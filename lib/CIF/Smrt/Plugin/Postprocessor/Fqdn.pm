package CIF::Smrt::Plugin::Postprocessor::Fqdn;
use base 'CIF::Smrt::Plugin::Postprocessor';

use strict;
use warnings;

use Iodef::Pb qw(:all);
require Net::DNS::Resolver;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

my @plugins = __PACKAGE__->plugins();

sub process {
    my $class   = shift;
    my $smrt    = shift;
    my $data    = shift;
 
    my $addresses = iodef_addresses($data);
    return unless($#{$addresses} > -1);
        
    foreach (@plugins){
        $_->process($smrt,$data);
    }
}

sub is_fqdn {
    my $class = shift;
    my $addr = shift;
    
    # TODO -- change this to ext_categry
    #return 1 if($addr->get_category()  == AddressType::AddressCategory::Address_category_fqdn());
    return 1 if($addr->get_content() =~ /^[a-z0-9.-]+\.[a-z]{2,6}$/);
}

sub resolve {
    my $class = shift;
    my $addr = shift;
    
    my $r = Net::DNS::Resolver->new(recursive => 0);
    $r->udp_timeout(2);
    $r->tcp_timeout(2);
    
    my $pkt = $r->send($addr);
    return unless($pkt);
    my @rdata = $pkt->answer();
    return(\@rdata);
}

sub resolve_ns {
    my $class = shift;
    my $addr = shift;
    
    my $r = Net::DNS::Resolver->new(recursive => 0);
    $r->udp_timeout(2);
    $r->tcp_timeout(2);
    
    my $pkt = $r->send($addr,'NS');
    return unless($pkt);
    my @rdata = $pkt->answer();
    return(\@rdata);
}


1;