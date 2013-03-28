package CIF::Smrt::ParseTxt;

use strict;
use warnings;

sub parse {
    my $f = shift;
    my $content = shift;
    
    return unless($f->{'regex'});
    
    my @lines = split(/[\r\n]/,$content);
    my @array;
    foreach(@lines){
        next if(/^(#|<|$)/);
        my @m = ($_ =~ /$f->{'regex'}/);
        next unless(@m);
        my $h;
        my @cols = split(',',$f->{'regex_values'});
        foreach (0 ... $#cols){
            $m[$_] = '' unless($m[$_]);
            for($m[$_]){
                s/^\s+//;
                s/\s+$//;
            }
            $h->{$cols[$_]} = $m[$_];
        }
        map { $h->{$_} = $f->{$_} } keys %$f;
        push(@array,$h);
    }
    return(\@array);

}

1;
