package CIF::Smrt::Plugin::Preprocessor::Address;

use strict;
use warnings;

use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;

sub process {
    my $class = shift;
    my $rules = shift;
    my $rec = shift;

    return $rec unless($rec->{'address'});
    return $rec if ($rec->{'atype'} && $rec->{'atype'} ne 'ipv4');
    $rec->{'address'} = lc($rec->{'address'});
    
    if($rec->{'address'} =~ /^$RE{'net'}{'CIDR'}{'IPv4'}{'-keep'}$/){
    	my $min = $rec->{'min_prefix'} || 14;
    	if ($2 < $min){
    		$rec->{'address'} = $1.'/'.$min;
    	}
    }
    return $rec;
}

1;
