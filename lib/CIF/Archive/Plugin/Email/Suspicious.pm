package CIF::Archive::Plugin::Email::Suspicious;
use base 'CIF::Archive::Plugin::Email';

use strict;
use warnings;

__PACKAGE__->table('email_suspicious');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = $class->iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /suspicious/);
    }
    return(0);
}

1;
