package CIF::Archive::Plugin::Domain::Spam;
use base 'CIF::Archive::Plugin::Domain';

use strict;
use warnings;

use Iodef::Pb::Simple qw(iodef_impacts);

__PACKAGE__->table('domain_spam');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /^spam$/);
    }
    return(0);
}

1;
