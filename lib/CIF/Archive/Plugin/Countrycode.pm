package CIF::Archive::Plugin::Countrycode;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

__PACKAGE__->table('countrycode');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid cc confidence detecttime created/);
__PACKAGE__->sequence('countrycode_id_seq');

sub insert {
    my $class = shift;
    my $data = shift;

    my @ids;
    my $additional_data = $class->iodef_systems_additional_data($data->{'data'});
    foreach my $entry (@$additional_data){
        next unless($entry);
        next unless($entry->get_meaning() eq 'cc');
        next unless($entry->get_content() =~ /^[A-Za-z]{2}$/);
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