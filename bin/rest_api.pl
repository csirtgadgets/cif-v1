#!/usr/bin/perl

use strict;
use warnings;

# fix lib paths, some may be relative
BEGIN {
    require File::Spec;
    my @libs = ("lib", "local/lib",
        "/home/wes/projects/src/cif/v2/cif-dbi-perl/lib",
        "/home/wes/projects/src/cif/v2/iodef-pb-perl/lib",
        "/home/wes/projects/src/cif/v2/cif-router-perl/lib",
        "/home/wes/projects/src/cif/v2/iodef-pb-simple-perl/lib",
        "/home/wes/projects/src/cif/v2/cif-perl/lib/",
    );
    my $bin_path;

    for my $lib (@libs) {
        unless ( File::Spec->file_name_is_absolute($lib) ) {
            unless ($bin_path) {
                if ( File::Spec->file_name_is_absolute(__FILE__) ) {
                    $bin_path = ( File::Spec->splitpath(__FILE__) )[1];
                }
                else {
                    require FindBin;
                    no warnings "once";
                    $bin_path = $FindBin::Bin;
                }
            }
            $lib = File::Spec->catfile( $bin_path, File::Spec->updir, $lib );
        }
        unshift @INC, $lib;
    }
}

1;