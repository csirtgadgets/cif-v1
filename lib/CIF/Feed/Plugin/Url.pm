package CIF::Feed::Plugin::Url;
use base 'CIF::Feed::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

__PACKAGE__->table('url');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence detecttime created/);
__PACKAGE__->sequence('url_id_seq');

## TODO: database config?
my @plugins = __PACKAGE__->plugins();
push(@plugins, ('suspicious','botnet','malware','phishing','spam'));

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
                #$args->{'apikey'},
                $args->{'limit'},
            ],
            group_map       => $args->{'group_map'},
            restriction_map => $args->{'restriction_map'},
        };
        my $f = $class->SUPER::generate_feeds($feed_args);
        if(keys %$f){
            $f = $class->SUPER::encode_feed({ recs => $f, %$feed_args });
            push(@feeds,$f) if($f);
        }
    }
    $class->table($tbl);
    return(\@feeds);
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (t.hash) t.id, archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups ON t.guid = apikeys_groups.guid
    LEFT JOIN archive ON t.uuid = archive.uuid
    WHERE
        detecttime >= ?
        AND t.confidence >= ?
        -- AND apikeys_groups.uuid = ?
    ORDER BY t.hash ASC, t.id DESC
    LIMIT ?
});
    
1;
