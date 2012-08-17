package CIF::Feed::Plugin::Url;
use base 'CIF::Feed::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use CIF qw/debug/;

__PACKAGE__->table('url');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence detecttime created/);
__PACKAGE__->sequence('url_id_seq');

## TODO: database config?
my @plugins = __PACKAGE__->plugins();
push(@plugins, ('suspicious','botnet','malware','phishing','spam','whitelist'));

sub generate_feeds {
    my $class   = shift;
    my $args    = shift;
    
    my $tbl = $class->table();
    
    my @feeds;
    foreach my $p (@plugins){
        my $t = $p;
        if($p =~ /Domain::(\S+)$/){
            $t = lc($1);
        }
        my $desc = $t.' url feed';
        $t = 'url_'.$t;
        $class->table($t);
        my $feed_args = {
            description => $desc,
            report_time => $args->{'report_time'},
            confidence  => $args->{'confidence'},
            guid        => $args->{'guid'},
            vars    => [
                $args->{'start_time'},
                $args->{'confidence'},
                $args->{'guid'},
                $args->{'start_time'},
                $args->{'limit'},
            ],
            group_map       => $args->{'group_map'},
            restriction_map => $args->{'restriction_map'},
            restriction     => $args->{'restriction'},
        };
        debug($desc.': generating');
        my $f = $class->SUPER::generate_feeds($feed_args);
        if(keys %$f){
            debug($desc.': testing whitelist');
            $f = $class->test_whitelist({ recs => $f });  
        }
        debug($desc.': encoding');
        $f = $class->SUPER::encode_feed({ recs => $f, %$feed_args });
        push(@feeds,$f);
    }
    $class->table($tbl);
    return(\@feeds);
}

## TODO -- double test this
sub test_whitelist {
    my $class = shift;
    my $args = shift;
    
    return $args->{'recs'} if($class->table() =~ /whitelist$/);
    
    my @whitelist = $class->search_feed_whitelist(
        $args->{'start_time'},
        25000,
    );

    return $args->{'recs'} unless($#whitelist > -1);
    my $recs = $args->{'recs'};
    
    foreach my $w (@whitelist){
        delete($recs->{$w->{'hash'}});
    }
    return($recs);
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (t.hash) t.id, t.hash, archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups ON t.guid = apikeys_groups.guid
    LEFT JOIN archive ON t.uuid = archive.uuid
    WHERE
        detecttime >= ?
        AND t.confidence >= ?
        AND t.guid = ?
        AND NOT EXISTS (
            SELECT uw.hash FROM url_whitelist uw
            WHERE
                uw.detecttime >= ?
                AND uw.confidence > 25
                AND uw.hash = t.hash
        )
    ORDER BY t.hash ASC, t.id DESC
    LIMIT ?
});

__PACKAGE__->set_sql('feed_whitelist' => qq{
    SELECT DISTINCT ON (t.uuid) t.uuid, hash, confidence
    FROM url_whitelist t
    WHERE
        t.detecttime >= ?
        AND t.confidence >= 25
    ORDER BY t.uuid DESC, t.id ASC
    LIMIT ?
});
    
1;
