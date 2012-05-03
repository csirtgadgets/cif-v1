package CIF::Router;
use base 'Class::Accessor';

use strict;
use warnings;

## TODO -- this should be set my CIF::Message
our $VERSION = '0.99_01';
$VERSION = eval $VERSION;

use Try::Tiny;
use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Config::Simple;

require CIF::Archive;
require CIF::APIKey;
require CIF::APIKeyGroups;
use CIF qw/is_uuid generate_uuid_url/;
use CIF::Message;

use Data::Dumper;

my @drivers = __PACKAGE__->plugins();

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(config db_config router_db_config driver driver_config restriction_map group_map groups));

sub new {
    my $class = shift;
    my $args = shift;
      
    return(undef,'missing config file') unless($args->{'config'});
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return(undef,'missing config file');
    
    my $self = {};
    bless($self,$class);
    $self->set_config($args->{'config'}->param(-block => 'router'));
    
    $self->set_db_config($args->{'config'}->param(-block => 'db'));
    $self->set_router_db_config($args->{'config'}->param(-block => 'router_db'));
    
    $self->set_restriction_map($args->{'config'}->param(-block => 'restriction_map'));
        
    my $ret = $self->init($args);
    die $ret unless($ret);
     
    my $driver = $args->{'driver'};
    
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
    return ($ret);
}

sub init_restriction_map {
    my $self = shift;
    
    return unless($self->get_restriction_map());
    my $array;
    foreach (keys %{$self->get_restriction_map()}){
        
        ## TODO map to the correct Protobuf RestrictionType
        my $m = MessageType::MapType->new({
            key => $_,
            value   => $self->get_restriction_map->{$_},
        });
        push(@$array,$m);
    }
    $self->set_restriction_map($array);
}

sub init_group_map {
    my $self = shift;
    
    return unless($self->get_config->{'groups'});
    my @g = split(/,/,$self->get_config->{'groups'});
    
    # system wide groups
    push(@g, qw(everyone root));
    my $array;
    foreach (@g){
        my $m = MessageType::MapType->new({
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
    
    my @groups = @{$self->get_group_map()};
   
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
        type    => MessageType::MsgType::REPLY(),
        status  => MessageType::StatusType::FAILED(),
    });
    
    my $pversion = sprintf("%4f",$msg->get_version());
    if($pversion != $CIF::Message::VERSION){
        $reply->set_data('invalid protocol version: '.$pversion.', should be: '.$VERSION);
        return $reply->encode();
    }
       
    for($msg->get_type()){
        if($_  == MessageType::MsgType::QUERY()){
            my $data = MessageType::QueryType->decode(@{$msg->get_data()}[0]);
            my ($err, $ret) = $self->authorized_read($data->get_apikey());
            unless($ret){
                $reply = MessageType->new({
                    type    => MessageType::MsgType::REPLY(),
                    status  => MessageType::StatusType::UNAUTHORIZED(),
                    data    => $err,
                })->encode();
                last;
            }
            my $queries = $data->get_query();
            my @results;
            foreach my $q (@$queries){
                my $s = CIF::Archive->search({
                    query           => $q,
                    limit           => $data->get_limit(),
                    confidence      => $data->get_confidence(),
                    guid            => $data->get_guid(),
                    guid_default    => $ret->{'default_guid'},
                    nolog           => $data->get_nolog(),
                    source          => $data->get_apikey(),
                });
                push(@results,@$s) if($s);
            }
            my $dt = DateTime->from_epoch(epoch => time());
            $dt = $dt->ymd().'T'.$dt->hms().'Z';
         
            my $rep = MessageType->new({
                type    => MessageType::MsgType::REPLY(),
                status  => MessageType::StatusType::SUCCESS(),
                data    => MessageType::ReplyType->new({
                    feed    => MessageType::ReplyType::FeedType->new({
                        description     => 'search',
                        updated         => $dt,
                        restriction     => RestrictionType::restriction_type_private(),
                        restriction_map => $ret->{'restriction_map'},
                        group_map       => $ret->{'group_map'},
                        entry           => \@results,
                    }),
                })->encode(),
            });
            
            $reply = $rep->encode();
            last;
        }
        if($_ == MessageType::MsgType::Type::SUBMISSION()){
            warn 'type: submission...';
            my ($err, $ret) = $self->authorized_write($msg->get_apikey());
            unless($ret){
                $reply = MessageType->new({
                    type    => MessageType::MsgType::REPLY(),
                    status  => MessageType::StatusType::UNAUTHORIZED(),
                    data    => $err,
                })->encode();
                last;
            }
            my $array = $msg->get_data();
            my $guid = $msg->get_guid() || $ret->{'default_guid'};
            require CIF::Archive;
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
        }
    }
    
    ## TODO -- return err messages
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