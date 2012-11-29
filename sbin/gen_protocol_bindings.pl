#!/usr/bin/perl -w

use strict;

use Google::ProtocolBuffers;
use FindBin qw/$Bin/;

my $f = $Bin.'/../protocol/src/msg.proto';

Google::ProtocolBuffers->parsefile($f,
    {
        generate_code => $Bin.'/../lib/CIF/Msg.pm',
        create_accessors    => 1,
        follow_best_practice => 1,
    }
);

$f = $Bin.'/../protocol/src/feed.proto';

unless(-e $Bin.'/../lib/CIF/Msg'){
    system("mkdir $Bin/../lib/CIF/Msg");
}

Google::ProtocolBuffers->parsefile($f,
    {
        generate_code => $Bin.'/../lib/CIF/Msg/Feed.pm',
        create_accessors    => 1,
        follow_best_practice => 1,
    }
);

# work-around till we fix:
# https://rt.cpan.org/Ticket/Display.html?id=76641

open(F,$Bin.'/../lib/CIF/Msg.pm') || die($!);;
my @lines = <F>;
close(F);
open(F,'>',$Bin.'/../lib/CIF/Msg.pm');
no warnings;
print F "package CIF::Msg;\n";
foreach (@lines){
    print F $_;
}
close(F);

open(F,$Bin.'/../lib/CIF/Msg/Feed.pm');
my @lines = <F>;
close(F);
open(F,'>',$Bin.'/../lib/CIF/Msg/Feed.pm');
no warnings;
print F "package CIF::Msg::Feed;\n";
foreach (@lines){
    print F $_;
}
close(F);        
