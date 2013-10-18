package CIF::Legacy::ShareWith;

sub hash_simple {
    my $class = shift;
    my $hash = shift;

    my ($rdata,$type);
    my $ad = $hash->{'AdditionalData'};
    return unless($ad);
    my @array;
    if(ref($ad) eq 'ARRAY'){
        @array = @$ad;
    } else {
        push(@array,$ad);
    }
    my @share;
    foreach my $a (@array){
        for(lc($a->{'meaning'})){
            next unless(/sharewith/);
            push(@share,$a->{'content'});
        }
    }
    return unless($#share > -1);
    return({
        carboncopy => join(',',@share),
    });
}
1;
