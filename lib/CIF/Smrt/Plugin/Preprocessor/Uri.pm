package CIF::Smrt::Plugin::Preprocessor::Uri;

use strict;
use warnings;

use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;

sub process {
    my $class = shift;
    my $rules = shift;
    my $rec = shift;
    
    my $address = $rec->{'address'};    
    return $rec unless($address);
    
    # Regexp::Common qw/URI/ chokes on large urls
    return $rec if($address =~ /^(ftp|https?):\/\//);
    return $rec if($address =~ /^$RE{'net'}{'IPv4'}$/ || $address =~ /^$RE{'net'}{'CIDR'}{'IPv4'}$/);
    
    #return $rec unless($address =~ /^$RE{'net'}{'IPv4'}/);
    return $rec if($rec->{'address'} =~ /[\s]+/);
    if($rec->{'address'} =~ /[\/]+/){
        $rec->{'address'} = 'http://'.$rec->{'address'};
    }
    return $rec;
}

1;
