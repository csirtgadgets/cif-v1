package CIF::Smrt::Plugin::Decode::Zip;

use strict;
use warnings;
use IO::Uncompress::Unzip qw(unzip $UnzipError);

sub decode {
    my $class = shift;
    my $data = shift;
    my $type = shift;
    my $f = shift;
    return unless($type =~ /zip/ && $type !~ /gzip/);

    my $file;
    if($f->{'zip_filename'}){
        $file = $f->{'zip_filename'};
    } else {
        $f->{'feed'} =~ m/\/([a-zA-Z0-9_]+).zip$/;
        $file = $1;
    }
    return unless($file);

    my $unzipped;
    unzip \$data => \$unzipped, Name => $file || die('unzip failed: '.$UnzipError);
    return $unzipped;
}

1;
