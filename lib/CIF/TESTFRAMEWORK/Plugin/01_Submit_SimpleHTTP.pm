package CIF::TESTFRAMEWORK::Plugin::01_Submit_SimpleHTTP;
use base 'CIF::TESTFRAMEWORK::Plugin';

use strict;
use warnings;

use LWP::UserAgent;
use JSON::XS;

use CIF qw/debug/;

sub run {
    my $self = shift;
    my $args = shift;
    
    my @tests = @{$args->{'tests'}};
    my $cli = $args->{'client'};
    
    my $loop    = $args->{'loop'} || 0;
    
    my $ua = LWP::UserAgent->new();
    $ua->ssl_opts(SSL_verify_mode => 'SSL_VERIFY_NONE');
    $ua->ssl_opts(verify_hostname => 0);
    $ua->default_header('Accept' => 'application/json');
    
    my $url = $cli->get_config->{'host'};
    $url .= '?apikey='.$cli->get_config->{'apikey'};
    
    my ($ret,$err);
    for (my $i = 0; $i < $loop; $i++){
        foreach my $t (@tests){
            debug('query: '.$t->{'address'});
            $ret = $ua->post($url,Content => encode_json($t));
            
            return ($ret->content()) unless($ret->status_line() eq '200');
            return('query failed: '.$t->{'address'}) unless($ret);
        }
    }
    debug('tests successful...');
    
    return 1;
}

sub basic {}

sub feed {}

1;