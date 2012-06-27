package CIF::Router;
use base 'Class::Accessor';

use strict;
use warnings;

## TODO -- this should be set my CIF::Message
our $VERSION = '0.99_02';
$VERSION = eval $VERSION;

use Try::Tiny;
use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Config::Simple;

require CIF::Archive;
require CIF::APIKey;
require CIF::APIKeyGroups;
use CIF qw/is_uuid generate_uuid_url/;
use CIF::Msg;
use CIF::Msg::Feed;

use Data::Dumper;

my @drivers = __PACKAGE__->plugins();

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(config db_config router_db_config driver driver_config restriction_map group_map groups feeds feeds_config));

sub new {
    my $class = shift;
    my $args = shift;
      
    return(undef,'missing config file') unless($args->{'config'});
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return(undef,'missing config file');
    
    my $self = {};
    bless($self,$class);
    $self->set_config($args->{'config'}->param(-block => 'router'));
    
    $self->set_db_config(       $args->{'config'}->param(-block => 'db'));
    $self->set_router_db_config($args->{'config'}->param(-block => 'router_db'));
    $self->set_restriction_map( $args->{'config'}->param(-block => 'restriction_map'));
    $self->set_group_map(       $args->{'config'}->param(-block => 'groups'));
    $self->set_feeds_config(    $args->{'config'}->param(-block => 'cif_feeds'));
   
    my $ret = $self->init($args);
    die $ret unless($ret);
     
    my $driver = $args->{'driver'} || 'REST';
    
    if($args->{'config'}->param(-block => 'router_'.lc($driver))){
        $self->set_driver_config($args->{'config'}->param(-block => 'router_'.lc($driver)));
        $args->{'driver_config'} = $self->get_driver_config();
    }
    
    if($driver){
        $driver = 'CIF::Router::'.$driver;
    
        my $err;
        try {
            $driver = $driver->new($args);
        } catch {
            $err = shift;
            warn $err;
        };
        $self->set_driver($driver);
    }
    return(undef,$self);
}

sub init {
    my $self = shift;
    my $args = shift;
    
    my $config = $self->get_db_config();
    
    my $db          = $config->{'database'} || 'cif';
    my $user        = $config->{'user'}     || 'postgres';
    my $password    = $config->{'password'} || '';
    my $host        = $config->{'host'}     || '127.0.0.1';
    
    my $dbi = 'DBI:Pg:database='.$db.';host='.$host;
    
    my $ret = CIF::DBI->connection($dbi,$user,$password,{ AutoCommit => 0});
    
    $self->init_restriction_map();
    $self->init_group_map();
    $self->init_feeds();   
    
    return ($ret);
}

sub init_feeds {
    my $self = shift;
    
    
    my $feeds = $self->get_feeds_config->{'enabled'} || return;
    $self->set_feeds($feeds);
}

sub init_restriction_map {
    my $self = shift;
    
    return unless($self->get_restriction_map());
    my $array;
    foreach (keys %{$self->get_restriction_map()}){
        
        ## TODO map to the correct Protobuf RestrictionType
        my $m = FeedType::MapType->new({
            key => $_,
            value   => $self->get_restriction_map->{$_},
        });
        push(@$array,$m);
    }
    $self->set_restriction_map($array);
}

sub init_group_map {
    my $self = shift;
    
    return unless($self->get_group_map());
    my $g = $self->get_group_map->{'groups'};
    
    # system wide groups
    push(@$g, qw(everyone root));
    my $array;
    foreach (@$g){
        my $m = FeedType::MapType->new({
            key     => generate_uuid_url($_),
            value   => $_,
        });
        push(@$array,$m);
    }
    $self->set_group_map($array);

}

sub authorized_read {
    my $self = shift;
    my $key = shift;
    
    # test1
    return('invaild apikey',0) unless(is_uuid($key));

    my $rec = CIF::APIKey->retrieve(uuid => $key);
    return('invaild apikey',0) unless($rec);
    return('apikey revokved',0) if($rec->revoked()); # revoked keys

    my $ret;
    my $args;
    my $guid = $args->{'guid'};
    if($guid){
        $guid = lc($guid);
        $ret->{'guid'} = generate_uuid_url($guid) unless(is_uuid($guid));
    } else {
        $ret->{'default_guid'} = $rec->default_guid();
    }
    
    ## TODO -- datatype access control?
    
    my @groups = ($self->get_group_map()) ? @{$self->get_group_map()} : undef;
   
    my @array;
    foreach my $g (@groups){
        next unless($rec->inGroup($g->get_key()));
        push(@array,$g);
    }

    $ret->{'group_map'} = \@array;
    
    if(my $m = $self->get_restriction_map()){
        $ret->{'restriction_map'} = $m;
    }

    return(undef,$ret); # all good
}

sub authorized_write {
    my $self = shift;
    my $key = shift;
    
    $key = lc($key);
    my $rec = CIF::APIKey->retrieve(uuid => $key);
    return(0) unless($rec && $rec->write());
    return(1);
}

sub process {
    my $self = shift;
    my $msg = shift;
    
    $msg = MessageType->decode($msg);
    
    my $reply = MessageType->new({
        version => $CIF::Msg::VERSION,
        type    => MessageType::MsgType::REPLY(),
        status  => MessageType::StatusType::FAILED(),
    });
    
    my $pversion = sprintf("%4f",$msg->get_version());
    if($pversion != $CIF::Msg::VERSION){
        $reply->set_data('invalid protocol version: '.$pversion.', should be: '.$CIF::Msg::VERSION);
        return $reply->encode();
    }
   
    for($msg->get_type()){
        if($_  == MessageType::MsgType::QUERY()){
            $reply = $self->process_query($msg);
            last;
        }
        if($_ == MessageType::MsgType::Type::SUBMISSION()){
            $reply = $self->process_submission($msg);
            last;
        }
    }
    
    ## TODO -- return err messages
    return $reply->encode();
}

sub process_query {
    my $self = shift;
    my $msg = shift;
    
    my $results = [];
    
    my $data = $msg->get_data();
    my $apikey_info;
    my $is_feed_query = 0;
    
    my $reply;
    my $authorized = 0;
    
    foreach my $m (@$data){
        $m = MessageType::QueryType->decode($m);
        # we can skip this if the first packet contains a valid apikey
        # later on; as we figure out what we're doing, we may want to
        # turn this off and check each time -- dunno why you'd search
        # with multiple apikeys; but just in case *shrug*
        unless($authorized){
            my $apikey = $m->get_apikey();
            my ($err, $ret) = $self->authorized_read($apikey);
            unless($ret){
                return(
                    MessageType->new({
                        version => $CIF::Msg::VERSION,
                        type    => MessageType::MsgType::REPLY(),
                        status  => MessageType::StatusType::UNAUTHORIZED(),
                        data    => $err,
                    })
                );
            }
            $apikey_info = $ret; 
        }
        $authorized = 1;
        my @res;
        foreach my $q (@{$m->get_query()}){   
            my $s = CIF::Archive->search({
                query           => $q->get_query(),
                limit           => $m->get_limit(),
                confidence      => $m->get_confidence(),
                guid            => $m->get_guid(),
                guid_default    => $apikey_info->{'default_guid'},
                nolog           => $q->get_nolog(),
                source          => $m->get_apikey(),
                description     => $m->get_description(),
            });
            next unless($s);
            push(@res,@$s);
        }
       
        if($#res > -1){
            ## TODO: SHIM, gatta be a more elegant way to do this
            unless($m->get_feed()){
                my $dt = DateTime->from_epoch(epoch => time());
                $dt = $dt->ymd().'T'.$dt->hms().'Z';
                
                my $f = FeedType->new({
                    version         => $CIF::Msg::VERSION,
                    confidence      => $m->get_confidence(),
                    description     => $m->get_description(),
                    ReportTime      => $dt,
                    group_map       => $apikey_info->{'group_map'}, # so they can't see other groups they're not in
                    restriction_map => $self->get_restriction_map(),
                    data            => \@res,
                });  
                push(@$results,$f->encode());
            } else {
                push(@$results,@res);
            }
        }
    }
                    
    $reply = MessageType->new({
        version => $CIF::Msg::VERSION,
        type    => MessageType::MsgType::REPLY(),
        status  => MessageType::StatusType::SUCCESS(),
        data    => $results,
    });

    return $reply;
}

sub process_submission {
    my $self = shift;
    my $msg = shift;
    
    warn 'type: submission...';
    my ($err, $ret) = $self->authorized_write($msg->get_apikey());
    my $reply;
    unless($ret){
        $reply = MessageType->new({
            version => $CIF::Msg::VERSION,
            type    => MessageType::MsgType::REPLY(),
            status  => MessageType::StatusType::UNAUTHORIZED(),
            data    => $err,
        })->encode();
        last;
    }
    my $array = $msg->get_data();
    my $guid = $msg->get_guid() || $ret->{'default_guid'};
    require CIF::Archive;
    ## TODO -- copy foreach loop from SMRT; commit every X objects
    foreach (@$array){
        my ($err,$r) = CIF::Archive->insert({
            data    => $_,
            guid    => $guid,
        });
        if($r){
            CIF::Archive->dbi_commit();
            warn 'insert successful: '.$r;
            $reply = $r;
        } else {
            CIF::Archive->dbi_rollback();
            warn 'insert unsuccessful...';
        }
    }
    ## TODO: create SUCESS REPLY
    return $reply;   
}

sub search {
    my $self = shift;
    my $args = shift;
    
    require CIF::Archive;
    my ($err,$ret) = CIF::Archive->search($args);
    
    return($err,$ret);
}

sub feed {
    my $self = shift;
    my $ret;
    
    my $dt = DateTime->from_epoch(epoch => time());
    $dt = $dt->ymd().'T'.$dt->hms().'Z';
    
    my $q = 'test';
    my $feed = Feed->new({
        entry       => $ret,
        restriction => RestrictionType::restriction_type_default(),
        description => 'search '.$q,
        updated     => $dt,
        group_map   => GroupMapType->new({
            [
                group   => MapType->new({
                    key => '1234',
                    value   => 'example.com',
                }),
                group   => MapType->new({
                    key => '1234',
                    value   => 'example2.com',
                }),
            ],
        }),
            
        ## TODO -- restriction / group mappings
    });
    
    $feed = $feed->encode();
}

sub send {}

1;