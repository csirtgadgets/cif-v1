package CIF::Archive::Plugin::Email::Whitelist;
use base 'CIF::Archive::Plugin::Email';

use strict;
use warnings;

__PACKAGE__->table('email_whitelist');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = $class->iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /whitelist/);
    }
    return(0);
}

1;
