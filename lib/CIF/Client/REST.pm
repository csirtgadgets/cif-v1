package CIF::Client::REST;
use base 'Class::Accessor';
use base 'LWP::UserAgent';

use strict;
use warnings;

use CIF;
require LWP::UserAgent;

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
        $self->ssl_opts(verify_hostname => 0);
    }

    if($self->get_config->{'proxy'}){
        warn 'setting proxy' if($::debug);
        $self->proxy(['http','https'],$self->get_config->{'proxy'});
    }
    
    $self->agent('libcif/'.$CIF::VERSION);

    return($self);
}

sub send {
    my $self = shift;
    my $data = shift;
    return unless($data);
    
    my $ret = $self->post($self->get_config->{'host'}.'/',Content => $data);
    return($ret->status_line()) unless($ret->is_success());
    return(undef,$ret->decoded_content());
}

1;