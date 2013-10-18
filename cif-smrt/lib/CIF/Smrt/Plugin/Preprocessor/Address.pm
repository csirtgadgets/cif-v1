package CIF::Smrt::Plugin::Preprocessor::Address;

use strict;
use warnings;

sub process {
    my $class = shift;
    my $rules = shift;
    my $rec = shift;
    
    return $rec unless($rec->{'address'});
    $rec->{'address'} = lc($rec->{'address'});
    return $rec;
}

1;
