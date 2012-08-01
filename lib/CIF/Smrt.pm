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
use constant WORKER_CONNECTION  => 'ipc://workers';
use constant RETURN_CONNECTION  => 'ipc://return';
use constant SENDER_CONNECTION  => 'ipc://sender';
use constant CTRL_CONNECTION    => 'ipc://ctrl';

use Regexp::Common qw/net URI/;
use Regexp::Common::net::CIDR;
use Encode qw/encode_utf8/;
use Data::Dumper;
use File::Type;
use Module::Pluggable require => 1;
use Digest::SHA1 qw/sha1_hex/;
use URI::Escape;
use Try::Tiny;

use Time::HiRes qw/nanosleep/;
use ZeroMQ qw/:all/;

# the lower this is, the higher the chance of 
# threading collisions resulting in a seg fault.
# the higher the thread count, the higher this number needs to be
use constant NSECS_PER_MSEC     => 1_000_000;
use constant NSECS_PER_MSEC_NOP => 2_000_000;

use CIF qw/generate_uuid_url generate_uuid_random is_uuid/;
require CIF::Client;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(
    config db_config feeds_config feeds threads 
    entries defaults feed rules load_full goback 
    client wait_for_server name instance 
    batch_control client_config postprocess
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
       
    $self->set_feed($args->{'feed'});
    
    my ($err,$ret) = $self->init_config($args);
    return($err) if($err);
    
    ($err,$ret) = $self->init_rules($args);
    return($err) if($err);
    
    $self->set_threads(         $args->{'threads'}          || $self->get_config->{'threads'}           || 1);
    $self->set_goback(          $args->{'goback'}           || $self->get_config->{'goback'}            || 3);
    $self->set_load_full(       $args->{'load_full'}        || $self->get_config->{'load_full'}         || 0);
    $self->set_wait_for_server( $args->{'wait_for_server'}  || $self->get_config->{'wait_for_server'}   || 0);
    $self->set_batch_control(   $args->{'batch_control'}    || $self->get_config->{'batch_control'}     || 5000); # arbitrary
    
    ## TODO -- enable postprocessors individually
    $self->set_postprocess(     $args->{'postprocess'}      || $self->get_config->{'postprocess'}       || 0);
    
    if($self->get_postprocess()){
        warn 'postprocessing enabled...' if($::debug);
    } else {
        warn 'postprocessing disabled...' if($::debug);
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

sub init_config {
    my $self = shift;
    my $args = shift;
    
    # do this here, we'll do the setup within the sender_routine (thread)
    $self->set_client_config($args->{'config'});
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return(undef,'missing config file');
    
    $self->set_config(          $args->{'config'}->param(-block => 'cif_smrt'));
        
    $self->set_db_config($args->{'config'}->param(-block => 'db'));
    $self->set_feeds_config($args->{'config'}->param(-block => 'cif_feeds'));
    return(undef,1);
}

sub init_rules {
    my $self = shift;
    my $args = shift;
    
    $args->{'rules'} = Config::Simple->new($args->{'rules'}) || return(undef,'missing rules file');
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
    my ($content,$err) = threads->create('_pull_feed',$f)->join();
    return(undef,$err) if($err);
    return(undef,'no content') unless($content);
    # auto-decode the content if need be
    $content = _decode($content,$f);

    # encode to utf8
    $content = encode_utf8($content);
    # remove any CR's
    $content =~ s/\r//g;
    delete($f->{'feed'});
    return($content);
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
        if(my $content = $_->pull($f)){
            return(undef,$content);
        }
    }
    return('could not pull feed',undef);
}


## TODO -- turn this into plugins
sub parse {
    my $self = shift;
    my $f = $self->get_rules();
    
    my ($content,$err) = pull_feed($f);
    return($err,undef) if($err);

    my $return;
    # see if we designate a delimiter
    if(my $d = $f->{'delimiter'}){
        require CIF::Smrt::ParseDelim;
        $return = CIF::Smrt::ParseDelim::parse($f,$content,$d);
    } else {
        # try to auto-detect the file
        if($content =~ /<\?xml version=/){
            if($content =~ /<rss version=/){
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
    
    warn 'parsing...' if($::debug);
    my $recs = $self->parse();
    
    return unless($#{$recs} > -1);
    
    if($self->get_goback()){    
        warn 'sorting '.($#{$recs}+1).' recs...' if($::debug);
        $recs = _sort_detecttime($recs);
    }
    
    ## TODO -- move this to the threads?
    ## test with alienvault scan's feed
    warn 'mapping...' if($::debug);
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
            
        ## TODO -- if we do this, we need to degrade the count somehow...
        last if($r->{'dt'} < $self->get_goback());
        push(@array,$r);
    }
    warn 'done mapping...' if($::debug);
    return(\@array);
}

sub process {
    my $self = shift;
    my $args = shift;
    
    # do this first so the threads don't copy the recs into their mem
    warn 'setting up zmq interfaces...' if($::debug);
   
    my $context = ZeroMQ::Context->new();
    my $workers = $context->socket(ZMQ_PUSH);
    $workers->bind(WORKER_CONNECTION());
    
    my $ctrl = $context->socket(ZMQ_PUB);
    $ctrl->bind(CTRL_CONNECTION());
    
    # feature of zmq, pub/sub's need a warm up msg
    warn 'sending ctrl warm-up msg...';
    $ctrl->send('WARMING UP');
    
    my $return = $context->socket(ZMQ_PULL);
    $return->bind(RETURN_CONNECTION());

    ## TODO -- req/reply checkins?
    warn 'creating '.$self->get_threads().' worker threads...';
    for (1 ... $self->get_threads()) {
        threads->create('worker_routine', $self)->detach();
    }
       
    warn 'done...' if($::debug);
    
    warn 'running preprocessor routine...' if($::debug);
    my $array = threads->create('preprocess_routine',$self)->join();
    return (undef,'no records') unless($#{$array} > -1);
    
    my $total_recs = ($#{$array});
    warn 'processing: '.($total_recs + 1).' records...';

    warn 'total recs: '.($total_recs + 1);
    threads->create('sender_routine',$self, $total_recs)->detach();

    warn 'sending to workers...' if($::debug);
    $workers->send_as(json => $_) foreach(@$array);
    
    do {
        warn 'waiting on message...' if($::debug);
        my $msg = $return->recv();
        warn 'return msg received...' if($::debug);

        $msg = MessageType->decode($msg->data());
        $total_recs -= ($#{$msg->{'data'}}+1);
        warn 'total left: '.($total_recs + 1);
        nanosleep NSECS_PER_MSEC;
    } while($total_recs > -1);
    
    warn 'sending KILL...';
    $ctrl->send('DONE');
    
    wait;
    
    $workers->close();
    $ctrl->close();
    $return->close();
    $context->term();
     
    return(undef,1);
}

sub worker_routine {
    my $self = shift;
   
    require Iodef::Pb::Simple;
    my $context = ZeroMQ::Context->new();
    
    warn 'starting worker: '.threads->tid() if($::debug > 1);
    
    my $receiver = $context->socket(ZMQ_PULL);
    $receiver->connect(WORKER_CONNECTION());
    
    my $sender = $context->socket(ZMQ_PUSH);
    $sender->connect(SENDER_CONNECTION());
    
    my $ctrl = $context->socket(ZMQ_SUB);
    $ctrl->setsockopt(ZMQ_SUBSCRIBE,''); 
    $ctrl->connect(CTRL_CONNECTION());
    
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
        warn 'worker['.threads->tid().'] polling...' if($::debug > 1);
        $poller->poll();
        warn 'worker['.threads->tid().'] checking event...' if($::debug > 1);
        if($poller->has_event('worker')){
            warn 'worker['.threads->tid().'] receiving event...' if($::debug > 2);
            my $msg = $receiver->recv_as('json');
            warn 'worker['.threads->tid().'] processing message...' if($::debug > 2);
            
            warn 'worker['.threads->tid().'] generating uuid...' if($::debug > 2);
            $msg->{'id'} = generate_uuid_random();
    
            warn 'worker['.threads->tid().'] generating iodef...' if($::debug > 2);
            my $iodef = Iodef::Pb::Simple->new($msg);
            
            if($self->get_postprocess()){
                foreach my $p (@postprocessors){
                    my $err;
                    try {
                        $p->process($self->get_config(),$iodef);
                    } catch {
                        $err = shift;
                    };
                    warn $err if($err);
                };
            }
            warn 'worker['.threads->tid().'] sending message...' if($::debug > 2);
            $sender->send($iodef->encode());
            warn 'worker['.threads->tid().'] message sent...' if($::debug > 2);
        }
        warn 'worker['.threads->tid().'] checking control...' if($::debug > 1);
        if($poller->has_event('ctrl')){
            warn 'worker['.threads->tid().'] recieved KILL';
            my $x = $ctrl->recv();
            $done = 1;
        }
        warn 'worker['.threads->tid().'] tick...' if($::debug > 2);
        nanosleep NSECS_PER_MSEC;
        warn 'worker['.threads->tid().'] tick done...' if($::debug > 2);
    }
    warn 'worker['.threads->tid().'] done...' if($::debug > 1);
    $sender->close();
    $ctrl->close();
    $receiver->close();
    $context->term();
}

sub sender_routine {
    my $self        = shift;
    my $total_recs  = shift;
      
    # do this within the thread
    my ($err,$client) = CIF::Client->new({
        config  => $self->get_client_config(),
    });
    $self->set_client($client);
    
    my $context = ZeroMQ::Context->new();
    
    warn 'starting sender thread...';
    warn 'waiting for '.($total_recs+1).' recs...';
       
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
                 
    my $array; 
    my $done = 0;
    do {
        $poller->poll();
        if($poller->has_event('ctrl')){
            $done = 1;
            my $x = $ctrl->recv();
            warn 'sender: KILL sig received';
        }
        do {
            if($poller->has_event('sender')){
                warn 'sender['.threads->tid().'] found event...' if($::debug > 2);
                my $msg = $sender->recv();
                warn 'sender['.threads->tid().'] msg recieved...' if($::debug > 2);
                push(@$array,$msg->data());
                # 300 is arbitrary || this is the last rec in the batch
                if(($#{$array}+1) % $self->get_batch_control() == 0 || $total_recs == 0){
                    warn 'sender['.threads->tid().'] sending data to router...' if($::debug > 2);
                    my $ret = $self->send($array);
                    warn 'sender['.threads->tid().'] returning answer from router...' if($::debug > 2);
                    $return->send($ret->encode());
                    $array = [];
                    warn 'sender['.threads->tid().'] total recs left: '.($total_recs+1) if($::debug > 2);
                }
                $total_recs--;
            }
            nanosleep NSECS_PER_MSEC;
        } while($total_recs > -1);
        nanosleep NSECS_PER_MSEC;
    } while (!$done && ($total_recs > -1));
    
    warn 'sender done...';
    $sender->close();
    $return->close();
    $ctrl->close();
    $context->term();
}

sub send {
    my $self = shift;
    my $data = shift;
 
    warn 'creating new submission';
    my $ret = $self->get_client->new_submission({
        guid    => $self->get_rules->{'guid'},
        data    => $data,
    });
    
    warn 'submitting...';
 
    return $self->get_client->submit($ret);    
}

sub throttle {
    my $throttle = shift;

    require Linux::Cpuinfo;
    my $cpu = Linux::Cpuinfo->new();
    return(1) unless($cpu);
    my $cores = $cpu->num_cpus();
    return(1) unless($cores && $cores =~ /^\d$/);
    return(1) if($cores eq 1);
    
    return($cores * 4)  if($throttle eq 'high');
    return($cores * 2)  if($throttle eq 'medium');
    return($cores);
}

sub normalize_timestamp {
    my $dt = shift;
    return $dt if($dt =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    if($dt && ref($dt) ne 'DateTime'){
        if($dt =~ /^\d+$/){
            if($dt =~ /^\d{8}$/){
                $dt.= 'T00:00:00Z';
                $dt = eval { DateTime::Format::DateParse->parse_datetime($dt) };
                unless($dt){
                    $dt = DateTime->from_epoch(epoch => time());
                }
            } else {
                $dt = DateTime->from_epoch(epoch => $dt);
            }
        } elsif($dt =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\S+)?$/) {
            my ($year,$month,$day,$hour,$min,$sec,$tz) = ($1,$2,$3,$4,$5,$6,$7);
            $dt = DateTime::Format::DateParse->parse_datetime($year.'-'.$month.'-'.$day.' '.$hour.':'.$min.':'.$sec,$tz);
        } else {
            $dt =~ s/_/ /g;
            $dt = DateTime::Format::DateParse->parse_datetime($dt);
            return undef unless($dt);
        }
    }
    $dt = $dt->ymd().'T'.$dt->hms().'Z';
    return $dt;
}

sub _sort_detecttime {
    my $recs = shift;

    foreach (@{$recs}){
        delete($_->{'regex'}) if($_->{'regex'});
        my $dt = $_->{'detecttime'};
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
        $_->{'detecttime'} = $dt;
        $_->{'description'} = '' unless($_->{'description'});
    }
    ## TODO -- can we get around having to create a new array?
    my @new = sort { $b->{'detecttime'} cmp $a->{'detecttime'} } @$recs;
    return(\@new);
}

1;
