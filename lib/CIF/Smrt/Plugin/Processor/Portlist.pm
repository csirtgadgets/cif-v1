package CIF::Smrt::Plugin::Processor::Portlist;

use strict;

sub process {
    my $class = shift;
    my $rec = shift;

    return unless($rec->{'portlist'});
    return if($rec->{'portlist'} =~ /^\d+$/);

    for($rec->{'portlist'}){
        if(/_/){
            $rec->{'portlist'} =~ s/_/,/g;
            last;
        }
    }

    return($rec);
}

1;
