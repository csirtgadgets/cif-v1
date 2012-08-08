package CIF::Smrt::Plugin::Pull::CIF;

require CIF::Client;

sub pull {
    my $class = shift;
    my $f = shift;
    return unless($f->{'cif'});

    my $config = $f->{'cif'};
    my $feed = $f->{'feed'};
    my ($client,$err) = CIF::Client->new({config => $config});
    return($err) if($err);
    my $content = $client->GET($feed);
    my $code = $client->responseCode();
    return('request failed: '.$code,undef) unless($code eq '200');
    return (undef,$content);
}

1;
