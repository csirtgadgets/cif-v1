package CIF::Client::Transport::HTTP;
use base 'Class::Accessor';
use base 'LWP::UserAgent';

use strict;
use warnings;

use CIF qw/debug/;
require LWP::UserAgent;
use Try::Tiny;
use JSON::XS;

our $AGENT = 'libcif/'.$CIF::VERSION.' (collectiveintel.org)';

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(config));

sub new {
    my $class = shift;
    my $args = shift;
 
    my $self = {};
    bless($self,$class);
        
    $self->set_config($args->{'config'});
     
    # seems to be a bug if you don't set this
    $self->{'max_redirect'}    = $args->{'max_redirect'} || 5;

    if(defined($self->get_config->{'verify_tls'}) && $self->get_config->{'verify_tls'} == 0){
        $self->ssl_opts(SSL_verify_mode => 'SSL_VERIFY_NONE');
        $self->ssl_opts(verify_hostname => 0);
    }

    if($self->get_config->{'proxy'}){
        debug('setting proxy') if($::debug);
        $self->proxy(['http','https'],$self->get_config->{'proxy'});
    }
    
    $self->agent($AGENT);

    return($self);
}

sub send {
    my $self = shift;
    my $data = shift;
    
    return $self->_send($data);
}

sub send_json {
    my $self = shift;
    my $args = shift;
    
    my $apikey  = $args->{'apikey'} || return 'missing apikey';
    my $data    = $args->{'data'}   || return 'missing data';
    
    $self->default_header('Accept' => 'application/json');
    $self->get_config->{'host'} .= '?apikey='.$apikey;
    return $self->_send($data);
}

sub _send {
    my $self = shift;
    my $data = shift;
    return unless($data);
    
    my ($err,$ret);
    my $x = 0;
    
    do {
        try {
            $ret = $self->post($self->get_config->{'host'},Content => $data);
        } catch {
            $err = shift;
        };
        if($err){
            for(lc($err)){
                if(/^server closed connection/){
                    debug('server closed the connection, retrying...') if($::debug);
                    $err = undef;
                    sleep(5);
                    last;
                }
                if(/connection refused/){
                    debug('server connection refused, retrying...') if($::debug);
                    $err = undef;
                    sleep(5);
                    last;
                }
                $x = 5;
            }
        }
    } while(!$ret && ($x++ < 5));
    ## TODO -- do we turn this into a re-submit?
    return('ERROR: unknown server failure....') unless($ret);
    return($ret->status_line()) unless($ret->is_success());
    return(undef,$ret->decoded_content());
}

1;