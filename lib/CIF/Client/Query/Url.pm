package CIF::Client::Query::Url;
use base 'CIF::Client::Query';

use warnings;
use strict;

use URI::Escape;

my $regex = qr/^http(s)?:\/\//;

sub process {
    my $class   = shift;
    my $args    = shift;
    
    return unless(lc($args->{'query'}) =~ $regex);
    
    $args->{'query'} =~ s/\/$//g;
    $args->{'query'} = uri_escape($args->{'query'},'\x00-\x1f\x7f-\xff');
    $args->{'query'} = lc($args->{'query'});
  
    my $query = {
        query       => $args->{'query'},
        description => 'search '.$args->{'query'},        
    };    

    return(undef,$query);  
}

1;
