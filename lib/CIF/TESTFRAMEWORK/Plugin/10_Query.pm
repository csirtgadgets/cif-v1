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
    
    my $loop = $args->{'loop'} || 0;
    
    my ($ret,$err);
    for (my $i = 0; $i < $loop; $i++){
        foreach my $t (@tests){
            debug('query: '.$t->{'address'});
            ($err,$ret) = $cli->search({
                query   => $t->{'address'},
                nolog   => 1,
            });
            return($err) if($err);
            return('query failed: '.$t->{'address'}) unless($ret);
        }
    }
    debug('query tests successful...');
    
    return 1;
}

sub basic {}

sub feed {}

1;