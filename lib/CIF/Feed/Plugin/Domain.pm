package CIF::Feed::Plugin::Domain;
use base 'CIF::Feed::Plugin::Address';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use CIF qw/debug/;
use Net::DNS::Match;

__PACKAGE__->table('domain');
__PACKAGE__->sequence('domain_id_seq');

## TODO: database config?
my @plugins = __PACKAGE__->plugins();
push(@plugins, ('suspicious','botnet','malware','fastflux','phishing','whitelist','passive','spam','spamvertising'));

sub generate_feeds {
    my $class   = shift;
    my $args    = shift;
    
    my $tbl = $class->table();
    
    my $whitelist = $class->generate_whitelist($args);
  
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
                $args->{'limit'},
                $args->{'uuid'},
            ],
            group_map       => $args->{'group_map'},
            restriction_map => $args->{'restriction_map'},
            restriction     => $args->{'restriction'},
        };
        debug($desc.': generating');
        my $f = $class->SUPER::generate_feeds($feed_args);
        debug('found: '.keys(%$f));
        
        if(keys %$f){
            debug($desc.': testing whitelist');
            $f = $class->test_whitelist({ recs => $f, %$feed_args, whitelist => $whitelist });  
        }
        debug('final count: '.keys(%$f));
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
    
    return if($class->table() =~ /_whitelist$/);
    
    debug('generating whitelist');
    my $tbl = $class->table();
    $class->table('infrastructure_whitelist');
    my @whitelist = $class->search_feed_whitelist(
        $args->{'start_time'},
        25, #confidence
        25000 # limit
    );
    $class->table($tbl);
    return unless($#whitelist > -1 );
    
    @whitelist = map { $_ = $_->{'address'} } @whitelist;
    
    return(\@whitelist);
} 

sub test_whitelist {
    my $class = shift;
    my $args = shift;

    return $args->{'recs'} if($class->table() =~ /whitelist$/);
    return $args->{'recs'} unless($args->{'whitelist'}); 
    my $whitelist = $args->{'whitelist'};
    
    my $wl_tree = Net::DNS::Match->new();
    $wl_tree->add($whitelist);
     
    my $recs = $args->{'recs'};

    debug('filtering through '.(keys %$recs).' records');
    
    my %hash;
    foreach(keys %$recs){
        my $a = $recs->{$_}->{'address'};
        next if(exists($hash{$a}));
        next if($wl_tree->match($a));
        $hash{$a} = $recs->{$_};
    }   

    return(\%hash);
}

    
1;
