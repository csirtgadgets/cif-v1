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
        debug('records: '.keys %$f);
        if(keys %$f){
            debug($desc.': testing whitelist');
            $f = $class->test_whitelist({ recs => $f });  
        }
        debug('total records: '.keys %$f);
        debug($desc.': encoding');
        $f = $class->SUPER::encode_feed({ recs => $f, %$feed_args });
        push(@feeds,$f);
    }
    $class->table($tbl);
    return(\@feeds);
}

sub generate_whitelist {
    my $class = shift;
    my $args = shift;
    
    debug('generating whitelist');
    my @whitelist = $class->search_feed_whitelist(
        $args->{'start_time'},
        25000,
    );
    
    return unless($#whitelist > -1 );
    my $wl;
    map { $wl->{lc($_->{'address'})} = 1 } @whitelist;
    return($wl);
}

## TODO -- double test this
sub test_whitelist {
    my $class = shift;
    my $args = shift;
    
    return $args->{'recs'} if($class->table() =~ /whitelist$/);
    
    my $whitelist = $args->{'whitelist'};
    my $recs = $args->{'recs'};
        
    my %hash;
    foreach my $rec (keys %$recs){
        my $a = lc($recs->{$rec}->{'hash'});
        next if(exists($whitelist->{$a}));
        $hash{$a} = $recs->{$rec};
    }
    return(\%hash);
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (t1.hash) t1.hash, t1.id, archive.data
    FROM (
        SELECT t.hash, t.id, t.uuid, t.guid
        FROM __TABLE__ t
        WHERE
            t.detecttime >= ?
            AND t.confidence >= ?
        ORDER by t.id DESC
    ) t1
    LEFT JOIN archive ON t1.uuid = archive.uuid
    LEFT JOIN apikeys_groups ON t1.guid = apikeys_groups.guid
    WHERE 
        t1.guid = ?
        AND NOT EXISTS (
            SELECT w.hash FROM url_whitelist w
            WHERE
                w.detecttime >= ?
                AND w.confidence > 25
                AND w.hash = t1.hash
        )
    LIMIT ?
});

__PACKAGE__->set_sql('feed_whitelist' => qq{
    SELECT DISTINCT on (t1.hash) t1.hash
    FROM (
        SELECT t2.hash
        FROM url_whitelist t2
        WHERE
            t2.detecttime >= ?
            AND t2.confidence >= 25
        ORDER BY id DESC
        LIMIT ?
    ) t1
});
    
1;
