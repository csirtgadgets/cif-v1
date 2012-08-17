package CIF::Feed::Plugin::Email;
use base 'CIF::Feed::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use CIF qw/debug/;

__PACKAGE__->table('email');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence detecttime created/);
__PACKAGE__->sequence('email_id_seq');

## TODO: database config?
my @plugins = __PACKAGE__->plugins();
push(@plugins,'phishing','registrant');

sub generate_feeds {
    my $class   = shift;
    my $args    = shift;
    
    my $tbl = $class->table();
    
    my @feeds;
    foreach my $p (@plugins){
        my $t = $p;
        if($p =~ /Email::(\S+)$/){
            $t = lc($1);
        }
        my $desc = $t.' email feed';
        $t = 'email_'.$t;
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
        debug($desc.': encoding');
        $f = $class->SUPER::encode_feed({ recs => $f, %$feed_args });
        push(@feeds,$f);
    }
    $class->table($tbl);
    return(\@feeds);
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (t.hash) t.hash, t.id, archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups ON t.guid = apikeys_groups.guid
    LEFT JOIN archive ON t.uuid = archive.uuid
    WHERE 
        detecttime >= ?
        AND t.confidence >= ?
        AND t.guid = ?
        AND NOT EXISTS (
            SELECT w.hash FROM email_whitelist w
            WHERE
                w.detecttime >= ?
                AND w.confidence > 25
                AND w.hash = t.hash
        )
    ORDER BY t.hash, t.id ASC, confidence DESC
    LIMIT ?
});
    
1;
