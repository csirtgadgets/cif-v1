package CIF::Archive::Plugin::Email::Registrant;
use base 'CIF::Archive::Plugin::Email';

use strict;
use warnings;

__PACKAGE__->table('email_registrant');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = $class->iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /registrant/);
    }
    return(0);
}

1;
