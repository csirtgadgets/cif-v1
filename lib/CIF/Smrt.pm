package CIF::Smrt;
use base 'Class::Accessor';

use 5.008008;
use strict;
use warnings;
use threads;

our $VERSION = '0.99_03';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

# we're using ipc instead of inproc cause perl sucks
# at sharing context's with certain types of sockets (ZMQ_PUSH in particular)
use constant WORKER_CONNECTION      => 'ipc://workers';
# this is used to return back the total sum of recs processed by the analytics
# i'm sure there's a better way to do this
use constant WORKER_SUM_CONNECTION  => 'ipc://workers_sum';
use constant RETURN_CONNECTION      => 'ipc://return';
use constant SENDER_CONNECTION      => 'ipc://sender';
use constant CTRL_CONNECTION        => 'ipc://ctrl';

# for figuring out throttle
use constant DEFAULT_THROTTLE_FACTOR => 4;

# default severity mapping
use constant DEFAULT_SEVERITY_MAP => {
    botnet      => 'high',
};

use Regexp::Common qw/net URI/;
use Regexp::Common::net::CIDR;
use Encode qw/encode_utf8/;
use Data::Dumper;
use File::Type;
use Module::Pluggable require => 1;
use Digest::SHA qw/sha1_hex/;
use URI::Escape;
use Try::Tiny;

use Net::SSLeay;
Net::SSLeay::SSLeay_add_ssl_algorithms();

use CIF qw/generate_uuid_url generate_uuid_random is_uuid debug normalize_timestamp/;

use Time::HiRes qw/nanosleep/;
use ZeroMQ qw/:all/;

# the lower this is, the higher the chance of 
# threading collisions resulting in a seg fault.
# the higher the thread count, the higher this number needs to be
use constant NSECS_PER_MSEC     => 1_000_000;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(
    config db_config feeds_config feeds threads 
    entries defaults feed rules load_full goback 
    client wait_for_server name instance 
    batch_control client_config postprocess apikey
    severity_map proxy
));

my @preprocessors = __PACKAGE__->plugins();
@preprocessors = grep(/Preprocessor::[0-9a-zA-Z_]+$/,@preprocessors);

my @postprocessors = __PACKAGE__->plugins();
@postprocessors = grep(/Postprocessor::[0-9a-zA-Z_]+$/,@postprocessors);

sub new {
    my $class = shift;
    my $args = shift;
    
    my $self = {};
    bless($self,$class);
      
    my ($err,$ret) = $self->init($args);
    return($err) if($err);

    return (undef,$self);
}

sub init {
    my $self = shift;
    my $args = shift;
    
    my ($err,$ret) = $self->init_config($args);
    return($err) if($err);
      
    ($err,$ret) = $self->init_rules($args);
    return($err) if($err);
        
    $self->set_threads(         $args->{'threads'}          || $self->get_config->{'threads'}           || 1);
    $self->set_goback(          $args->{'goback'}           || $self->get_config->{'goback'}            || 3);
    $self->set_load_full(       $args->{'load_full'}        || $self->get_config->{'load_full'}         || 0);
    $self->set_wait_for_server( $args->{'wait_for_server'}  || $self->get_config->{'wait_for_server'}   || 0);
    $self->set_batch_control(   $args->{'batch_control'}    || $self->get_config->{'batch_control'}     || 10000); # arbitrary
    $self->set_apikey(          $args->{'apikey'}           || $self->get_config->{'apikey'}            || return('missing apikey'));
    $self->set_proxy(           $args->{'proxy'}            || $self->get_config->{'proxy'});
   
    $self->init_postprocessors($args);
    
    if($self->get_postprocess()){
        debug('postprocessing enabled...') if($::debug);
    } else {
        debug('postprocessing disabled...') if($::debug);
    }
    
    $self->set_goback(time() - ($self->get_goback() * 84600));
    $self->set_goback(0) if($self->get_load_full());
    
    
    ## TODO -- this isnt' being passed to the plugins, the config is
    $self->set_name(        $args->{'name'}     || $self->get_config->{'name'}      || 'localhost');
    $self->set_instance(    $args->{'instance'} || $self->get_config->{'instance'}  || 'localhost');
    
    $self->init_db($args);
    $self->init_feeds($args);
    return($err,$ret) if($err);
    return(undef,1);
}

sub init_postprocessors {
    my $self = shift;
    my $args = shift;
    
    my $things = $args->{'postprocess'} || $self->get_config->{'postprocess'};
    return unless($things);
    
    if($things eq '1'){
        $self->set_postprocess(\@postprocessors);
    } else {
        my $enabled;
        foreach (@$things){
            foreach my $p (@postprocessors){
                push(@$enabled,$p) if(lc($p) =~ /::$_$/);
            }
        }
        $self->set_postprocess($enabled);
    }
}

sub init_config {
    my $self = shift;
    my $args = shift;
    
    # do this here, we'll do the setup within the sender_routine (thread)
    $self->set_client_config($args->{'config'});
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return('missing config file');
    
    $self->set_config(          $args->{'config'}->param(-block => 'cif_smrt'));
    $self->set_db_config(       $args->{'config'}->param(-block => 'db'));
    $self->set_feeds_config(    $args->{'config'}->param(-block => 'cif_feeds'));
    
    $self->init_config_severity($args);
    
    return(undef,1);
}

sub init_config_severity {
    my $self = shift;
    my $args = shift;
    
    my $map = $args->{'config'}->param(-block => 'cif_smrt_severity');
    $map = DEFAULT_SEVERITY_MAP() unless(keys %$map);
    
    $self->set_severity_map($map);
    
}

sub init_rules {
    my $self = shift;
    my $args = shift;
    
    $args->{'rules'} = Config::Simple->new($args->{'rules'}) || return(undef,'missing rules file');
    
    unless($args->{'feed'}){
        my @sections = keys %{$args->{'rules'}->{'_DATA'}};
        @sections = map { $_ = $_ if($_ !~ /^default/) } @sections;
        my $string = "missing feed, please set (-f) one of the following for this config:\n\n";
        $string .= join("\n",@sections);
        return($string);
    }

    $self->set_feed($args->{'feed'});
    my $defaults    = $args->{'rules'}->param(-block => 'default');
    my $rules       = $args->{'rules'}->param(-block => $self->get_feed());
    
    return ('invalid feed: '.$self->get_feed().'...') unless(keys %$rules);
   
    map { $defaults->{$_} = $rules->{$_} } keys (%$rules);
    
    unless(is_uuid($defaults->{'guid'})){
        $defaults->{'guid'} = generate_uuid_url($defaults->{'guid'});
    }
    $self->set_rules($defaults);
    return(undef,1);
}

sub init_feeds {
    my $self = shift;
    
    my $feeds = $self->get_feeds_config->{'enabled'} || return;
    $self->set_feeds($feeds);
}

sub init_db {
    my $self = shift;
    my $args = shift;
    
    my $config = $self->get_db_config();
    
    my $db          = $config->{'database'} || 'cif';
    my $user        = $config->{'user'}     || 'postgres';
    my $password    = $config->{'password'} || '';
    my $host        = $config->{'host'}     || '127.0.0.1';
    
    my $dbi = 'DBI:Pg:database='.$db.';host='.$host;
    
    require CIF::DBI;
    my $ret = CIF::DBI->connection($dbi,$user,$password,{ AutoCommit => 0});
    return $ret;   
}

sub pull_feed { 
    my $f = shift;
    my $ret = threads->create('_pull_feed',$f)->join();
    return(undef,'') unless($ret);
    return($ret) if($ret =~ /^ERROR: /);
    
    # auto-decode the content if need be
    $ret = _decode($ret,$f);

    # encode to utf8
    $ret = encode_utf8($ret);
    # remove any CR's
    $ret =~ s/\r//g;
    delete($f->{'feed'});
    return(undef,$ret);
}

# we do this sep cause it's in a thread
# this gets around memory leak issues and TLS threading issues with Crypt::SSLeay, etc
sub _pull_feed {
    my $f = shift;
    return unless($f->{'feed'});

    foreach my $key (keys %$f){
        foreach my $key2 (keys %$f){
            if($f->{$key} =~ /<$key2>/){
                $f->{$key} =~ s/<$key2>/$f->{$key2}/g;
            }
        }
    }
    my @pulls = __PACKAGE__->plugins();
    @pulls = grep(/::Pull::/,@pulls);
    foreach(@pulls){
        my ($err,$ret) = $_->pull($f);
        return('ERROR: '.$err) if($err);
        
        # we don't want to error out if there's just no content
        next unless(defined($ret));
        return($ret);
    }
    return('ERROR: could not pull feed');
}


## TODO -- turn this into plugins
sub parse {
    my $self = shift;
    my $f = $self->get_rules();
    
    if($self->get_proxy()){
        $f->{'proxy'} = $self->get_proxy();
    }
    
    my ($err,$content) = pull_feed($f);
    return($err) if($err);
    
    my $return;
    try {
        # see if we designate a delimiter
        if(my $d = $f->{'delimiter'}){
            require CIF::Smrt::ParseDelim;
            $return = CIF::Smrt::ParseDelim::parse($f,$content,$d);
        } else {
            # try to auto-detect the file
            debug('testing...');
            ## todo -- very hard to detect iodef-pb strings
            # might have to rely on base64 encoding decode first?
            if($content =~ /^application\/base64\+snappy\+pb\+iodef\n([\S\n]+)\n$/){
                require CIF::Smrt::ParsePbIodef;
                $return = CIF::Smrt::ParsePbIodef::parse($f,$content);
            } elsif($content =~ /<\?xml version=/){
                if($content =~ /<rss version=/ && !$f->{'nodes'}){
                    require CIF::Smrt::ParseRss;
                    $return = CIF::Smrt::ParseRss::parse($f,$content);
                } else {
                    require CIF::Smrt::ParseXml;
                    $return = CIF::Smrt::ParseXml::parse($f,$content);
                }
            } elsif($content =~ /^\[?{/){
                # possible json content or CIF
                if($content =~ /^{"status"\:/){
                    require CIF::Smrt::ParseCIF;
                    $return = CIF::Smrt::ParseCIF::parse($f,$content);
                } elsif($content =~ /urn:ietf:params:xmls:schema:iodef-1.0/) {
                    require CIF::Smrt::ParseJsonIodef;
                    $return = CIF::Smrt::ParseJsonIodef::parse($f,$content);
                } else {
                    require CIF::Smrt::ParseJson;
                    $return = CIF::Smrt::ParseJson::parse($f,$content);
                }
            ## TODO -- fix this; double check it
            } elsif($content =~ /^#?\s?"\S+","\S+"/ && !$f->{'regex'}){
                require CIF::Smrt::ParseCsv;
                $return = CIF::Smrt::ParseCsv::parse($f,$content);
            } else {
                require CIF::Smrt::ParseTxt;
                $return = CIF::Smrt::ParseTxt::parse($f,$content);
            }
        }
    } catch {
        $err = shift;
    };
    return($err) if($err);
    return(undef,$return);
}

sub _decode {
    my $data = shift;
    my $f = shift;

    my $ft = File::Type->new();
    my $t = $ft->mime_type($data);
    my @plugs = __PACKAGE__->plugins();
    @plugs = grep(/Decode/,@plugs);
    foreach(@plugs){
        if(my $ret = $_->decode($data,$t,$f)){
            return($ret);
        }
    }
    return $data;
}

sub preprocess_routine {
    my $self = shift;

    debug('parsing...') if($::debug);
    my ($err,$recs) = $self->parse();
    return($err) if($err);
    
    debug('parsed records: '."\n".Dumper($recs)) if($::debug > 9);
    
    return unless($#{$recs} > -1);
    
    if($self->get_goback()){
        debug('sorting '.($#{$recs}+1).' recs...') if($::debug);
        $recs = _sort_detecttime($recs);
    }
    ## TODO -- move this to the threads?
    ## test with alienvault scan's feed
    debug('mapping...') if($::debug);
    
    my @array;
    foreach my $r (@$recs){
        foreach my $key (keys %$r){
            next unless($r->{$key});
            if($r->{$key} =~ /<(\S+)>/){
                my $x = $r->{$1};
                if($x){
                    $r->{$key} =~ s/<\S+>/$x/;
                }
            }
        }
             
        foreach my $p (@preprocessors){
            $r = $p->process($self->get_rules(),$r);
        }
        
        # TODO -- work-around, make this more configurable
        unless($r->{'severity'}){
            $r->{'severity'} = ($self->get_severity_map->{$r->{'assessment'}}) ? $self->get_severity_map->{$r->{'assessment'}} : 'medium';
        }
            
        ## TODO -- if we do this, we need to degrade the count somehow...
        last if($r->{'reporttime_epoch'} < $self->get_goback());
        push(@array,$r);
    }
    debug('done mapping...') if($::debug);
    debug('records to be processed: '.($#array+1)) if($::debug);
    if($#array == -1){
        debug('your goback is too small, if you want records, increase the goback time') if($::debug);
    }

    return(undef,\@array);
}

sub process {
    my $self = shift;
    my $args = shift;
    
    # do this first so the threads don't copy the recs into their mem
    debug('setting up zmq interfaces...') if($::debug);
   
    my $context = ZeroMQ::Context->new();
    my $workers = $context->socket(ZMQ_PUSH);
    $workers->bind(WORKER_CONNECTION());
    
    my $ctrl = $context->socket(ZMQ_PUB);
    $ctrl->bind(CTRL_CONNECTION());
    
    # feature of zmq, pub/sub's need a warm up msg
    debug('sending ctrl warm-up msg...');
    $ctrl->send('WARMING_UP');
    
    my $return = $context->socket(ZMQ_PULL);
    $return->bind(RETURN_CONNECTION());
    
    my $workers_sum = $context->socket(ZMQ_PULL);
    $workers_sum->bind(WORKER_SUM_CONNECTION());
    
    # this needs to be started first
    debug('starting sender thread...');
    threads->create('sender_routine',$self)->detach();
    # thread/zmq safety requirement
    # if the workers start too fast, this gets messed up, give it a 'tick' head-start
    # if we still see a race condition, send a warmup message to the sender either here
    # or through the workers as a 'checkin'
    nanosleep NSECS_PER_MSEC;
    
    ## TODO -- req/reply checkins?
    debug('creating '.$self->get_threads().' worker threads...');
    for (1 ... $self->get_threads()) {
        threads->create('worker_routine', $self)->detach();
    }
       
    debug('done...') if($::debug);
    
    debug('running preprocessor routine...') if($::debug);
    ## TODO -- figure out if this really needs to be threaded out or not
    # there are implications with how we return errors
    #my ($err,$array) = threads->create('preprocess_routine',$self)->join();
    my ($err,$array) = $self->preprocess_routine();
    return($err) if($err);

    return (undef,'no records') unless($#{$array} > -1);
    
    my $master_count = ($#{$array} + 1);
    debug('processing: '.$master_count.' records...');

    debug('master count: '.$master_count);

    ## TODO -- batch this out a little
    debug('sending to workers...') if($::debug);
    $workers->send_as(json => $_) foreach(@$array);
    
    my $poller = ZeroMQ::Poller->new(
        {
            name    => 'workers_sum',
            socket  => $workers_sum,
            events  => ZMQ_POLLIN,
        },
        {
            name    => 'return',
            socket  => $return,
            events  => ZMQ_POLLIN,
        },
    );
    
    my $done = 0;
    my $total_recs = $master_count;
    my $sent_recs = 0;
    do {
        debug('waiting on message...');
        
        debug('polling...') if($::debug > 5);
        $poller->poll();
        debug('found msg');
        if($poller->has_event('workers_sum')){
            my $msg = $workers_sum->recv()->data();
            for($msg){
                if(/^COMPLETED:(\d+)$/){
                    $master_count -= $1; 
                    last;
                }
                if(/^ADDED:(\d+)$/){
                    $total_recs += $1;
                    last;
                }
            }
        }
        
        ## TODO -- should this be after the return check?
        debug('master count: '.$master_count);  
        if($master_count == 0){
            debug('sending total: '.$total_recs);
            $ctrl->send('TOTAL:'.$total_recs);
            $ctrl->send('WRK_DONE');
        }
        # waiting for sender
        if($poller->has_event('return')){
            debug('return msg received');
            my $msg = $return->recv();
            if($msg->data() =~ /^ERROR: /){
                print $msg->data()."\n";
                $sent_recs = -1;
            } else {
                $msg = MessageType->decode($msg->data());
                # size of the array returned +1
                $sent_recs += ($#{$msg->get_data()} + 1);
            }
        }
        nanosleep NSECS_PER_MSEC;
        # total_recs is based on 0 ... X not -1 ... X
        debug('sent recs: '.$sent_recs);
        debug('total recs: '.$total_recs);
    } while($sent_recs != -1 && $sent_recs < $total_recs);

    $ctrl->send('WRK_DONE');
    
    $workers->close();
    $workers_sum->close();
    $ctrl->close();
    $return->close();
    $context->term();
    return(undef,1);
}

sub worker_routine {
    my $self = shift;
   
    require Iodef::Pb::Simple;
    my $context = ZeroMQ::Context->new();
    
    debug('starting worker: '.threads->tid()) if($::debug > 1);
    
    my $receiver = $context->socket(ZMQ_PULL);
    $receiver->connect(WORKER_CONNECTION());
    
    my $sender = $context->socket(ZMQ_PUSH);
    $sender->connect(SENDER_CONNECTION());
    
    my $ctrl = $context->socket(ZMQ_SUB);
    $ctrl->setsockopt(ZMQ_SUBSCRIBE,''); 
    $ctrl->connect(CTRL_CONNECTION());
    
    my $workers_sum = $context->socket(ZMQ_PUSH);
    $workers_sum->connect(WORKER_SUM_CONNECTION());
    
     my $poller = ZeroMQ::Poller->new(
        {
            name    => 'worker',
            socket  => $receiver,
            events  => ZMQ_POLLIN,
        },
        {
            name    => 'ctrl',
            socket  => $ctrl,
            events  => ZMQ_POLLIN,
        },
    ); 
       
    my $done = 0;
    my $recs = 0;
    while(!$done){
        debug('polling...') if($::debug > 5);
        $poller->poll();
        debug('checking control...') if($::debug > 5);
        if($poller->has_event('ctrl')){
            my $msg = $ctrl->recv()->data();
            debug('ctrl sig received: '.$msg) if($::debug > 5 && $msg eq 'WRK_DONE');
            $done = 1 if($msg eq 'WRK_DONE');
        }
        debug('checking event...') if($::debug > 4);
        if($poller->has_event('worker')){
            debug('receiving event...') if($::debug > 4);
            my $msg = $receiver->recv_as('json');
            debug('processing message...') if($::debug > 4);
            
            debug('generating uuid...') if($::debug > 4);
            $msg->{'id'} = generate_uuid_random();
            
            if($::debug > 1){
                my $thing = $msg->{'address'} || $msg->{'malware_md5'} || $msg->{'malware_sha1'};
                debug('uuid: '.$msg->{'id'}.' - '.$msg->{'reporttime'}.' - '.$thing.' - '.$msg->{'assessment'}.' - '.$msg->{'description'});
            }
    
            debug('generating iodef...') if($::debug > 3);

            my $iodef = Iodef::Pb::Simple->new($msg);
                  
            my @results;
            if($self->get_postprocess()){
                foreach my $p (@{$self->get_postprocess}){
                    my ($err,$array);
                    try {
                        $array = $p->process($self,$iodef);
                    } catch {
                        $err = shift;
                    };
                    debug($err) if($::debug && $err);
                    push(@results,@$array) if($array && @$array);
                };

                # we don't do +1 here cause the parent already knows about the
                # original record
             
                if($#results > -1){
                    @results = map { IODEFDocumentType->new({ lang => 'EN', Incident => $_ })->encode() } @results;
                    # sometimes the $sender->send_as will get there faster
                    # than the $workers_sum will make it up and over to the sender
                    # it's possible we'll have to re-work this with the sender thread, but it works for now
                    #$workers_sum->send(($#results+1));
                    $workers_sum->send('ADDED:'.($#results+1));
                    nanosleep NSECS_PER_MSEC;
                }
            }
            push(@results,$iodef->encode());
                       
            debug('sending message...') if($::debug > 3);
            $sender->send_as('json' => \@results);
            debug('message sent...') if($::debug > 3);
            $workers_sum->send('COMPLETED:1');
        }
        # thread/zmq safety requirement
        nanosleep NSECS_PER_MSEC;
    }
    debug('done...') if($::debug > 2);
    $sender->close();
    $ctrl->close();
    $receiver->close();
    $workers_sum->close();
    $context->term();
}

sub sender_routine {
    my $self        = shift;
    #my $total_recs  = shift;
      
    # do this within the thread
    require CIF::Client;
    my ($err,$client) = CIF::Client->new({
        config  => $self->get_client_config(),
        apikey  => $self->get_apikey(),
    });
    $self->set_client($client);
    
    my $batch_control = $self->get_batch_control();
    
    my $context = ZeroMQ::Context->new();
    
    debug('starting sender thread...') if($::debug > 1);
       
    my $sender = $context->socket(ZMQ_PULL);
    $sender->bind(SENDER_CONNECTION());
    
    my $ctrl = $context->socket(ZMQ_SUB);
    $ctrl->setsockopt(ZMQ_SUBSCRIBE,'');
    $ctrl->connect(CTRL_CONNECTION());
    
    my $return = $context->socket(ZMQ_PUSH);
    $return->connect(RETURN_CONNECTION());
    
    my $poller = ZeroMQ::Poller->new(
        {
            name    => 'sender',
            socket  => $sender,
            events  => ZMQ_POLLIN,
        },
        {
            name    => 'ctrl',
            socket  => $ctrl,
            events  => ZMQ_POLLIN,
        },
    ); 
                 
    my $queue; 
    my $done = 0;
    my ($total_recs,$sent_recs) = (0,0);
    do {
        debug('polling...') if($::debug > 4);
        $poller->poll();
        # we wanna check this one first, since it'll come in later
        if($poller->has_event('ctrl')){
            my $msg = $ctrl->recv()->data();
            debug('ctrl sig received: '.$msg) if($::debug > 2);
            for($msg){
                if(/^TOTAL:(\d+)$/){
                    $total_recs = $1;
                    debug('total received: '.$total_recs) if($::debug > 2);
                    last;
                }
            }
        }
        # we need to move this out of the if/then incase we're waiting on a kill
        if($poller->has_event('sender')){
            debug('found event...') if($::debug > 2);
            my $msg = $sender->recv_as('json');
            my $num_msgs = ($#{$msg}+1);
            debug('msgs recvieved: '.$num_msgs) if($::debug > 2);
            push(@$queue,@$msg);
            debug('msgs in queue: '.($#{$queue}+1)) if($::debug > 2);
        }
        
        # we're not done till we at-least have a total from the 
        # master thread
        # if what's in the queue is the difference between sent and total
        # we're done
        if($total_recs && ($sent_recs + (($#{$queue}+1)) == $total_recs)){
            $done = 1;
        }
        # if we have a total number and it's equal to our sent number
        # we're done
        if($total_recs && ($sent_recs == $total_recs)){
            $done = 1;
        }

        if($#{$queue} > $batch_control || $done){
            debug('sending data to router: '.($#{$queue}+1)) if($::debug > 2);
            my ($err,$ret) = $self->send($queue);
            debug('returning answer from router...') if($::debug > 2);
            if($err){
                $return->send($err);
            } else {
                $return->send($ret->encode());
            }
            $sent_recs += ($#{$queue}+1);
            $queue = [];
        }
        nanosleep NSECS_PER_MSEC;

    } while (!$done);
    
    debug('sender done...') if($::debug > 1);;
    $sender->close();
    $return->close();
    $ctrl->close();
    $context->term();
}

sub send {
    my $self = shift;
    my $data = shift;

    debug('creating new submission') if($::debug);
    my $ret = $self->get_client->new_submission({
        guid    => $self->get_rules->{'guid'},
        data    => $data,
    });
    
    debug('submitting...') if($::debug);
    return $self->get_client->submit($ret);    
}

sub throttle {
    my $throttle = shift;

    require Linux::Cpuinfo;
    my $cpu = Linux::Cpuinfo->new();
    return(DEFAULT_THROTTLE_FACTOR()) unless($cpu);
    
    my $cores = $cpu->num_cpus();
    return(DEFAULT_THROTTLE_FACTOR()) unless($cores && $cores =~ /^\d$/);
    return(DEFAULT_THROTTLE_FACTOR()) if($cores eq 1);
    
    return($cores * (DEFAULT_THROTTLE_FACTOR() * 2))  if($throttle eq 'high');
    return($cores * DEFAULT_THROTTLE_FACTOR())  if($throttle eq 'medium');
}

sub _sort_detecttime {
    my $recs = shift;

    foreach (@{$recs}){
        delete($_->{'regex'}) if($_->{'regex'});
        my $dt = $_->{'reporttime'} || $_->{'detecttime'};
        if($dt){
            $dt = normalize_timestamp($dt);
        }
        unless($dt){
            $dt = DateTime->from_epoch(epoch => time());
            if(lc($_->{'detection'}) eq 'hourly'){
                $dt = $dt->ymd().'T'.$dt->hour.':00:00Z';
            } elsif(lc($_->{'detection'}) eq 'monthly') {
                $dt = $dt->year().'-'.$dt->month().'-01T00:00:00Z';
            } elsif(lc($_->{'detection'} ne 'now')){
                $dt = $dt->ymd().'T00:00:00Z';
            } else {
                $dt = $dt->ymd().'T'.$dt->hms();
            }
        }
        $_->{'reporttime'} = $dt;
        $_->{'description'} = '' unless($_->{'description'});
    }
    ## TODO -- can we get around having to create a new array?
    my @new = sort { $b->{'reporttime'} cmp $a->{'reporttime'} } @$recs;
    return(\@new);
}

1;
