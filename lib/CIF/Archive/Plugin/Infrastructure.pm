package CIF::Archive::Plugin::Infrastructure;
use base 'CIF::Archive::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;

use Try::Tiny;

my @plugins = __PACKAGE__->plugins();

__PACKAGE__->table('infrastructure');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid address portlist protocol confidence detecttime created/);
__PACKAGE__->columns(Essential => qw/id uuid guid address portlist protocol confidence detecttime created/);
__PACKAGE__->sequence('infrastructure_id_seq');

sub insert {
    my $class = shift;
    my $data = shift;
    
    my $tbl = $class->table();
    foreach(@plugins){
        if($_->prepare($data)){
            $class->table($_->table());
        }
    }

    my $uuid = $data->{'uuid'};
    my $portlist;
    my $protocol;
    my $confidence = $class->iodef_confidence($data->{'data'});
    $confidence = @{$confidence}[0]->get_content();
    
    my $msg = $data->{'data'};
    
    my @ids;
    my $addresses = $class->iodef_addresses($data->{'data'});
    return unless(@$addresses);
    foreach my $a (@$addresses){
        # we have to check for both because of urls that look like:
        # 1.1.1.1/abc.html
        next unless($a->get_content() =~ /^$RE{'net'}{'IPv4'}$/ || $a->get_content() =~ /^$RE{'net'}{'CIDR'}{'IPv4'}$/);

        my $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            address     => $a->get_content(),
            confidence  => $confidence,
            portlist    => $portlist,
            protocol    => $protocol,
        });
        push(@ids,$id);
        
        ## TODO -- clean this up into a function, map with ipv6
        ## it'll evolve into pushing this search into the hash table
        ## the client will then do the final leg of the work (Net::Patricia, etc)
        ## right now postgres can do it, but down the road hadoop might not
        ## this way we can do faster hash lookups for non-advanced CIDR queries
        my @array = split(/\./,$a->get_content());
        my @array2 = (
            $array[0].'.0.0.0/8',
            $array[0].'.'.$array[1].'.0.0/16',
            $array[0].'.'.$array[1].'.'.$array[2].'.0/24',
            $a->get_content(),
        );
        foreach (@array2){
            $id = $class->insert_hash($data,$_);
        }
    }
    return(undef,@ids);
}

sub query {
    my $class = shift;
    my $data = shift;
    
    my $q = $data->{'query'};
    return(undef) unless($q && $q =~ /^$RE{'net'}{'IPv4'}/);
    
    # work-around for some domains
    return if($q =~ /^[a-zA-Z0-9.-]+\.[a-z]{2,6}$/);
    
    my $ret;
    if($data->{'guid'}){
        $ret = $class->search_lookup_guid(
            $q,
            $q,
            $data->{'confidence'},
            $data->{'guid'},
            $data->{'limit'}
        );
    } elsif($q =~ /^$RE{'net'}{'IPv4'}$/){
        $ret = $class->search_lookup(
            $q,
            $q,
            $data->{'confidence'},
            $data->{'source'},
            $data->{'limit'},
        );
    } elsif($q =~ /^$RE{'net'}{'CIDR'}{'IPv4'}$/){
        $ret = $class->search_lookup_cidr(
            $q,
            $data->{'confidence'},
            $data->{'source'},
            $data->{'limit'},
        );
    }
    return $ret;
}

__PACKAGE__->set_sql('lookup' => qq{
    SELECT t.id, t.uuid, archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups on t.guid = apikeys_groups.guid
    LEFT JOIN archive ON t.uuid = archive.uuid
    WHERE 
        (address <<= ? OR address >>= ?)
        AND confidence >= ?
        AND apikeys_groups.uuid = ?
        AND archive.uuid IS NOT NULL
    ORDER BY t.detecttime DESC, t.created DESC, t.id DESC
    LIMIT ?
});

__PACKAGE__->set_sql('lookup_guid' => qq{
    SELECT t.id,t.uuid, archive.data
    FROM __TABLE__ t
    LEFT JOIN archive ON archive.uuid = t.uuid
    WHERE 
        (address <<= ? OR address >>= ?)
        AND confidence >= ?
        AND t.guid = ?
        AND archive.uuid IS NOT NULL
    ORDER BY t.detecttime DESC, t.created DESC, t.id DESC
    LIMIT ?
});

__PACKAGE__->set_sql('lookup_cidr' => qq{
    SELECT t.id, t.uuid, archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups on t.guid = apikeys_groups.guid
    LEFT JOIN archive ON t.uuid = archive.uuid
    WHERE 
        address <<= ?
        AND confidence >= ?
        AND apikeys_groups.uuid = ?
    ORDER BY t.detecttime DESC, t.created DESC, t.id DESC
    LIMIT ?
});
    
1;
