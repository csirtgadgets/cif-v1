package CIF::TESTFRAMEWORK::Plugin::00_Submit;
use base 'CIF::TESTFRAMEWORK::Plugin';

use strict;
use warnings;

use CIF::Client;
use Iodef::Pb::Simple;
use CIF qw/debug generate_uuid_ns/;
use Try::Tiny;    

sub run {
    my $self = shift;
    my $args = shift;
    
    my $tests = $args->{'tests'};
    
    my $cli = $args->{'client'};
    
    my $err;
    foreach my $t (@$tests){
        try {
            $t = Iodef::Pb::Simple->new($t);
        } catch {
            $err = shift;
        };
        if($err){
            return('test failed: '.$err);
        }
        $t = $t->encode();
    }
    
    my $ret = $cli->new_submission({
        guid    => generate_uuid_ns('everyone'),
        data    => $tests,
    });
    
    ($err,$ret) = $cli->submit($ret);
    if($err){
        debug($err);
        return($err);
    }
    
    foreach (@{$ret->get_data()}){
        debug('submission sucessful: '.$_);
    }

    return 1;
}



1;