package CIF::Router::HTTP::Json;

use strict;
use warnings;

require Iodef::Pb::Format;
require CIF::Client;
use Data::Dumper;

sub handler {
    my $req = shift;

    my $r = Apache2::Request->new($req);
    
    my $cli = CIF::Client->new({
        apikey      => $r->param('apikey'),
        config      => '/home/cif/.cif',    
    });
    
    my ($err,$ret) = $cli->search({
        query       => $r->param('query'),
        limit       => $r->param('limit'),
        confidence  => $r->param('confidence'),
        nolog       => $r->param('nolog'),
    });
    
    my $nomap = 0;
    
    my @text;
    foreach my $feed (@$ret){
        next unless($feed->get_data());
    
        my $r_map = ($nomap) ? undef : $feed->get_restriction_map();
        my $t = Iodef::Pb::Format->new({
            format              => 'Json',
            group_map           => $feed->get_group_map(),
            restriction_map     => $r_map,
            data                => $feed->get_data(),
            confidence          => $feed->get_confidence(),
            guid                => $feed->get_guid(),
            uuid                => $feed->get_uuid(),
            description         => $feed->get_description(),
            restriction         => $feed->get_restriction(),
            reporttime          => $feed->get_ReportTime(),
            config              => $cli->get_config(),
        });
        
        ## TODO -- add feed meta data to this.
        push(@text,$t);
    }
    return(join('',@text));
    
}

1;