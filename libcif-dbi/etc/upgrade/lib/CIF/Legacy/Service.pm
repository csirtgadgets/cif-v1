package CIF::Legacy::Service;

sub hash_simple {
    my $clas = shift;
    my $hash = shift;

    my $portlist = $hash->{'EventData'}->{'Flow'}->{'System'}->{'Service'}->{'Portlist'};
    my $protocol = $hash->{'EventData'}->{'Flow'}->{'System'}->{'Service'}->{'ip_protocol'};
    
    return unless($portlist || $protocol);

    $portlist =~ s/\s+//g if($portlist);

    return({
        portlist    => $portlist,
        protocol    => $protocol,
    });
}
1;
