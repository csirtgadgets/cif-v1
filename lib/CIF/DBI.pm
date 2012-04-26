package CIF::DBI;
use base 'Class::DBI';

use strict;
use warnings;

# because UUID's are really primary keys too in our schema
# this overrides some of the default functionality of Class::DBI and 'id'
sub retrieve {
    my $class = shift;

    return $class->SUPER::retrieve(@_) if(@_ == 1);
    my %keys = @_;

    my @recs = $class->search_retrieve_uuid($keys{'uuid'});
    return unless(defined($#recs) && $#recs > -1);
    return($recs[0]);
}

__PACKAGE__->set_sql('retrieve_uuid' => qq{
    SELECT id,uuid
    FROM __TABLE__
    WHERE uuid = ?
    ORDER BY id DESC
    LIMIT 1
});

__PACKAGE__->set_sql('prune' => qq{
    DELETE FROM __TABLE__
    WHERE created <= ?;
});


1;