#!/usr/bin/perl -w

use strict;
use warnings;

# fix lib paths, some may be relative
BEGIN {
    require File::Spec;
    my @libs = (
        "lib",
        "local/lib",
        "../libcif/lib", # in case we're in -dev mode
        "etc/upgrade/lib",
    );
    my $bin_path;

    for my $lib (@libs) {
        unless ( File::Spec->file_name_is_absolute($lib) ) {
            unless ($bin_path) {
                if ( File::Spec->file_name_is_absolute(__FILE__) ) {
                    $bin_path = ( File::Spec->splitpath(__FILE__) )[1];
                }
                else {
                    require FindBin;
                    no warnings "once";
                    $bin_path = $FindBin::Bin;
                }
            }
            $lib = File::Spec->catfile( $bin_path, File::Spec->updir, $lib );
        }
        unshift @INC, $lib;
    }
}

use Getopt::Std;
use Config::Simple;
use Data::Dumper;
use MIME::Lite;
use JSON::XS;
use threads;
use Time::HiRes qw/nanosleep/;
use ZeroMQ qw/:all/;
use Try::Tiny;
use Compress::Snappy;
use MIME::Base64;

use CIF qw/debug/;
use CIF::Legacy;
require CIF::Archive;

# control connections
use constant CTRL_CONNECTION            => 'ipc://ctrl';
use constant WORKER_CONNECTION          => 'ipc://workers';
use constant WRITER_CONNECTION          => 'ipc://writer';

# bi-directional pipe for return counts, figure out when we're done
use constant MSGS_PROCESSED_CONNECTION  => 'ipc://msgs_processed';
use constant MSGS_WRITTEN_CONNECTION    => 'ipc://msgs_written';

# used for SIGINT cleanup
my @pipes = ('msgs_written','workers','msgs_processed','writer','ctrl');

# the lower this is, the higher the chance of 
# threading collisions resulting in a seg fault.
# the higher the thread count, the higher this number needs to be
use constant NSECS_PER_MSEC     => 1_000_000;

use constant DEFAULT_THROTTLE_FACTOR => 1;

my %opts;
getopts('v:hdC:T:t:A:L:k:',\%opts);
our $debug = $opts{'d'} || 0;
$debug = $opts{'v'} if($opts{'v'});

my $config      = $opts{'C'} || $ENV{'HOME'}.'/.cif';
my $throttle    = $opts{'T'} || 'low';
my $threads     = $opts{'t'};
my $admin       = $opts{'A'} || 'root';
my $keep_days   = $opts{'k'};
my $mutex       = $opts{'L'} || '/tmp/cif-upgrade-database.lock';

#$SIG{'INT'} = 'cleanup';
$SIG{__DIE__} = 'cleanup';

if(-e $mutex){
    print 'already running, mutex found: '.$mutex."\n" if($debug);
    exit(-1);
}
my $ret;
#my $ret = system('touch '.$mutex);
#unless(defined($ret) && $ret == 0){
#    die($!);
#}

$threads = _throttle($throttle) unless($threads);

my $timestamp;
if($keep_days){
    $timestamp = DateTime->from_epoch(epoch => (time() - ((1 + $keep_days) * 84600)));
    $timestamp = $timestamp->ymd().'T00:00:00Z';
} else {
    $timestamp = '1900-01-01T00:00:00Z';
}

debug('using date: '.$timestamp);

my ($e,$r) = threads->create('_pager_routine',$config,$timestamp)->join();
warn $e if($e);

remove_lock();
debug('done...');
exit(0);

sub cleanup {
    my $msg = shift;
    if($msg){   
        print $msg."\n";
    } else {
        print "\n\nCaught Interrupt (^C), Aborting\n";
    }
    
    # zmq ipc cleanup in case we SIGINT
    foreach (@pipes){
        my $pipe = './'.$_;
        unlink ($pipe) if(-e $pipe);
    }
    
    remove_lock();
    exit(0);
}

sub remove_lock {
    system('rm '.$mutex) if(-e $mutex);
}

sub init_db {
    my $args = shift;

    my $config = Config::Simple->new($args->{'config'}) || return('missing config file');
    $config = $config->param(-block => 'db');
    
    my $db          = $config->{'database'} || 'cif';
    my $user        = $config->{'user'}     || 'postgres';
    my $password    = $config->{'password'} || '';
    my $host        = $config->{'host'}     || '127.0.0.1';
    
    my $dbi = 'DBI:Pg:database='.$db.';host='.$host;
    my $ret = CIF::DBI->connection($dbi,$user,$password,{ AutoCommit => 0});
    return (undef,$ret);
}

sub _pager_routine {
    my $config  = shift;
    my $ts      = shift;

    my $context = ZeroMQ::Context->new();
    
    my $ctrl = $context->socket(ZMQ_PUB);
    $ctrl->bind(CTRL_CONNECTION());

    debug('done...') if($::debug);
    
    my $workers = $context->socket(ZMQ_PUSH);
    $workers->bind(WORKER_CONNECTION());
    
    my $msgs_written = $context->socket(ZMQ_PULL);
    $msgs_written->bind(MSGS_WRITTEN_CONNECTION());

    my $msgs_processed = $context->socket(ZMQ_PULL);
    $msgs_processed->bind(MSGS_PROCESSED_CONNECTION());
    
    # setup the sql
    my $sql = qq{
        created >= '$ts'
    };
    my ($ret,$err,$data,$tmp,$sth);

    ($err,$ret) = init_db({ config => $config });
    return ($err) if($err);
    
    ($err,$ret) = CIF::Archive->new({ config => $config });
    return $err if($err);

    my $archive = $ret;
    $archive->load_page_info({ sql => $sql });
    
    $archive->{'limit'} = 5000;
    $archive->{'offset'} = 0;
    
    my $total = $archive->{'total'};
    debug('total count: '.$total);
    debug('pages: '.$archive->page_count());
    
    my $q = 'ORDER BY id DESC LIMIT '.$archive->{'limit'}.' OFFSET ?';
    my $ssql = 'SELECT id,uuid,guid,data FROM archive WHERE '.$sql.' '.$q;
    $archive->set_sql(custom1 => $ssql);
    $sth = $archive->sql_custom1();
    
    # feature of zmq, pub/sub's need a warm up msg
    debug('sending ctrl warm-up msg...');
    $ctrl->send('WARMING_UP');

    my $writer_t = threads->create('_writer_routine',$config,$total,$archive->{'limit'})->detach();
    nanosleep NSECS_PER_MSEC;
    
    debug('creating '.$threads.' worker threads...');
    for (1 ... $threads) {
        threads->create('_worker_routine',$config)->detach();
    }
    nanosleep NSECS_PER_MSEC;
    
    my $poll = ZeroMQ::Poller->new(
        {
            name    => 'msgs_written',
            socket  => $msgs_written,
            events  => ZMQ_POLLIN,
        },
        {
            name    => 'msgs_processed',
            socket  => $msgs_processed,
            events  => ZMQ_POLLIN,
        },
    );
    
    do {
        debug('executing sql...');
        $sth->execute($archive->{'offset'});
        $ret = $sth->fetchall_hashref('id');
        
        debug('sending next pages to workers...');
        $workers->send_as('json' => $ret->{$_}) foreach(keys(%$ret));
        
        debug('waiting on workers to finish up...') if($::debug > 4);
        my $completed = 0;
        # need to tell the writer process when they should commit between pages
        # send signal or something
        do {
            debug('polling...') if($::debug > 4);
            $poll->poll();
            if($poll->has_event('msgs_written')){
                $ret = $msgs_written->recv()->data();
                $completed += $ret;
                $total -= $ret;
            }        
            #sleep(1); # so ->poll() doesn't crush us and we can INT out
            nanosleep NSECS_PER_MSEC;
        } while(($completed < $archive->{'limit'}) && $total > 0);
        
        #debug('completed: '.$completed.'/'.$archive->{'limit'}) if($::debug > 1););
        debug('remaining: '.$total.' ('.int(($total/$archive->{'total'})*100).'%)');
       
        my $pages_left = $archive->page_count() - $archive->current_page();
        debug('pages left: '.$pages_left) if($pages_left % 10 == 0);
        $archive->{'offset'} = $archive->next_offset();
    } while($archive->current_page <= $archive->page_count());
    
    debug('sending WRK_DONE...') if($::debug);
    $ctrl->send('WRK_DONE');

    nanosleep NSECS_PER_MSEC;
    
    debug('closing connections...');

    $ctrl->close();
    $msgs_processed->close();
    $workers->close();
    $msgs_written->close();
    $context->term();
    return 1;
}

sub _worker_routine {
    my $context = ZeroMQ::Context->new();
    
    debug('starting worker: '.threads->tid()) if($::debug > 1);
    
    my $receiver = $context->socket(ZMQ_PULL);
    $receiver->connect(WORKER_CONNECTION());
    
    my $writer = $context->socket(ZMQ_PUSH);
    $writer->connect(WRITER_CONNECTION());
    
    my $msgs_processed = $context->socket(ZMQ_PUSH);
    $msgs_processed->connect(MSGS_PROCESSED_CONNECTION());
    
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
    my $tmp_total = 0;
    my $err;
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
            #debug('['.threads->tid.']'.' receiving event...') if($::debug > 2 && $tmp_total % 10 == 0);
            my $msg = $receiver->recv()->data();
            debug('processing message...') if($::debug > 4);
           
            ($err,$msg) = _process_message($msg);
            if($msg){
                $writer->send_as('json' => $msg);
                debug('sent to writer...') if($::debug > 4);
                $msgs_processed->send('1');
            }
        }
        $tmp_total++;
    }
    debug('done...') if($::debug > 2);
    debug('worker exiting...');
    $writer->close();
    $receiver->close();
    $ctrl->close();
    $context->term();
}

sub _process_message {
    my $data = shift;
    
    my $err;
    
    $data = JSON::XS::decode_json($data);
    unless($data->{'data'} =~ /^\{\"xmlns\:xsi/){
        debug('skipping: '.$data->{'id'});
        return 'skipping: '.$data->{'id'};
    }
    
    my $uuid    = $data->{'uuid'};
    my $id      = $data->{'id'};
    my $guid    = $data->{'guid'};
    $data       = $data->{'data'};
    
    debug('id: '.$id) if($::debug > 4);
 
    ## TODO -- REMOVE!
    my $orig = $data;
   
    # to keypairs
    $data = CIF::Legacy::hash_simple($data,$uuid);
    my $reporttime = $data->{'reporttime'};
    
    # to IODEF::PB
    #$data = Iodef::Pb::Simple->new($data);
    #try {
    #    $data = $data->encode();
    #} catch {
    #    $err = shift;
    #};
    #if($err){
    #    return $err;
    #}
    
    #$data = Compress::Snappy::compress($data);
    #$data = encode_base64($data);
    return (undef,{
        uuid        => $uuid,
        guid        => $guid,
        reporttime  => $reporttime,
        id          => $id,
        data        => $data,
        orig        => $orig,
    });
}

sub _writer_routine {
    my $config      = shift;
    my $total       = shift;
    my $commit_size = shift;

    my $context = ZeroMQ::Context->new();
    debug('starting writer thread...');
    
    my $writer = $context->socket(ZMQ_PULL);
    $writer->bind(WRITER_CONNECTION());
    
    my $msgs_written = $context->socket(ZMQ_PUSH);
    $msgs_written->connect(MSGS_WRITTEN_CONNECTION());
    
    my $poller = ZeroMQ::Poller->new(
        {
            name    => 'writer',
            socket  => $writer,
            events  => ZMQ_POLLIN,
        },
    ); 
    
    init_db({ config => $config });

    require Iodef::Pb::Simple;
    my ($e,$dbi) = CIF::Archive->new({ config => $config });
    return($e) if($e);
    
    $dbi->set_sql(custom2 => qq{
        UPDATE archive SET data = ?, created = ? where id = ?
    });
    
    my $sth2 = $dbi->sql_custom2();
                 
    
    my ($msg,$tmsg);
    my $tmp_total = 0;
    
    my ($ret,$err);
    my ($done,$total_r,$total_w) = (0,0,0);
    
    do {
        ($tmsg,$msg) = (undef,undef);
        debug('polling...') if($::debug > 4);
        
        $poller->poll();
        if($poller->has_event('writer')){
            debug('found message...') if($::debug > 4);
            $msg = $writer->recv_as('json');
            
            $tmsg = Iodef::Pb::Simple->new($msg->{'data'});
            
            $sth2->execute($msg->{'orig'},$msg->{'reporttime'},$msg->{'id'});
            
            ($err,$ret) = $dbi->insert_index({ 
                data        => $tmsg,
                feeds       => $dbi->{'feeds'},
                datatypes   => $dbi->{'datatypes'}, 
                uuid        => $msg->{'uuid'},
                guid        => $msg->{'guid'},
                reporttime  => $msg->{'reporttime'},
            });
            debug($err) if($err);
            $total_r += 1;
            $tmp_total += 1;
            debug($tmp_total) if($tmp_total % 100 == 0);
        }
        $done = 1 if($total_r == $total);
        
        if((($total_r % $commit_size) == 0) || $done){
            debug('flushing writer...');
            $dbi->dbi_commit();
            $msgs_written->send($tmp_total);
            debug('wrote: '.$tmp_total.' messages...');
            $total_w += $tmp_total;
            # reset the local counter
            $tmp_total = 0;
        }
        debug('total_received: '.$total_r) if($::debug > 4);
        debug('total_written: '.$total_w) if($::debug > 4);
        debug('total: '.$total) if($::debug > 4);
    } while(!$done);
    
    debug('writer done...') if($::debug > 1);
    
    $writer->close();
    $context->term();
    return;
}

sub _throttle {
    my $throttle = shift;

    require Linux::Cpuinfo;
    my $cpu = Linux::Cpuinfo->new();
    return(DEFAULT_THROTTLE_FACTOR()) unless($cpu);
    
    my $cores = $cpu->num_cpus();
    return(DEFAULT_THROTTLE_FACTOR()) unless($cores && $cores =~ /^\d+$/);
    return(DEFAULT_THROTTLE_FACTOR()) if($cores eq 1);
    
    return($cores * (DEFAULT_THROTTLE_FACTOR() * 2))  if($throttle eq 'high');
    return($cores * DEFAULT_THROTTLE_FACTOR())  if($throttle eq 'medium');
    return($cores / 2) if($throttle eq 'low');
}
