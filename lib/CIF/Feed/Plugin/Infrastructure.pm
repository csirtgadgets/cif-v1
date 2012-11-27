package CIF::Feed::Plugin::Infrastructure;
use base 'CIF::Feed::Plugin::Address';

use warnings;
use strict;

use Net::Patricia;
use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use CIF qw/debug/;

__PACKAGE__->table('infrastructure');
__PACKAGE__->sequence('infrastructure_id_seq');

## TODO: database config?
my @plugins = __PACKAGE__->plugins();

# these are the built-in indicies
push(@plugins, ('suspicious','botnet','malware','fastflux','phishing','scan','whitelist','passive'));

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
                $args->{'limit'},
                $args->{'uuid'},
            ],
            group_map       => $args->{'group_map'},
            restriction_map => $args->{'restriction_map'},
            restriction     => $args->{'restriction'},
        };
        debug('generating '.$desc);
        my $f = $class->SUPER::generate_feeds($feed_args);
        debug('found: '.keys(%$f));
        if(keys %$f){
            debug('testing whitelist: '.$desc);
            $f = $class->test_whitelist({ recs => $f, %$feed_args, whitelist => $whitelist }); 
        }
        debug('final count: '.keys(%$f));
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

## TODO - refactor this with domain.pm
sub generate_whitelist {
    my $class = shift;
    my $args = shift;
    
    return if($class->table() eq 'infrastructure_whitelist');
    
    debug('generating whitelist');
    my $tbl = $class->table();
    $class->table('infrastructure_whitelist');
    my @wl_recs = $class->search_feed_whitelist(
        $args->{'start_time'},
        25,
        25000,
    );
    $class->table($tbl);
    debug('wl recs: '.$#wl_recs);
    
    my $whitelist = Net::Patricia->new();
    debug('generating ip_tree');
    $whitelist->add_string($_) foreach @perm_whitelist;
    
    if($#wl_recs > -1){
        $whitelist->add_string($_->{'address'}) foreach (@wl_recs);
    }
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
            
    return($recs);    
}

1;
