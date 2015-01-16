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
    $rec->{'address'} = lc($rec->{'address'});
    
    if($rec->{'address'} =~ /^$RE{'net'}{'CIDR'}{'IPv4'}$/){
    	if ($2 > 14){
    		$rec->{'address'} = $1.'/14';
    	}
    }
    
    return $rec;
}

1;
