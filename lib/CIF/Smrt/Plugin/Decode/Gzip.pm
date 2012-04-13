package CIF::Smrt::Plugin::Decode::Gzip;

use Compress::Zlib;

sub decode {
    my $class = shift;
    my $data = shift;
    my $type = shift;
    return unless($type =~ /gzip/);
    return Compress::Zlib::memGunzip($data);
}

1;
