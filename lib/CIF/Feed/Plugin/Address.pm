package CIF::Feed::Plugin::Address;
use base 'CIF::Feed::Plugin';

use warnings;
use strict;

use CIF qw(debug);

__PACKAGE__->columns(All => qw/id uuid guid hash address confidence reporttime created/);

sub generate_feeds { return; }

# specific to domain and infrastructure
# where we need the address to bench against the whitelist
no warnings;
sub generate_feeds { 
    my $class   = shift;
    my $args    = shift;
   
    my @vars = @{$args->{'vars'}};
    
    my $sth = $class->sql_feed();
    debug('executing');
    my $ret = $sth->execute(@vars);
    return unless($ret);
    debug('fetching');
    return($sth->fetchall_hashref('id'));
}
use warnings;

# used for domains and ip's
# because we can have /24's and blanket TLDs in the whitelist

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (t1.hash) t1.hash, t1.id, t1.address, archive.data
    FROM (
        SELECT t.hash, t.id, t.uuid, t.guid, t.address
        FROM __TABLE__ t
        WHERE
            t.reporttime >= ?
            AND t.confidence >= ?
        ORDER by t.id DESC
        LIMIT ?
    ) t1
    LEFT JOIN archive ON t1.uuid = archive.uuid
    LEFT JOIN apikeys_groups ON t1.guid = apikeys_groups.guid
    WHERE apikeys_groups.uuid = ?
});

__PACKAGE__->set_sql('feed_whitelist' => qq{
    SELECT DISTINCT on (t1.hash) t1.hash, t1.address
    FROM (
        SELECT t2.hash, t2.address
        FROM __TABLE__ t2
        WHERE
            t2.reporttime >= ?
            AND t2.confidence >= ?
        ORDER BY id DESC
        LIMIT ?
    ) t1
});

# override since we're just a skel.

sub vaccum { }

    
1;
