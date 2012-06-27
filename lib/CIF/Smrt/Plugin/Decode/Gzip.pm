package CIF::Smrt::Plugin::Decode::Gzip;

use Compress::Zlib;

sub decode {
    my $class = shift;
    my $data = shift;
    my $type = shift;
    return unless($type =~ /gzip/);

    my $uncompressed = Compress::Zlib::memGunzip($data);
    my $ft = File::Type->new();
    my $t = $ft->mime_type($uncompressed);

    return unless($t =~ /octet-stream/); #only return octect streams(aka text)
    return $uncompressed;
}

1;

