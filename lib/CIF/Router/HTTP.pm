package CIF::Router::HTTP;

use strict;
use warnings;

## TODO -- split this out in CIF v2
## leaving it here for now, simplier

use APR::Table ();
use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Response;
use Apache2::Const qw(:common :http);

require CIF::Router;
require CIF::Router::HTTP::Json;
use CIF qw/init_logging/;
use Data::Dumper;

## NOTE: we do it this way cause mod_perl calls us by name
## not CIF::Router
## required by ::Router
sub new {
    my $class = shift;
    my $self = {};
    bless($self,$class);
    return($self);
}

sub handler {
    my $req = shift;
    
    my ($err,$router) = CIF::Router->new({
        config  => $req->dir_config->get('CIFRouterConfig') || '/home/cif/.cif',
    });
    if($err){
        ## TODO -- set debugging variable
        debug($err);
        return Apache2::Const::SERVER_ERROR();
    }
    my $debug = $router->get_config->{'debug'} || 0;
    init_logging($debug);

    my $reply;
    
    # test for legacy [v0] support first
    # this basically does a recursive lookup and translates out for us
    if($req->headers_in->{'Accept'} && $req->headers_in->{'Accept'} eq 'application/json'){
        return Apache2::Const::FORBIDDEN if($router->get_config->{'disable_legacy'});
        $req->content_type('application/json');
        $reply = CIF::Router::HTTP::Json::handler($req);
    } else {
        return unless($req->method() eq 'POST');
        my $len = $req->headers_in->{'content-length'};
        unless($len > 0){
            return Apache2::Const::FORBIDDEN;
        }
        my $buffer;
        $req->read($buffer,$req->headers_in->{'content-length'});
        $req->content_type('application/x-protobuf');
        $reply = $router->process($buffer);
    }
    
    $req->status(Apache2::Const::HTTP_OK);
    $req->headers_out()->add('Content-length',length($reply));

    binmode STDOUT;
    print $reply;
    return Apache2::Const::OK;
}

1;