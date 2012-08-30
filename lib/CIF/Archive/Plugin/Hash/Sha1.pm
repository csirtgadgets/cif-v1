package CIF::Archive::Plugin::Malware::Sha1;
use base 'CIF::Archive::Plugin::Malware';

use strict;
use warnings;

__PACKAGE__->table('malware_sha1');

sub prepare {
    my $class = shift;
    my $data = shift;
    return unless(lc($data) =~ /^[a-f0-9]{40}$/);
    return(1);
}

sub query {
    my $class = shift;
    my $data = shift;
 
    return unless($class->prepare($data->{'query'}));

    ## TODO --  this is a crappy work-around, feeds are only searched by sha1's
    ##          and we need to fix the ordering based on confidence
    ##          if we're searching for a feed, it's one way, if not it's a different way 
    if($data->{'limit'} && $data->{'limit'} == 1){
        return $class->SUPER::search_lookup_feed(
            $data->{'query'},
            $data->{'confidence'},
            $data->{'source'},
        );
    }
    return $class->SUPER::search_lookup(
        $data->{'query'},
        $data->{'confidence'},
        $data->{'source'},
        $data->{'limit'},
    );
}

1;
