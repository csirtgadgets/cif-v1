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
        
    foreach (@plugins){
        $_->process($smrt,$data);
    }
}

sub is_url {
    my $class = shift;
    my $addr = shift;
    
    # TODO -- change this to ext_categry
    #return 1 if($addr->get_category()  == AddressType::AddressCategory::Address_category_fqdn());
    return 1 if($addr->get_content() =~ /^$RE{'URI'}{'HTTP'}/ || $addr->get_content() =~ /^$RE{'URI'}{'HTTP'}{-scheme => 'https'}$/);
}

1;