#!/usr/bin/perl

use strict;
use warnings;

# this just sets up the lib paths for apache

# fix lib paths, some may be relative
BEGIN {
    require File::Spec;
    my @libs = ("lib", "local/lib",
        '../cif-perl/lib',
        '../cif-protocol/perl/lib',
        '../cif-dbi-perl/lib',
        '../iodef-pb-perl/lib',
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
