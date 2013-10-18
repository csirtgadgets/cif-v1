package CIF::Archive::Plugin::Malware::Md5;
use base 'CIF::Archive::Plugin::Malware';

use strict;
use warnings;

__PACKAGE__->table('malware_md5');

sub prepare {
    my $class = shift;
    my $data = shift;
    return unless(lc($data) =~ /^[a-f0-9]{32}$/);
    return(1);
}

sub query {
    my $class = shift;
    my $data = shift;
    
    return unless($class->prepare($data->{'query'}));
    return $class->search_lookup(
        $data->{'query'},
        $data->{'confidence'},
        $data->{'limit'},
    );
}

1;
