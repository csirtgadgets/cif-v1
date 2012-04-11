package CIF::Archive::Plugin::Domain::Phishing;
use base 'CIF::Archive::Plugin::Domain';

use strict;
use warnings;

sub prepare {
    my $class = shift;
    my $data = shift;

    my $impact = $class->iodef_impacts_first($data->{'data'});
        
    return unless($impact =~ /phish/);
    return 1;
}   

1;