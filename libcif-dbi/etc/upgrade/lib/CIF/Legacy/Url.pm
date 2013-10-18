package CIF::Legacy::Url;

use Regexp::Common qw/URI/;

sub hash_simple {
    my $class = shift;
    my $data = shift;

    my $address = $data->{'EventData'}->{'Flow'}->{'System'}->{'Node'}->{'Address'};
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

    return unless($address =~ /^(ftp|https?):\/\//);

    my $ad = $data->{'EventData'}->{'Flow'}->{'System'}->{'AdditionalData'};
    return unless($ad);
    my @array;
    if(ref($ad) eq 'ARRAY'){
        @array = @$ad;
    } else {
        push(@array,$ad);
    }
    my ($md5,$sha1);
    foreach my $a (@array){
        for(lc($a->{'meaning'})){
            $md5    = $a->{'content'} if(/^md5/);
            $sha1   = $a->{'content'} if(/^sha1/);
        }
    }

    return({
        address => $address,
        md5     => $md5,
        sha1    => $sha1,
    });
}
1;
