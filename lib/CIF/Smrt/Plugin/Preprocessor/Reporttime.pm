package CIF::Smrt::Plugin::Preprocessor::Reporttime;

use strict;
use warnings;

use CIF qw/normalize_timestamp/;

sub process {
    my $class   = shift;
    my $rules   = shift;
    my $rec     = shift;
    
    my $dt;
    if($rec->{'reporttime'}){
        $dt = $rec->{'reporttime'};
    } elsif($rec->{'detecttime'}){
        # legacy syntax support
        $dt = $rec->{'detecttime'};
    } else {
        $dt = DateTime->from_epoch(epoch => time());
    }
    $dt = normalize_timestamp($dt);
    $rec->{'reporttime'} = $dt;
    return $rec;
    
    
}

1;