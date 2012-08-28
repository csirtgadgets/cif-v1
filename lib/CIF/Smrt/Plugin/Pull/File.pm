package CIF::Smrt::Plugin::Pull::File;

sub pull {
    my $class = shift;
    my $f = shift;
    
    return unless($f->{'feed'} =~ /^(\/\S+|[a-zA-Z]+\/\S+)/);
    my $file = $1;
    if($file =~ /^([a-zA-Z]+)/){
        my $bin_path = $FindBin::Bin;
        $file = $bin_path.'/../'.$file;
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
