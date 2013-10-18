package CIF::Smrt::Plugin::Decode::Gtar;

use Compress::Zlib;
use Archive::Tar;
use IO::Scalar;

sub decode {
    my $class = shift;
    my $data = shift;
    my $type = shift;
    my $f = shift;
    my $uncompressed;
    return unless($type =~ /gzip/ || $type =~ /gtar/); #support tar.gz or tar

    if ($type =~ /gzip/){ #if tar.gz, extract to tar
        $uncompressed = Compress::Zlib::memGunzip($data);
        my $ft = File::Type->new();
        my $t = $ft->mime_type($uncompressed);
        return unless($t =~ /gtar/); #return if not a tar inside
    } else {
	$uncompressed = $data; #already a tar
    }

    my $file;
    if($f->{'zip_filename'}){
        $file = $f->{'zip_filename'};
    } else {
        die $f->{'feed'};
        $f->{'feed'} =~ m/\/([a-zA-Z0-9_]+).zip$/;
        $file = $1;
    }
    return unless($file);

    my $fh = IO::Scalar->new(\$uncompressed);

    my $tar = Archive::Tar->new;
    $tar->read($fh) or die "Cannot read from \$fh";
    my $untarred = $tar->get_content($file);

    die("couldn't extract $file from archive") unless($untarred);
    return $untarred;

}

1;

