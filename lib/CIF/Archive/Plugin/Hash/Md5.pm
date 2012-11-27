package CIF::Archive::Plugin::Hash::Md5;
use base 'CIF::Archive::Plugin::Hash';

use strict;
use warnings;

__PACKAGE__->table('hash_md5');

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
