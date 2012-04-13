package CIF::Smrt::Plugin::Pull::File;

sub pull {
    my $class = shift;
    my $f = shift;
    return unless($f->{'feed'} =~ /^(\/\S+)/);
    my $file = $1;
    open(F,$file) || die($!.': '.$file);
    my $content = join('',<F>);
    return('no content',undef) unless($content && $content ne '');
    return(undef,$content);
}

1;
