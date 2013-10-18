package CIF::Client::Query::Feed;

use strict;
use warnings;

my $regex = qr/^([a-z]+\/[a-z]+([0-9])?)$/;

sub process {
    my $class   = shift;
    my $args    = shift;
    
    return unless($args->{'query'} =~ $regex);
    
    my @bits = split(/\//,$args->{'query'});
    $args->{'query'}        = join(' ',reverse(@bits)).' feed';
    $args->{'limit'}        = 1;
    $args->{'description'}  = 'search '.$args->{'query'};
    $args->{'feed'}         = 1;
    $args->{'confidence'}   = defined($args->{'confidence'}) ? $args->{'confidence'} : 95;

    return(undef,$args);  
}

1;