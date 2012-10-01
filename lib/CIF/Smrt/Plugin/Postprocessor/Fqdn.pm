package CIF::Smrt::Plugin::Postprocessor::Fqdn;
use base 'CIF::Smrt::Plugin::Postprocessor';

use strict;
use warnings;

use Iodef::Pb::Simple ':all';
require Net::DNS::Resolver;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

my @plugins = __PACKAGE__->plugins();

sub process {
    my $class   = shift;
    my $smrt    = shift;
    my $data    = shift;
 
    my $addresses = iodef_addresses($data);
    return unless($#{$addresses} > -1);
       
    my $array;
    foreach (@plugins){
        my $r = $_->process($smrt,$data);
        push(@$array,@$r) if($r && @$r);
    }
    return $array;
}

sub is_fqdn {
    my $class = shift;
    my $addr = shift;
    
    return unless($addr->get_category() == AddressType::AddressCategory::Address_category_ext_value());
    return unless($addr->get_ext_category() =~ /^(fqdn|domain)$/);
    return 1 if($addr->get_content() =~ /^[a-z0-9.-]+\.[a-z]{2,8}$/);
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