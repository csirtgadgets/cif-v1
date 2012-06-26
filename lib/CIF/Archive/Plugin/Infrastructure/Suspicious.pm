package CIF::Archive::Plugin::Infrastructure::Suspicious;
use base 'CIF::Archive::Plugin::Infrastructure';

use strict;
use warnings;

__PACKAGE__->table('infrastructure_suspicious');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = $class->iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /^suspicious$/);
    }
    return(0);
}

1;
