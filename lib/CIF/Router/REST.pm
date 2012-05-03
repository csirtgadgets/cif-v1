package CIF::Router::REST;

use strict;
use warnings;

## TODO -- split this out in CIF v2
## leaving it here for now, simplier

use APR::Table ();
use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Const qw(:common :http);

sub handler {
    my $req = shift;
    
    return unless($req->method() eq 'POST');
        
    my $len = $req->headers_in->{'content-length'};
    unless($len > 0){
        return Apache2::Const::FORBIDDEN;
    }
    my $buffer;
    $req->read($buffer,$req->headers_in->{'content-length'});
    
    require CIF::Router;
    my ($err,$router) = CIF::Router->new({
        config  => $req->dir_config->get('CIFRouterRESTConfig') || '/home/cif/.cif',
    });
    if($err){
        ## TODO -- set debugging variable
        warn $err;
        return Apache2::Const::SERVER_ERROR();
    }
    my $reply = $router->process($buffer);
    
    $req->content_type('application/x-protobuf');
    $req->status(Apache2::Const::HTTP_OK);
    $req->headers_out()->add('Content-length',length($reply));

    binmode STDOUT;
    print $reply;
    return Apache2::Const::OK;
}

1;