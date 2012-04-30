package CIF::Archive::Plugin::Hash;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

# work-around for cif-v1
use Regexp::Common qw/net/;
use Digest::SHA1 qw(sha1_hex);


__PACKAGE__->table('hash');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence detecttime created data/);
__PACKAGE__->sequence('hash_id_seq');

my @plugins = __PACKAGE__->plugins();

sub prepare {}

sub insert {
    my $class = shift;
    my $data = shift;
    
    return unless($data->{'hash'});

    $data->{'hash'} = lc($data->{'hash'});
    my $tbl = $class->table();
    foreach (@plugins){
        next unless($_->prepare($data->{'hash'}));
        $class->table($_->table());
        last;
    }
        
    my $id = $class->SUPER::insert({
        uuid        => $data->{'uuid'},
        guid        => $data->{'guid'},
        confidence  => $data->{'confidence'},
        hash        => $data->{'hash'},
    });
    
    $class->table($tbl);
    return($id);
}

sub query {
    my $class   = shift;
    my $data    = shift;
    
    # work-around for cif-v1
    # till we can add this to the client
    #return if($data->{'query'} =~ /^$RE{'net'}{'IPv4'}/);
    #unless($data->{'query'}=~ /^([a-f0-9]{32}|[a-f0-9]{40})$/){
    #     $data->{'query'} = sha1_hex($data->{'query'});
    #}
    # end
    
    foreach (@plugins){
        my $r = $_->query($data);
        return ($r) if($r && $r->count());
    }
    return;
}

__PACKAGE__->set_sql('lookup' => qq{
    SELECT t.id,t.uuid,archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups on t.guid = apikeys_groups.guid
    LEFT JOIN archive ON archive.uuid = t.uuid
    WHERE 
        hash = ?
        AND confidence >= ?
        AND apikeys_groups.uuid = ?
        AND archive.uuid IS NOT NULL
    ORDER BY t.detecttime DESC, t.created DESC, t.id DESC
    LIMIT ?
});

__PACKAGE__->set_sql('lookup_guid' => qq{
    SELECT t.id,t.uuid,archive.data
    FROM __TABLE__ t
    LEFT JOIN archive ON archive.uuid = t.uuid
    WHERE 
        hash = ?
        AND confidence >= ?
        AND t.guid = ?
        AND archive.uuid IS NOT NULL
    ORDER BY t.detecttime DESC, t.created DESC, t.id DESC
    LIMIT ?
});

1;