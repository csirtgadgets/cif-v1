package CIF::Archive::Plugin::Hash;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

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
    
    my $q = $data->{'query'};
    foreach (@plugins){
        my $r = $_->query($data);
        return ($r) if($r->count());
    }
    return;
}

__PACKAGE__->set_sql('query' => qq{
    SELECT __TABLE__.id,__TABLE__.uuid, archive.data
    FROM __TABLE__
    LEFT JOIN archive ON archive.uuid = __TABLE__.uuid
    WHERE 
        hash = ?
        AND confidence >= ?
    ORDER BY __TABLE__.detecttime DESC, __TABLE__.created DESC, __TABLE__.id DESC
    LIMIT ?
});


1;