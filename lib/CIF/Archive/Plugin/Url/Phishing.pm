package CIF::Archive::Plugin::Url::Phishing;
use base 'CIF::Archive::Plugin::Url';

use strict;
use warnings;

__PACKAGE__->table('url_phishing');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = $class->iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /phish/);
    }
    return(0);
}

1;
