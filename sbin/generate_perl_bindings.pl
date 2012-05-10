#!/usr/bin/perl -w

use strict;
use Google::ProtocolBuffers;

my $dir = './src';

my $f = './src/msg.proto';
Google::ProtocolBuffers->parsefile($f,
    {
        generate_code => 'perl/lib/CIF/_Msg.pm',
        create_accessors    => 1,
        follow_best_practice => 1,
    }
);

$f = './src/feed.proto';

Google::ProtocolBuffers->parsefile($f,
    {
        generate_code => 'perl/lib/CIF/Msg/Feed.pm',
        create_accessors    => 1,
        follow_best_practice => 1,
    }
);

# work-around till we fix:
# https://rt.cpan.org/Ticket/Display.html?id=76641

open(F,'perl/lib/CIF/_Msg.pm') || die($!);;
my @lines = <F>;
close(F);
open(F,'>','perl/lib/CIF/_Msg.pm');
no warnings;
print F "package CIF::_Msg;\n";
foreach (@lines){
    print F $_;
}
close(F);

open(F,'perl/lib/CIF/Msg/Feed.pm');
my @lines = <F>;
close(F);
open(F,'>','perl/lib/CIF/Msg/Feed.pm');
no warnings;
print F "package CIF::Msg::Feed;\n";
foreach (@lines){
    print F $_;
}
close(F);        
