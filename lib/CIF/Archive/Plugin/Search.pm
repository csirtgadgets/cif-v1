package CIF::Archive::Plugin::Search;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Digest::SHA1 qw/sha1_hex/;

use Try::Tiny;

__PACKAGE__->table('search');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence detecttime created/);
__PACKAGE__->sequence('search_id_seq');

my @plugins = __PACKAGE__->plugins();

sub query { } # handled by the hash module

sub insert {
    my $class = shift;
    my $data = shift;

    my $tbl = $class->table();
    foreach(@plugins){
        if($_->prepare($data)){
            $class->table($class->sub_table($_));
            last;
        }
    }
    my $uuid = $data->{'uuid'};
    my $confidence  = 50;
    
    my @ids;
    my $additional_data = $class->iodef_additional_data($data->{'data'});
    return unless(@$additional_data);
    foreach my $entry (@$additional_data){
        ## TODO -- split this into plugins MD5, SHA1, UUID
        next unless($entry);
        next unless($entry->get_meaning() eq 'sha1');
        next unless($entry->get_content() =~ /^[a-f0-9]{40}$/);
        my $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            hash        => $entry->get_content(),
            confidence  => $confidence,
        });
        push(@ids,$id);
        $id = $class->insert_hash($data,$entry->get_content());
    }    
      
    $class->table($tbl);
    return(undef,\@ids);
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT on (__TABLE__.uuid) __TABLE__.uuid, confidence, archive.data
    FROM __TABLE__
    LEFT JOIN archive ON __TABLE__.uuid = archive.uuid
    WHERE
        detecttime >= ?
        AND __TABLE__.confidence >= ?
    ORDER BY __TABLE__.uuid ASC, __TABLE__.id ASC
    LIMIT ?
});

1;