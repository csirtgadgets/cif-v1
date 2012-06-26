package CIF::Archive::Plugin::Infrastructure::Scan;
use base 'CIF::Archive::Plugin::Infrastructure';

use strict;
use warnings;

__PACKAGE__->table('infrastructure_scan');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = $class->iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if(lc($_->get_content->get_content()) =~ /^scan(?:(ning|ner))/);
    }
    return(0);
}

1;
