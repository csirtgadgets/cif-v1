package CIF::TESTFRAMEWORK::Plugin::10_Query;
use base 'CIF::TESTFRAMEWORK::Plugin';

use strict;
use warnings;

use CIF qw/debug/;

sub run {
    my $self = shift;
    my $args = shift;
    
    my @tests = @{$args->{'tests'}};
    my $cli = $args->{'client'};
    
    my ($ret,$err);
    foreach my $t (@tests){
        debug('query: '.$t->{'address'});
        ($err,$ret) = $cli->search({
            query => $t->{'address'},
        });
        return($err) if($err);
        return('query failed: '.$t->{'address'}) unless($ret);
    }
    debug('query tests successful...');
    
    return 1;
}

sub basic {}

sub feed {}

1;