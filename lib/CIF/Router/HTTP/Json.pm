package CIF::Router::HTTP::Json;

use strict;
use warnings;

require Iodef::Pb::Format;
require CIF::Client;
require JSON::XS;
use Data::Dumper;
use CIF qw/debug generate_uuid_ns is_uuid generate_uuid_random/;
use Try::Tiny;

sub handler {
    my $req = shift;

    my $r = Apache2::Request->new($req);
    
    my $apikey  = $r->param('apikey')   || return 'missing apikey';
    my $guid    = $r->param('guid')     || 'everyone';
    
    $guid = generate_uuid_ns($guid) unless(is_uuid($guid));    
    
    my ($err,$ret) = CIF::Client->new({
        apikey      => $apikey,
        config      => '/home/cif/.cif', 
    });
    return($err) if($err);
    
    my $cli = $ret;
 
    for($req->method()){
        if(/^GET$/){
            ($err,$ret) = $cli->search({
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
        if(/^POST$/){
            my $len = $req->headers_in->{'content-length'};
            unless($len > 0){
                return Apache2::Const::FORBIDDEN;
            }
            my $buffer;
            $req->read($buffer,$req->headers_in->{'content-length'});
            $buffer = JSON::XS::decode_json($buffer);
            return Apache2::Const::FORBIDDEN() unless($buffer);
            $buffer = [ $buffer ] unless(ref($buffer) eq 'ARRAY');

            foreach (@$buffer){
                $_->{'guid'} = $guid unless($_->{'guid'});
                my $e;
                unless($_->{'id'} && is_uuid($_->{'id'})){
                    $_->{'id'} = generate_uuid_random();
                }
                try {
                    $_ = Iodef::Pb::Simple->new($_);
                } catch {
                    $e = shift;
                };
 
                if($e){
                    return JSON::XS::encode_json({
                        data    => $e,
                        status  => '200',
                    });
                }
                
            }
            $ret = $cli->new_submission({
                guid    => $guid,
                data    => $buffer,
            });
            ($err,$ret) = $cli->submit($ret);
            return({
                JSON::XS::encode_json({
                    status  => 200,
                    data    => $err,
                })
            }) if($err);
            return JSON::XS::encode_json({
                status  => 200,
                data    => $ret->get_data(),
            });
        }
    }
    return JSON::XS::encode_json({
        status  => 200,
        data    => 'unauthorized method',
    });
    
}

1;