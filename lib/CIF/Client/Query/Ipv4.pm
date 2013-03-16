package CIF::Client::Query::Ipv4;
use base 'CIF::Client::Query';

use strict;
use warnings;

use Net::Patricia;
use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;

sub process {
    my $class   = shift;
    my $args    = shift;

    return unless($args->{'query'} =~ /^$RE{'net'}{'IPv4'}/);
    $args->{'query'} = normalize_address($args->{'query'});
    
    my $pt = $args->{'pt'};
    $pt->add_string($args->{'query'});
    
    my @array = split(/\./,$args->{'query'});
    my $queries;
    for($args->{'query'}){
        if(/^$RE{'net'}{'IPv4'}$/){
            $queries = [    
                { query   => $args->{'query'},                              nolog => $args->{'nolog'} },
                { query => $array[0].'.'.$array[1].'.'.$array[2].'.0/24',   nolog => 1, },
                { query => $array[0].'.'.$array[1].'.0.0/16',               nolog => 1, },
                { query => $array[0].'.0.0.0/8',                            nolog => 1, },
            ];
        }
        if(/^$RE{'net'}{'CIDR'}{'IPv4'}{-keep}$/){
            my $addr = $1;
            my $mask = $2;
            return 'mask too low; minimum value is 8' unless($mask > 7);
            
            for($mask){
                if($_ > 8){
                    push(@$queries, { query => $array[0].'.0.0.0/8', nolog => 1 });
                }
                if($_ > 16){
                    push(@$queries, { query => $array[0].'.'.$array[1].'.0.0/16', nolog => 1 });
                }
                if($_ > 24){
                    push(@$queries, { query => $array[0].'.'.$array[1].'.'.$array[2].'.0/24', nolog => 1 });
                }
            }
            push(@$queries, { query => $args->{'query'}, nolog  => $args->{'nolog'} });
        }
    }
    return(undef,$queries);
}

sub normalize_address {
    my $addr = shift;

    my @bits = split(/\./,$addr);
    foreach(@bits){
        next unless(/^0{1,2}/);
        $_ =~ s/^0{1,2}//;
    }
    return join('.',@bits);
}

1;