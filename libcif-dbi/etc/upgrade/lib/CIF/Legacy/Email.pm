package CIF::Legacy::Email;

use Regexp::Common qw/URI/;

sub isEmail {
    my $e = shift;
    return unless($e);
    return if($e =~ /^$RE{'URI'}/ || $e =~ /^$RE{'URI'}{'HTTP'}{-scheme => 'https'}$/);
    return unless(lc($e) =~ /^[a-z0-9_.-]+\@[a-z0-9.-]+\.[a-z0-9.-]{2,5}$/);
    return(1);
}

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
    return unless(isEmail($address));

    return({
        address     => $address,
    });
}
1;
