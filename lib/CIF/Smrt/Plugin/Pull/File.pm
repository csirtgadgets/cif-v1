package CIF::Smrt::Plugin::Pull::File;

use strict;
use warnings;

sub pull {
    my $class = shift;
    my $f = shift;
    
    return unless($f->{'feed'} =~ /^(\/\S+|[a-zA-Z]+\/\S+)/);
    my $file = $1;
    if($file =~ /^([a-zA-Z]+)/){
        ## TODO -- work-around, path should be passed to me by the higher level lib
        # || /opt/cif/bin is in case we run $ cif_crontool as is with no preceeding path
        my $bin_path = $FindBin::Bin || '/opt/cif/bin';
        # see if we're working out of a -dev directory
        if(-e './rules'){
            $file = $bin_path.'/../rules/'.$file;
        } else {
            $file = $bin_path.'/../'.$file;
        }
    }
    open(F,$file) || return($!.': '.$file);
    my @lines = <F>;
    close(F);
    
    if(my $l = $f->{'feed_limit'}){
        my ($start,$end);
        if(ref($l) eq 'ARRAY'){
            ($start,$end) = @{$l};
        } else {
            ($start,$end) = (0,$l-1);
        }
        @lines = @lines[$start..$end];
    }
    my $content = join('',@lines) || '';
    return(undef,$content);
}

1;
