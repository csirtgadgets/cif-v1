package CIF::Archive::Plugin::Hash::Sha1;
use base 'CIF::Archive::Plugin::Hash';

use strict;
use warnings;

__PACKAGE__->table('hash_sha1');

sub prepare {
    my $class = shift;
    my $data = shift;
    return unless(lc($data) =~ /^[a-f0-9]{40}$/);
    return(1);
}

sub query {
    my $class = shift;
    my $data = shift;
 
    return unless($class->prepare($data->{'query'}));

    ## TODO --  this is a crappy work-around, feeds are only searched by sha1's
    ##          and we need to fix the ordering based on confidence
    ##          if we're searching for a feed, it's one way, if not it's a different way 
    if($data->{'limit'} && $data->{'limit'} == 1){
        return $class->search_lookup_feed(
            $data->{'query'},
            $data->{'confidence'},
            $data->{'source'},
        );
    }
    return $class->search_lookup(
        $data->{'query'},
        $data->{'confidence'},
        $data->{'source'},
        $data->{'limit'},
    );
}

# since all feed lookups are sha1 based, but we only want the last record
__PACKAGE__->set_sql('lookup_feed' => qq{
    SELECT t.id,t.uuid,archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups on t.guid = apikeys_groups.guid
    LEFT JOIN archive ON archive.uuid = t.uuid
    WHERE 
        hash = ?
        AND confidence >= ?
        AND apikeys_groups.uuid = ?
        AND archive.uuid IS NOT NULL
    ORDER BY t.confidence ASC, t.reporttime DESC, t.created DESC, t.id DESC
    LIMIT 1
});

1;
