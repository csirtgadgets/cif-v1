package CIF::Feed::Plugin::Domain;
use base 'CIF::Feed::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use CIF qw/debug/;

__PACKAGE__->table('domain');
__PACKAGE__->columns(All => qw/id uuid guid address confidence detecttime created/);
__PACKAGE__->sequence('domain_id_seq');

## TODO: database config?
my @plugins = __PACKAGE__->plugins();
push(@plugins, ('suspicious','botnet','malware','fastflux','phishing','nameserver','whitelist'));

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
        my $desc = $t.' domain feed';
        $t = 'domain_'.$t;
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

sub test_whitelist {
    my $class = shift;
    my $args = shift;
    
    return $args->{'recs'} if($class->table() =~ /whitelist$/);
    
    my $recs = $args->{'recs'};
  
    my %hash;
    foreach(keys %$recs){
        next if(exists($hash{$recs->{$_}->{'address'}}));
        $hash{$recs->{$_}->{'address'}} = $recs->{$_};
    }
    my @whitelist = $class->search_feed_whitelist(
        $args->{'start_time'},
        25000,
    );
    
    foreach my $w (@whitelist){
        my $wa = $w->{'address'};
        # linear approach first
        if(exists($hash{$wa})){
            delete($hash{$wa});
        } else {
            # else rip through the keys and make sure
            # test1.yahoo.com doesn't exist in the whitelist as yahoo.com
            foreach my $x (keys %hash){
                    if($x =~ /\.$wa$/){
                        delete($hash{$x});
                    }
            }
        }   
    }
    return(\%hash);
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT ON (t.address) t.address, t.id, archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups ON t.guid = apikeys_groups.guid
    LEFT JOIN archive ON t.uuid = archive.uuid
    WHERE 
        detecttime >= ?
        AND t.confidence >= ?
        AND t.guid = ?
        AND NOT EXISTS (
            SELECT dw.address FROM domain_whitelist dw
            WHERE
                dw.detecttime >= ?
                AND dw.confidence >= 25
                AND dw.address = t.address
        )
    ORDER BY t.address, t.id ASC, confidence DESC
    LIMIT ?
});

__PACKAGE__->set_sql('feed_whitelist' => qq{
    SELECT DISTINCT ON (t.uuid) t.uuid, address, confidence
    FROM domain_whitelist t
    WHERE
        t.detecttime >= ?
        AND t.confidence >= 25
    ORDER BY t.uuid DESC, t.id ASC
    LIMIT ?
});

    
1;
