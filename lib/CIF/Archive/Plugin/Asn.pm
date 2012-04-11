package CIF::Archive::Plugin::Asn;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

__PACKAGE__->table('asn');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid asn confidence detecttime created/);
__PACKAGE__->sequence('asn_id_seq');

sub insert {
    my $class = shift;
    my $data = shift;

    my @ids;
    my $additional_data = $class->iodef_systems_additional_data($data->{'data'});
    foreach my $entry (@$additional_data){
        next unless($entry);
        next unless($entry->get_meaning() eq 'asn');
        next unless($entry->get_content() =~ /^\d+/);
        my $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            cc          => $entry->get_content(),
            confidence  => 50,
        });
        push(@ids,$id);
    }  
    return(undef,\@ids);        
}

1;