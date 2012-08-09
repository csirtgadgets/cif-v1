package CIF::Feed::Plugin::Infrastructure;
use base 'CIF::Feed::Plugin';

use warnings;
use strict;

use Net::Patricia;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

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
        my $f = $class->SUPER::generate_feeds($feed_args);
        if(keys %$f){
            $f = $class->test_whitelist({ recs => $f, %$feed_args }); 
        }
        # we create a feed no matter what
        # because of the way guid's work, it's better to do it this way
        # it's better to get nothing based on your key's 'default guid' rather than
        # a feed from another guid you weren't expecting...
        $f = $class->SUPER::encode_feed({ recs => $f, %$feed_args });
        push(@feeds,$f);
    }
    $class->table($tbl);
    return(\@feeds);
}

sub test_whitelist {
    my $class = shift;
    my $args = shift;
    
    return $args->{'recs'} if($class->table() =~ /whitelist$/);

    my @whitelist = $class->search_feed_whitelist(
        $args->{'start_time'},
        25000,
    );

    return $args->{'recs'} unless($#whitelist > -1);
    
    ## TODO: test this a bit more with CIDR blocks
    my $pt = Net::Patricia->new();
    $pt->add_string($_) foreach @perm_whitelist;
  
    my $recs = $args->{'recs'};
    foreach my $wl (@whitelist){
        $pt->add_string($wl->{'address'});
        foreach my $rec (keys %$recs){
            my $addr = $recs->{$rec}->{'address'};
            delete($recs->{$rec}) if($pt->match_string($addr)); 
        }
    }
            
    return($recs) if(keys %$recs);    
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (address,protocol,portlist) t.address, t.id, archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups ON t.guid = apikeys_groups.guid
    LEFT JOIN archive ON t.uuid = archive.uuid
    WHERE 
        detecttime >= ?
        AND t.confidence >= ?
        AND t.guid = ?
        AND NOT EXISTS (
            SELECT iw.address FROM infrastructure_whitelist iw 
            WHERE 
                iw.detecttime >= ?
                -- TODO: this should be a calculated var
                AND iw.confidence >= 25 
                AND iw.address = t.address
        ) 
    ORDER BY address,protocol,portlist ASC, confidence DESC, detecttime DESC, t.id DESC 
    LIMIT ?
});

__PACKAGE__->set_sql('feed_whitelist' => qq{
    SELECT DISTINCT ON (t.uuid) t.uuid, address, confidence
    FROM infrastructure_whitelist t
    WHERE
        t.detecttime >= ?
        AND t.confidence >= 25
    ORDER BY t.uuid DESC, t.id ASC
    LIMIT ?
});

    
1;
