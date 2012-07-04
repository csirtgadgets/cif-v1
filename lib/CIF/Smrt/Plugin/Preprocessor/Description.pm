package CIF::Smrt::Plugin::Preprocessor::Description;

use strict;
use warnings;

sub process {
    my $class = shift;
    my $rules = shift;
    my $rec = shift;

    $rec->{'assessment'} = lc($rec->{'assessment'});
    unless($rec->{'description'}){
        $rec->{'description'} = 'unknown';
    } else {
        $rec->{'description'} = lc($rec->{'description'});
    }
    return $rec;
}

1;
