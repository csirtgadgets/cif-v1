package CIF::Archive::Plugin::Infrastructure::Spamvertising;
use base 'CIF::Archive::Plugin::Infrastructure';

use strict;
use warnings;

use Iodef::Pb::Simple qw(iodef_impacts);

__PACKAGE__->table('infrastructure_spamvertising');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /^spamvertising$/);
    }
    return(0);
}

1;
