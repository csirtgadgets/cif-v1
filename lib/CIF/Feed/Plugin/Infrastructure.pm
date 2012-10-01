package CIF::Feed::Plugin::Infrastructure;
use base 'CIF::Feed::Plugin';

use warnings;
use strict;

use Net::Patricia;
use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use CIF qw/debug/;

__PACKAGE__->table('infrastructure');
__PACKAGE__->columns(All => qw/id uuid guid address portlist protocol confidence detecttime created/);
__PACKAGE__->sequence('infrastructure_id_seq');

## TODO: database config?
my @plugins = __PACKAGE__->plugins();
push(@plugins, ('suspicious','botnet','malware','fastflux','phishing','scan','whitelist'));

## TODO -- IPv6
my @perm_whitelist = (
    "0.0.0.0/8",
    "10.0.0.0/8",
    "127.0.0.0/8",
    "192.168.0.0/16",
    "169.254.0.0/16",
    "192.0.2.0/24",
    "224.0.0.0/4",
    "240.0.0.0/5",
    "248.0.0.0/5"
);

sub generate_feeds {
    my $class   = shift;
    my $args    = shift;
    
    my $tbl = $class->table();
    
    my $whitelist = $class->generate_whitelist($args);
    
    my @feeds;
    foreach my $p (@plugins){
        my $t = $p;
        if($p =~ /Infrastructure::(\S+)$/){
            $t = lc($1);
        }
        my $desc = $t.' infrastructure feed';
        $t = 'infrastructure_'.$t;
        $class->table($t);
        my $feed_args = {
            description => $desc,
            report_time => $args->{'report_time'},
            confidence  => $args->{'confidence'},
            guid        => $args->{'guid'},
            start_time  => $args->{'start_time'},
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
        debug('generating '.$desc);
        my $f = $class->SUPER::generate_feeds($feed_args);
        if(keys %$f){
            debug('testing whitelist: '.$desc);
            $f = $class->test_whitelist({ recs => $f, %$feed_args, whitelist => $whitelist }); 
        }
        # we create a feed no matter what
        # because of the way guid's work, it's better to do it this way
        # it's better to get nothing based on your key's 'default guid' rather than
        # a feed from another guid you weren't expecting...
        debug('encoding: '.$desc);
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
    my @wl_recs = $class->search_feed_whitelist(
        $args->{'start_time'},
        25000,
    );
    
    debug('wl recs: '.$#wl_recs);
    
    debug('generating ip_tree');
    my $whitelist = Net::Patricia->new();
    $whitelist->add_string($_) foreach @perm_whitelist;
    $whitelist->add_string($_->{'address'}) foreach (@wl_recs);
    return $whitelist;
}

sub test_whitelist {
    my $class = shift;
    my $args = shift;
    
    return $args->{'recs'} if($class->table() =~ /whitelist$/);
    return $args->{'recs'} unless($args->{'whitelist'}->climb());
    
    my $whitelist = $args->{'whitelist'};
    my $recs = $args->{'recs'};
    
    foreach my $rec (keys %$recs){
        delete($recs->{$rec}) if($whitelist->match_string($recs->{$rec}->{'address'})); 
    }
            
    return($recs) if(keys %$recs);    
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (t1.address,t1.protocol,t1.portlist) t1.address, t1.id, archive.data
    FROM (
        SELECT t.address, t.protocol, t.portlist, t.id, t.uuid, t.guid
        FROM __TABLE__ t
        WHERE 
            detecttime >= ?
            AND t.confidence >= ?            
        ORDER BY id DESC
    ) t1
    LEFT JOIN archive ON t1.uuid = archive.uuid
    LEFT JOIN apikeys_groups ON t1.guid = apikeys_groups.guid
    WHERE t1.guid = ?
    AND NOT EXISTS (
        SELECT w.address FROM infrastructure_whitelist w
        WHERE
                w.detecttime >= ?
                AND w.confidence >= 25
                AND w.address = t1.address
    )
    LIMIT ?
});

__PACKAGE__->set_sql('feed_whitelist' => qq{
    SELECT DISTINCT on (t1.address) t1.address
    FROM (
        SELECT t2.address
        FROM infrastructure_whitelist t2
        WHERE
            t2.detecttime >= ?
            AND t2.confidence >= 25
        ORDER BY id DESC
        LIMIT ?
    ) t1
});

    
1;
