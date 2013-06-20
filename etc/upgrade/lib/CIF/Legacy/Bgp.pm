package CIF::Legacy::Bgp;

sub hash_simple {
    my $class = shift;
    my $hash = shift;
    my $sh = shift;

    my ($asn,$prefix,$rir,$cc);

    my $ad = $hash->{'EventData'}->{'Flow'}->{'System'}->{'AdditionalData'};
    my @array;
    if(ref($ad) eq 'ARRAY'){
        @array = @$ad;
    } else {
        push(@array,$ad);
    }
    foreach my $a (@array){
        next unless($a->{'meaning'});
        for(lc($a->{'meaning'})){
            $asn    = $a->{'content'} if(/asn/);
            $prefix = $a->{'content'} if(/prefix/);
            $rir    = $a->{'content'} if(/rir/);
            $cc     = $a->{'content'} if(/cc/);
        }
    }
    return unless($asn || $prefix || $rir || $cc);
    
    if($asn){
        $asn =~ /^(\d+) ([\s|\S]+)$/;
        $sh->{'asn'}        = $1;
        $sh->{'asn_desc'}   = $2;
    }
    $sh->{'prefix'} = $prefix;
    $sh->{'rir'} = $rir;
    $sh->{'cc'} = $cc;
    return($sh);
}

1;
