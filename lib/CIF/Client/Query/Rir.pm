package CIF::Client::Query::Rir;
use base 'CIF::Client::Query';

use warnings;
use strict;

use CIF qw/debug/;

my $regex = qr/^(afrinic|apnic|arin|lacnic|ripencc)$/;

sub process {
    my $class   = shift;
    my $args    = shift;

    return unless(lc($args->{'query'}) =~ $regex);
    debug('performing rir query...');

    $args->{'query'} = lc($args->{'query'});

    my $query = {
        query       => $args->{'query'},
        description => 'search RIR '.uc($args->{'query'}),
        %$args,
    };

    return(undef,$query);
}

1;