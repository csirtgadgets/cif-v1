package CIF::Router::HTTP::Json;

use strict;
use warnings;

require Iodef::Pb::Format;
require CIF::Client;

sub handler {
    my $reply = shift;
    
    CIF::Client->decode_feed($reply);
    my $t = Iodef::Pb::Format->new({
        format              => 'Json',
    });
    return $t;
}

1;