#!/usr/bin/perl

use warnings;
use strict;

use LWP::UserAgent;
use JSON::XS;
use Data::Dumper;

my $url = 'https://localhost?apikey=XXXX';

my $ua = LWP::UserAgent->new();
$ua->ssl_opts(verify_hostname => 0);
$ua->default_header('Accept' => 'application/json');

my $hash = {
    address     => 'example.com',
    assessment  => 'botnet',
    confidence  => 86,
    description => 'zeus',
};

my $ret = $ua->post($url,Content => encode_json($hash));
warn Dumper($ret);
