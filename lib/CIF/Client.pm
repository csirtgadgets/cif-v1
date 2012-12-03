package CIF::Client;
use base 'Class::Accessor';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Try::Tiny;
use Config::Simple;
use Digest::SHA1 qw/sha1_hex/;
use Compress::Snappy;
use MIME::Base64;
use Iodef::Pb::Simple qw/iodef_addresses iodef_confidence iodef_impacts/;
use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;
use Net::Patricia;
use URI::Escape;
use Digest::SHA1 qw/sha1_hex/;
use Digest::MD5 qw/md5_hex/;
use Encode qw(encode_utf8);

use CIF qw(generate_uuid_ns debug);
use CIF::Msg;
use CIF::Msg::Feed;

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(
    config driver_config global_config driver apikey 
    nolog limit guid filter_me no_maprestrictions
    table_nowarning related
));

our @queries = __PACKAGE__->plugins();
@queries = map { $_ =~ /::Query::/ } @queries;

sub new {
    my $class = shift;
    my $args = shift;
    
    return('missing config file') unless($args->{'config'});
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return('missing config file');
    
    my $self = {};
    bless($self,$class);
    
    $self->set_global_config(   $args->{'config'});
    $self->set_config(          $args->{'config'}->param(-block => 'client'));
    $self->set_driver(          $self->get_config->{'driver'} || 'HTTP');
    $self->set_driver_config(   $args->{'config'}->param(-block => 'client_'.lc($self->get_driver())));
    $self->set_apikey(          $args->{'apikey'} || $self->get_config->{'apikey'});
    
    $self->{'guid'}             = $args->{'guid'}               || $self->get_config->{'default_guid'};
    $self->{'limit'}            = $args->{'limit'}              || $self->get_config->{'limit'};
    $self->{'compress_address'} = $args->{'compress_address'}   || $self->get_config->{'compress_address'};
    $self->{'round_confidence'} = $args->{'round_confidence'}   || $self->get_config->{'round_confidence'};
    $self->{'table_nowarning'}  = $args->{'table_nowarning'}    || $self->get_config->{'table_nowarning'};
    
    $self->{'group_map'}        = (defined($args->{'group_map'})) ? $args->{'group_map'} : $self->get_config->{'group_map'};
    
    $self->set_no_maprestrictions(  $args->{'no_maprestrictions'}   || $self->get_config->{'no_maprestrictions'});
    $self->set_filter_me(           $args->{'filter_me'}            || $self->get_config->{'filter_me'});
    $self->set_nolog(               $args->{'nolog'}                || $self->get_config->{'nolog'});
    $self->set_related(             $args->{'related'}              || $self->get_config->{'related'});
    
    my $nolog = (defined($args->{'nolog'})) ? $args->{'nolog'} : $self->get_config->{'nolog'};
    
    if($args->{'fields'}){
        @{$self->{'fields'}} = split(/,/,$args->{'fields'}); 
    } 
    
    my $driver     = 'CIF::Client::Transport::'.$self->get_driver();
    my $err;
    try {
        $driver     = $driver->new({
            config  => $self->get_driver_config()
        });
    } catch {
        $err = shift;
    };
    if($err){
        debug($err) if($::debug);
        return($err);
    }
    
    $self->set_driver($driver);
    return (undef,$self);
}

sub search {
    my $self = shift;
    my $args = shift;
    
    my $filter_me   = $args->{'filter_me'} || $self->get_filter_me();
    my $nolog       = (defined($args->{'nolog'})) ? $args->{'nolog'} : $self->get_nolog();
    
    unless($args->{'apikey'}){
        $args->{'apikey'} = $self->get_apikey();
    }

    unless(ref($args->{'query'}) eq 'ARRAY'){
        my @a = split(/,/,$args->{'query'});
        $args->{'query'} = \@a;
    }
    
    my @queries;
    my @orig_queries = @{$args->{'query'}};
    
    # we have to pass this along so we can check it later in the code
    # for our original queries since the server will give us back more 
    # than we asked for
    my $ip_tree = Net::Patricia->new();
    
    debug('generating query') if($::debug);
    foreach my $q (@{$args->{'query'}}){
        my ($err,$ret) = CIF::Client::Query->new({
            query       => $q,
            apikey      => $args->{'apikey'},
            limit       => $args->{'limit'},
            confidence  => $args->{'confidence'},
            guid        => $args->{'guid'},
            nolog       => $args->{'nolog'},
            description => $args->{'description'} || 'search '.$q,
            pt          => $ip_tree,
            
            ## TODO -- not sure how else to do this atm
            ## needs to be passed to the IPv4 query so we
            ## can get back the tree and check it against the feed
        });
        return($err) if($err);
        push(@queries,$ret) if($ret);
    }        
        
    my $msg = MessageType->new({
        version => $CIF::VERSION,
        type    => MessageType::MsgType::QUERY(),
        # encode it here, message type only knows about bytes
        ## TODO -- the Query Packet should have each of these attributes (confidence, nolog, guid, limit)
        ## query shouldn't be repated the QueryType should foreach ($args->{'query'})
        data    => \@queries,
    });
    
    debug('sending query') if($::debug);
    my ($err,$ret) = $self->send($msg->encode());
    
    return $err if($err);
    $ret = MessageType->decode($ret);
 
    unless($ret->get_status() == MessageType::StatusType::SUCCESS()){
        return('failed: '.@{$ret->get_data()}[0]) if($ret->get_status() == MessageType::StatusType::FAILED());
        return('unauthorized') if($ret->get_status() == MessageType::StatusType::UNAUTHORIZED());
    }
    return(0) unless($ret->{'data'});
    my $uuid = generate_uuid_ns($args->{'apikey'});

    debug('decoding...') if($::debug);
        ## TODO: finish this so feeds are inline with reg queries
    ## TODO: try to base64 decode and decompress first in try { } catch;
    foreach my $feed (@{$ret->get_data()}){
        my @array;
        my $err;
        my $test;
        try {
            $test = Compress::Snappy::decompress(decode_base64($feed));
        } catch {
            $err = shift;
        };
        $feed = $test if($test);
        $err = undef;

        try {
            $feed = FeedType->decode($feed);
        } catch {
            $err = shift;
        };
        if($err){
            return($err);
        }
        next unless($feed->get_data());
        my %uuids;
        debug('processing: '.$#{$feed->get_data}.' items') if($::debug);
        foreach my $e (@{$feed->get_data()}){
            $e = Compress::Snappy::decompress(decode_base64($e));
            $e = IODEFDocumentType->decode($e);
            if($filter_me){
                my $id = @{$e->get_Incident()}[0]->get_IncidentID->get_name();
                # filter out my searches
                next if($id eq $uuid);
            }
            my $docid = @{$e->get_Incident()}[0]->get_IncidentID->get_content();
            if($ip_tree->climb()){
                my $addresses = iodef_addresses($e);
                
                # if there are no addresses, we've got nothing or hashes
                my $found = (@$addresses) ? 0 : 1;
                foreach my $a (@$addresses){
                    next unless ($a->get_content =~ /^$RE{'net'}{'IPv4'}/);               
                    # if we have a match great
                    # if we don't we need to test and see if this address
                    # contains our original query
                    unless($ip_tree->match_string($a->get_content())){
                        my $ip_tree2 = Net::Patricia->new();
                        $ip_tree2->add_string($a->get_content());
                        foreach (@orig_queries){
                            ## TODO -- work-around for uuid searches
                            unless(/^$RE{'net'}{'IPv4'}/){ $found = 1; last; }
                            if($ip_tree2->match_string($_)){
                                $found = 1;
                                last;
                            }
                        }
                    } else {
                        $found = 1;
                        last;
                    }
                }
                next unless($found);
            }
            unless($uuids{$docid}){
                push(@array,$e);
                $uuids{$docid} = 1;
            }
        }
        if($#array > -1){
            debug('final results: '.$#array) if($::debug);
            $feed->set_data(\@array);
        } else {
            $feed->set_data(undef);
        }
    }
    
    debug('done processing');
    return(undef,$ret->get_data());
}

sub send {
    my $self = shift;
    my $msg = shift;
    
    return $self->get_driver->send($msg);
}

sub submit {
    my $self = shift;
    my $data = shift;
    
    my $msg = MessageType->new({
        version => $CIF::VERSION,
        type    => MessageType::MsgType::SUBMISSION(),
        apikey  => $self->get_apikey(),
        # encode it here, message type only knows about bytes
        ## TODO -- the Query Packet should have each of these attributes (confidence, nolog, guid, limit)
        ## query shouldn't be repated the QueryType should foreach ($args->{'query'})
        data    => $data,
    });
    
    my ($err,$ret) = $self->send($msg->encode());
    return('ERROR: server failure, contact system administrator') unless($ret);
    
    $ret = MessageType->decode($ret);
    
    unless($ret->get_status() == MessageType::StatusType::SUCCESS()){
        return('ERROR: '.@{$ret->get_data()}[0]) if($ret->get_status() == MessageType::StatusType::FAILED());
        return('ERROR: unauthorized') if($ret->get_status() == MessageType::StatusType::UNAUTHORIZED());
    }
    
    return (undef,$ret);
}    

sub new_submission {
    my $self = shift;
    my $args = shift;
    
    my $data = (ref($args->{'data'}) eq 'ARRAY') ? $args->{'data'} : [$args->{'data'}];

    foreach (@$data){
        $_ = encode_base64(Compress::Snappy::compress($_));
    }
    
    my $msg = MessageType::SubmissionType->new({
        guid    => $args->{'guid'},
        data    => $data,
    });

    return $msg->encode();
}

# confor($conf, ['infrastructure/botnet', 'client'], 'massively_cool_output', 0)
#
# search the given sections, in order, for the given config param. if found, 
# return its value or the default one specified.

sub confor {
    my $conf = shift;
    my $sections = shift;
    my $name = shift;
    my $def = shift;

    # return unless we get called with a config (eg: via the WebAPI)
    return unless($conf->{'config'});

    # handle
    # snort_foo = 1,2,3
    # snort_foo = "1,2,3"

    foreach my $s (@$sections) { 
        my $sec = $conf->{'config'}->param(-block => $s);
        next if isempty($sec);
        next if !exists $sec->{$name};
        if (defined($sec->{$name})) {
            return ref($sec->{$name} eq "ARRAY") ? join(', ', @{$sec->{$name}}) : $sec->{$name};
        } else {
            return $def;
        }
    }
    return $def;
}

sub isempty {
    my $h = shift;
    return 1 unless ref($h) eq "HASH";
    my @k = keys %$h;
    return 1 if $#k == -1;
    return 0;
}

1;