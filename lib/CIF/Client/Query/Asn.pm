package CIF::Client::Query::Asn;
use base 'CIF::Client::Query';

use warnings;
use strict;

my $regex = qr/^(AS|as)?\d+$/;

sub process {
    my $class   = shift;
    my $args    = shift;
    
    return unless($args->{'query'} =~ $regex);
    
    $args->{'query'} =~ s/^(as|AS)//g;
    $args->{'query'} = 'as'.$args->{'query'};
    
    my $query = {
        query       => $args->{'query'},
        description => 'search '.$args->{'query'},        
    };

    return(undef,$query);  
}

1;
