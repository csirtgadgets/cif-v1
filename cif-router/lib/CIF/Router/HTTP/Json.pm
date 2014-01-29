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
    my $router_config   = shift;
    my $req             = shift;
    my $router          = shift;

    my $r = Apache2::Request->new($req);
    
    my $apikey  = $r->param('apikey')   || return 'missing apikey';
    my $guid    = $r->param('guid')     || 'everyone';
    my $format  = $r->param('fmt')      || 'json';
    
    return Apache2::Const::Forbidden() unless($format =~ /^[a-zA-Z]+$/);
    
    $guid = generate_uuid_ns($guid) unless(is_uuid($guid));    
    
    my ($err,$ret) = CIF::Client->new({
        apikey      => $apikey,
        config      => $router_config, 
    });
    return($err) if($err);
    
    my $cli = $ret;
 
    for($req->method()){
        if(/^GET$/){
            my $query       = $r->param('q')    || $r->param('query');
            
            unless($query){
                if($format eq 'json'){    
                    return JSON::XS::encode_json({
                        status  => Apache2::Const::HTTP_OK(),
                        data    => 'missing query',
                    });
                }
                return 'missing query';
            }
            
            $query = lc($query);
            
            my $limit       = $r->param('limit') || $cli->get_limit() || 500;
            my $confidence  = $r->param('confidence');
            
            # if it's a feed query, protect the consumer appropriately
            $confidence = 95 if($query =~ /^[a-z]+\/[a-z]$/ && !defined($confidence));
        
            debug('query: '.$query);
            $ret = $cli->encode_query({
                query       => $query,
                limit       => $limit,
                confidence  => $confidence          || 0,
                nolog       => $r->param('nolog')   || 0,
            });
            my $rep = $router->process($ret->encode());
            
            $rep = MessageType->decode($rep);
            
            unless($rep->get_status() == MessageType::StatusType::SUCCESS()){
                return('failed: '.@{$rep->get_data()}[0]) if($rep->get_status() == MessageType::StatusType::FAILED());
                return('unauthorized') if($rep->get_status() == MessageType::StatusType::UNAUTHORIZED());
            }
            
            $ret = $cli->decode_results({ data => $rep });
            
            my $nomap = 0;
                        
            my @text;
            foreach my $feed (@$ret){
                next unless($feed->get_data());
            
                my $r_map = ($nomap) ? undef : $feed->get_restriction_map();
                my $t = Iodef::Pb::Format->new({
                    format              => ucfirst($format),
                    group_map           => $feed->get_group_map(),
                    restriction_map     => $r_map,
                    data                => $feed->get_data(),
                    confidence          => $feed->get_confidence(),
                    guid                => $feed->get_guid(),
                    uuid                => $feed->get_uuid(),
                    description         => $feed->get_description(),
                    restriction         => $feed->get_restriction(),
                    reporttime          => $feed->get_ReportTime(),
                    config              => $cli->get_global_config(),
                });
                
                ## TODO -- add feed meta data to this.
                push(@text,$t);
            }
            return(join('',@text));
        }
        if(/^POST$/){
            debug('posting...');
            my $len = $req->headers_in->{'content-length'};
            unless($len > 0){
                return Apache2::Const::FORBIDDEN();
            }
            my $buffer;
            $req->read($buffer,$req->headers_in->{'content-length'});
            $buffer = JSON::XS::decode_json($buffer);
            return Apache2::Const::FORBIDDEN() unless($buffer);
            $buffer = [ $buffer ] unless(ref($buffer) eq 'ARRAY');
            
            if($#{$buffer} > 5000){
                return JSON::XS::encode_json({
                    status  => Apache2::Const::FORBIDDEN(),
                    data    => 'legacy JSON API should only be used for smaller data-sets (less than 5,000), use the normal API or cif_smrt for larger data-sets',
                });
            }

            foreach (@$buffer){
                # set the guid
                $_->{'guid'} = $guid unless($_->{'guid'});
                $_->{'guid'} = generate_uuid_ns($_->{'guid'}) unless(is_uuid($_->{'guid'}));
                
                $_->{'source'} = $r->param('apikey');
                $_->{'source'} = generate_uuid_ns($_->{'source'});
                
                # reset the confidence if it's too high
                my $confidence = 85;
                $confidence = $_->{'confidence'} if($_->{'confidence'} =~ /^\d+$/ && $_->{'confidence'} < 85);
                $_->{'confidence'} = $confidence;
                
                # crudely overwritte, assume the cli is braindead
                my $reporttime = DateTime->from_epoch(epoch => time());
                $_->{'reporttime'} = $reporttime->ymd().'T'.$reporttime->hms().'Z';
                
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
                    debug($e);
                    return Apache2::Const::HTTP_BAD_REQUEST();
                }
                $_ = $_->encode();
                
            }

            $ret = $cli->new_submission({
                guid    => $guid,
                data    => $buffer,
            });
            ($err,$ret) = $cli->submit($ret);
            
            if($err){
                debug($err);
                return(Apache2::Const::HTTP_BAD_REQUEST())
            }
            
            return JSON::XS::encode_json({
                status  => Apache2::Const::HTTP_OK(),
                data    => $ret->get_data(),
            });
        }
    }
    return Apache2::Const::FORBIDDEN();
    
}

1;