package CIF::Smrt::ParseCsv;

use strict;
use warnings;
use Text::CSV;

sub parse {
    my $f = shift;
    my $content = shift;
    
    my @lines = split(/\n/,$content);
    my @array;
    my $csv = Text::CSV->new({binary => 1});
    my @cols = split(',',$f->{'values'});
    foreach(@lines){
        next if(/^(#|<|$)/);
        my $row = $csv->parse($_);
        next unless($csv->parse($_));
        my $h;
        my @m = $csv->fields();
        foreach (0 ... $#cols){
            next if($cols[$_] eq 'null');
            $h->{$cols[$_]} = $m[$_];
        }
        map { $h->{$_} = $f->{$_} } keys %$f;
        push(@array,$h);
    }
    return(\@array);

}

1;
