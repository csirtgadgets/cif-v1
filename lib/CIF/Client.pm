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
use Iodef::Pb::Simple;
use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;
use Net::Patricia;
use URI::Escape;
use Digest::SHA1 qw/sha1_hex/;
use Digest::MD5 qw/md5_hex/;
use Encode qw(encode_utf8);

use CIF qw(generate_uuid_ns);
use CIF::Msg;
use CIF::Msg::Feed;

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(
    config driver_config driver apikey 
    nolog limit guid filter_me no_maprestrictions
    table_nowarning
));

our @plugins = __PACKAGE__->plugins();

sub new {
    my $class = shift;
    my $args = shift;
    
    return(undef,'missing config file') unless($args->{'config'});
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return(undef,'missing config file');
    
    my $self = {};
    bless($self,$class);
    
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
    
    my $nolog = (defined($args->{'nolog'})) ? $args->{'nolog'} : $self->get_config->{'nolog'};
    
    if($args->{'fields'}){
        @{$self->{'fields'}} = split(/,/,$args->{'fields'}); 
    } 
    
    my $driver     = 'CIF::Client::'.$self->get_driver();
    
    try {
        $driver     = $driver->new({
            config  => $self->get_driver_config()
        });
    } catch {
        my $err = shift;
        warn $err;
    };
    
    $self->set_driver($driver);
    return (undef,$self);
}

sub send {
    my $self = shift;
    my $msg = shift;
    
    return $self->get_driver->send($msg);
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
    
    my $pt;
    my @queries;
    my @orig_queries;
    
    ## TODO -- keep track of the actual query vs the index search
    ## apply NOLOG to each of the queries
    
    ## TODO -- client should have search plugins for queries (eg: ip, domain, ..)
    ## get this code out of here..
    
    foreach my $q (@{$args->{'query'}}){
        if(lc($q) =~ /^http(s)?:\/\//){
            $q =~ s/\/$//g;
            ## escape unsafe chars, that's what the data-warehouse does
            ## TODO -- doc this
            $q = uri_escape($q,'\x00-\x1f\x7f-\xff');
        }
        ## TODO -- double check this
        $q = lc($q);
        
        ## TODO -- fix this regex a bit
        if($q =~ /^([a-z\/]+([0-9])?)$/){
            my @bits = split(/\//,$q);
            my $qq = join(' ',reverse(@bits)).' feed';
            my %args2 = %$args;
            delete($args2{'query'});
            $args2{'description'} = 'search '.$qq;
            $args2{'limit'} = 1;
            ## TODO: this is a hack, gatta find a better way to handle these
            $args2{'feed'} = 1;
            
            ## TODO: fix this, if we log a feed search, the next search this will pop-up
            ##       instead of the feed itself (since we're looking at the hash table)
            $args->{'nolog'} = 1;
            
            ## TODO -- this could cause problems based on what comes in through the api
            ## feeds we wanna default higher than regular searches... i think..?
            $args2{'confidence'} = ($args->{'confidence'}) ? $args->{'confidence'} : 85;
            push(@queries, $self->new_query({ query => [ {query => $qq, nolog => $args->{'nolog'}}], %args2 }));
        } elsif($q =~ /^$RE{'net'}{'IPv4'}$/){
            $pt = Net::Patricia->new();
            $pt->add_string($q);
            push(@orig_queries,$q);
            my @array = split(/\./,$q);
            
            # we're gonna overwrite the original
            # keep the rest of the data
            my %args2 = %$args;
            $args2{'filter_me'} = $filter_me;
            $args2{'description'} = 'search '.$q;
            delete($args2{'query'});
         
            # we wanna keep the first 'nolog'
            push(@queries, (
                $self->new_query({ 
                    query => [
                        { query => $q,                                              nolog => $args2{'nolog'} },
                        { query => $array[0].'.'.$array[1].'.'.$array[2].'.0/24',   nolog => 1, },
                        { query => $array[0].'.'.$array[1].'.0.0/16',               nolog => 1, },
                        { query => $array[0].'.0.0.0/8',                            nolog => 1, },
                    ],
                    %args2
                }),
            ));
        } elsif ($q =~ /^$RE{'net'}{'CIDR'}{'IPv4'}{-keep}$/){
            $pt = Net::Patricia->new();
            $pt->add_string($q);
            push(@orig_queries,$q);
            my $addr = $1;
            my $mask = $2;  
            my @array = split(/\./,$addr);
            return 'mask too low; minimum value is 8' if($mask < 8);
            
            my %args2 = %$args;
            delete($args2{'nolog'});
            delete($args2{'query'});
            $args2{'description'} = 'search '.$q;
            
            my @x;
            
            for($mask){
                if($_ > 8){
                    push(@x, { query => $array[0].'.0.0.0/8', nolog => 1 });
                }
                if($_ > 16){
                    push(@x, { query => $array[0].'.'.$array[1].'.0.0/16', nolog => 1 });
                }
                if($_ > 24){
                    push(@x, { query => $array[0].'.'.$array[1].'.'.$array[2].'.0/24', nolog => 1 });
                }
            }
            push(@x, { query => $q, nolog => $args->{'nolog'} });
            push(@queries, $self->new_query({ query => \@x, %args2 }));
        } else {
            my %args2 = %$args;
            delete($args2{'query'});
            $args2{'description'} = 'search '.$q;
            push(@queries, $self->new_query({ query => [ { query => $q, nolog => $args->{'nolog'}} ],%args2 }));
            #die ::Dumper(@queries);
        }
    }
        
    my $msg = MessageType->new({
        version => $CIF::VERSION,
        type    => MessageType::MsgType::QUERY(),
        # encode it here, message type only knows about bytes
        ## TODO -- the Query Packet should have each of these attributes (confidence, nolog, guid, limit)
        ## query shouldn't be repated the QueryType should foreach ($args->{'query'})
        data    => \@queries,
    });
    
    my ($err,$ret) = $self->send($msg->encode());
    
    return $err if($err);
    $ret = MessageType->decode($ret);
 
    unless($ret->get_status() == MessageType::StatusType::SUCCESS()){
        return('failed: '.@{$ret->get_data()}[0]) if($ret->get_status() == MessageType::StatusType::FAILED());
        return('unauthorized') if($ret->get_status() == MessageType::StatusType::UNAUTHORIZED());
    }
    return(0) unless($ret->{'data'});
    my $uuid = generate_uuid_ns($args->{'apikey'});

    warn 'processing...' if($::debug);
   
    ## TODO: finish this so feeds are inline with reg queries
    ## TODO: try to base64 decode and decompress first in try { } catch;
    foreach my $feed (@{$ret->get_data()}){
        my @array;
        my $err;
        my $test = Compress::Snappy::decompress(decode_base64($feed));
        $feed = $test if($test);
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
        foreach my $e (@{$feed->get_data()}){
            $e = Compress::Snappy::decompress(decode_base64($e));
            $e = IODEFDocumentType->decode($e);
            if($filter_me){
                my $id = @{$e->get_Incident()}[0]->get_IncidentID->get_name();
                # filter out my searches
                next if($id eq $uuid);
            }
            my $docid = @{$e->get_Incident()}[0]->get_IncidentID->get_content();
            if($pt){
                my $addresses = $self->iodef_addresses($e);
                
                # if there are no addresses, we've got nothing or hashes
                my $found = (@$addresses) ? 0 : 1;
                foreach my $a (@$addresses){                    
                    # if we have a match great
                    # if we don't we need to test and see if this address
                    # contains our original query
                    unless($pt->match_string($a->get_content())){
                        my $pt2 = Net::Patricia->new();
                        $pt2->add_string($a->get_content());
                        foreach (@orig_queries){
                            if($pt2->match_string($_)){
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
        $feed->set_data(\@array);
    }
    return(undef,$ret->get_data());
}

sub new_query {
    my $self    = shift;
    my $args    = shift;
   
    my $msg = MessageType::QueryType->new({
        apikey      => $args->{'apikey'},
        limit       => $args->{'limit'},
        confidence  => $args->{'confidence'},
        guid        => $args->{'guid'},
        description => $args->{'description'},
        
        ## TODO: clean this up...
        feed        => $args->{'feed'},
    });
    
    my $q = $args->{'query'};

    foreach my $qq (@$q){
        $qq->{'query'} = sha1_hex($qq->{'query'}) unless($qq->{'query'} =~ /^[a-f0-9]{40}$/);
        $qq = MessageType::QueryStruct->new({
            query   => $qq->{'query'},
            nolog   => $qq->{'nolog'},
        });
    }
    $msg->set_query($q);
     
    return $msg->encode();
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
  
    $ret = MessageType->decode($ret);
 
    unless($ret->get_status() == MessageType::StatusType::SUCCESS()){
        return('failed: '.@{$ret->get_data()}[0]) if($ret->get_status() == MessageType::StatusType::FAILED());
        return('unauthorized') if($ret->get_status() == MessageType::StatusType::UNAUTHORIZED());
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

sub iodef_addresses {
    my $class = shift;
    my $iodef = shift;
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        next unless($i->get_EventData());
        foreach my $e (@{$i->get_EventData()}){
            my @flows = (ref($e->get_Flow()) eq 'ARRAY') ? @{$e->get_Flow()} : $e->get_Flow();
            foreach my $f (@flows){
                my @systems = (ref($f->get_System()) eq 'ARRAY') ? @{$f->get_System()} : $f->get_System();
                foreach my $s (@systems){
                    my @nodes = (ref($s->get_Node()) eq 'ARRAY') ? @{$s->get_Node()} : $s->get_Node();
                    foreach my $n (@nodes){
                        my $addresses = $n->get_Address();
                        $addresses = [$addresses] if(ref($addresses) eq 'AddressType');
                        push(@array,@$addresses);
                    }
                }
            }
        }
    }
    return(\@array);
}


1;
