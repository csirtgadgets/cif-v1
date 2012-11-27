package CIF::Feed::Plugin;
use base 'CIF::DBI';
use base 'Class::Accessor';

use warnings;
use strict;

use Try::Tiny;
use CIF::Msg;
use CIF::Msg::Feed;
use CIF qw/generate_uuid_random debug/;

__PACKAGE__->columns(All => qw/id uuid/);
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->has_a(uuid => 'CIF::Archive');

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(restriction_map group_map));

sub generate_feeds {
    my $class   = shift;
    my $args    = shift;
   
    my @vars = @{$args->{'vars'}};
    
    my $sth = $class->sql_feed();
    debug('executing');
    my $ret = $sth->execute(@vars);
    return unless($ret);
    ## TODO: protect against orphan keys
    ## if there's nothing in the data section, trigger a warning
    ## or a delete?
    debug('fetching');
    return($sth->fetchall_hashref('id'));
}

sub encode_feed {
    my $class = shift;
    my $args = shift;
  
    my $recs = $args->{'recs'};
    if(keys %$recs){
    $recs = [ map { $recs->{$_}->{'data'} } keys (%$recs) ];
    } else {
        $recs = [];
    }
    
    delete($args->{'recs'});
        
    my $feed = FeedType->new({
        description     => $args->{'description'},
        ReportTime      => $args->{'report_time'},
        data            => $recs,
        version         => $CIF::VERSION,
        confidence      => $args->{'confidence'},
        guid            => $args->{'guid'},
        group_map       => $args->{'group_map'},
        restriction_map => $args->{'restriction_map'},
        uuid            => generate_uuid_random(),
        restriction     => $args->{'restriction'},
    });
    return $feed;
}

sub test_whitelist {
    my $class = shift;
    my $args = shift;
    
    return $args->{'recs'} if(keys %{$args->{'recs'}});
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (t1.hash) t1.hash, t1.id, archive.data
    FROM (
        SELECT t.hash, t.id, t.uuid, t.guid
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
    SELECT DISTINCT on (t1.hash) t1.hash
    FROM (
        SELECT t2.hash
        FROM __TABLE__ t2
        WHERE
            t2.reporttime >= ?
            AND t2.confidence >= ?
        ORDER BY id DESC
        LIMIT ?
    ) t1
});



1;