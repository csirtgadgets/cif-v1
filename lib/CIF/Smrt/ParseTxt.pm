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
        my @cols = (ref($f->{'regex_values'}) eq 'ARRAY') ? @{$f->{'regex_values'}} : split(',',$f->{'regex_values'});
        foreach (0 ... $#cols){
            $m[$_] = '' unless($m[$_]);
            for($m[$_]){
                s/^\s+//;
                s/\s+$//;
            }
            $h->{$cols[$_]} = $m[$_];
        }
        # a work-around, we do some of this in iodef::pb::simple too
        # adding this here makes the debugging messages a little less complicated
        if($h->{'address_mask'}){
            $h->{'address'} .= '/'.$h->{'address_mask'};
        }
        map { $h->{$_} = $f->{$_} } keys %$f;
        push(@array,$h);
    }
    return(\@array);

}

1;
