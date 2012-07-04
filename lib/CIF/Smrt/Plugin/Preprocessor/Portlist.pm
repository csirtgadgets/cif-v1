package CIF::Smrt::Plugin::Preprocessor::Portlist;

use strict;
use warnings;

sub process {
    my $class = shift;
    my $rules = shift;
    my $rec = shift;

    return $rec unless($rec->{'portlist'});
    return $rec if($rec->{'portlist'} =~ /^\d+$/);

    for($rec->{'portlist'}){
        if(/_/){
            $rec->{'portlist'} =~ s/_/,/g;
            last;
        }
    }

    return $rec;
}

1;
