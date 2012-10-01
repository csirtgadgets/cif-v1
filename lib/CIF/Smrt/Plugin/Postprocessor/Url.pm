package CIF::Smrt::Plugin::Postprocessor::Url;
use base 'CIF::Smrt::Plugin::Postprocessor';

use strict;
use warnings;

use Regexp::Common qw/URI net/;
use Iodef::Pb::Simple ':all';

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

my @plugins = __PACKAGE__->plugins();

sub process {
    my $class   = shift;
    my $smrt    = shift;
    my $data    = shift;

    my $addresses = iodef_addresses($data);
    return unless($#{$addresses} > -1);
    
    my $found = 0;
    foreach (@$addresses){
        next unless($class->is_url($_));
        $found = 1;
    }
    
    return unless($found);
    
    my $array;
    foreach (@plugins){
        my $r = $_->process($smrt,$data);
        push(@$array,@$r) if($r && @$r);
    }
    return $array;
}

sub is_url {
    my $class = shift;
    my $addr = shift;

    return unless($addr->get_category() == AddressType::AddressCategory::Address_category_ext_value());
    return unless($addr->get_ext_category() eq 'url');
    return 1 if($addr->get_content() =~ /^$RE{'URI'}{'HTTP'}/ || $addr->get_content() =~ /^$RE{'URI'}{'HTTP'}{-scheme => 'https'}$/);
}

1;