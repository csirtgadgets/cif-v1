package CIF::Legacy::Group;

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
    foreach my $a (@array){
        for(lc($a->{'meaning'})){
            next unless(/guid/);
            return({
                guid   => $a->{'content'}
            });
        }
    }
}
1;
