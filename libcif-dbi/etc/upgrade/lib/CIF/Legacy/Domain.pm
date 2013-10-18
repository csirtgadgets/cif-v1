package CIF::Legacy::Domain;

sub hash_simple {
    my $class = shift;
    my $hash = shift;

    my $address = $hash->{'EventData'}->{'Flow'}->{'System'}->{'Node'}->{'Address'};
    return unless($address);
    for(ref($address)){
        if(/HASH/){
            $address = $address->{'content'};
            last;
        }
        if(/ARRAY/){
            my @ary = @{$address};
            $address = $ary[$#ary]->{'content'};
            last;
        }
    }
    return unless($address =~ /^[a-zA-Z0-9.-]+\.[a-z]{2,5}$/);

    my ($rdata,$type);
    my $ad = $hash->{'EventData'}->{'Flow'}->{'System'}->{'AdditionalData'};
    my @array;
    if(ref($ad) eq 'ARRAY'){
        @array = @$ad;
    } else {
        push(@array,$ad);
    }
    foreach my $a (@array){
        for(lc($a->{'meaning'})){
            $rdata  = $a->{'content'} if(/rdata/);
            $type   = $a->{'content'} if(/type/);
        }
    }

    my $portlist = $hash->{'EventData'}->{'Flow'}->{'System'}->{'Service'}->{'Portlist'};
    my $protocol = $hash->{'EventData'}->{'Flow'}->{'System'}->{'Service'}->{'ip_protocol'};

    return({
        rdata       => $rdata,
        type        => $type,
        address     => $address,
        portlist    => $portlist,
        protocol    => $protocol,
    });
}
1;
