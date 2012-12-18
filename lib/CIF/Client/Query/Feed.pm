package CIF::Client::Query::Feed;

use strict;
use warnings;

my $regex = qr/^([a-z]+\/[a-z]+([0-9])?)$/;

sub process {
    my $class   = shift;
    my $args    = shift;
    
    return unless($args->{'query'} =~ $regex);
    
    my @bits = split(/\//,$args->{'query'});
    $args->{'query'} = join(' ',reverse(@bits)).' feed';
    
    my $query = {
        query       => $args->{'query'},
        description => 'search '.$args->{'query'},
        limit       => 1,
        
        ## TODO: this is a hack, gatta find a better way to handle these
        feed        => 1,
        
        ## TODO: fix this, if we log a feed search, the next search this will pop-up
        ##       instead of the feed itself (since we're looking at the hash table)
        nolog       => 1,
        
        ## TODO -- this could cause problems based on what comes in through the api
        ## feeds we wanna default higher than regular searches... i think..?
        ## should this be set server side?
        confidence  => $args->{'confidence'} || 95,
    };

    return(undef,$query);  
}

1;