package CIF::Client::Query::Cc;
use base 'CIF::Client::Query';

use warnings;
use strict;

use CIF qw/debug/;

my $regex = qr/^[A-Za-z]{2}$/;

sub process {
    my $class   = shift;
    my $args    = shift;
    
    return unless($args->{'query'} =~ $regex);
    debug('performing country code search...');
    
    $args->{'query'} = uc($args->{'query'});
  
    my $query = {
        query       => $args->{'query'},
        description => 'search CC '.$args->{'query'},        
    };

    return(undef,$query);  
}

1;
