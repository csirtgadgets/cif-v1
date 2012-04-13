package CIF::Smrt::ParseCIF;

use strict;
use warnings;
use JSON;

sub parse {
    my $f = shift;
    my $content = shift;

    my $hash = from_json($content);
    my @feed = @{$hash->{'data'}->{'result'}->{'feed'}->{'items'}};
    my %map;
    if(my @restrictions = split(',',$f->{'restrictions'})){
        my @map = split(',',$f->{'restrictions_map'});
        foreach my $r (0 ... $#restrictions){
            $map{$restrictions[$r]} = $map[$r];
        }
    }
    foreach my $a (@feed){
        map { $a->{$_} = $f->{$_} } keys %$f;
        if($f->{'restrictions'}){
            $a->{'restriction'} = $map{lc($a->{'restriction'})};
            $a->{'alternativeid_restriction'} = $map{lc($a->{'alternativeid_restriction'})};
        }
    }
    delete($f->{'restrictions'});
    delete($f->{'restrictions_map'});
    return(@feed);
}

1;
