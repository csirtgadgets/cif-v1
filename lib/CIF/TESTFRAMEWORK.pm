package CIF::TESTFRAMEWORK;
use base 'Class::Accessor';

use strict;
use warnings;

use Module::Pluggable require => 1;
use Config::Simple;
use CIF qw/debug/;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(
    dbh config db_config
    plugins profile client
    tests
));

our @plugins = sort  __PACKAGE__->plugins();

sub new {
    my $class   = shift;
    my $args    = shift;
    
    my $self = {};
    bless($self,$class);
    
    my ($err,$ret) = $self->init($args);
    return $err if($err);
    return (undef,$self);
}

sub init {
    my $self    = shift;
    my $args    = shift;
    
    my ($err,$ret) = $self->init_profile($args);
    return ($err) if($err);
    
    ($err,$ret) = $self->init_client($args);
    return ($err) if($err);
    
    $self->set_tests($args->{'tests'});
    
    # do this last, it turns config into an obj
    ($err,$ret) = $self->init_config($args);
    return ($err) if($err);
    
    $self->set_plugins(\@plugins);
    
    return (undef,1);    
}

sub init_config {
    my $self = shift;
    my $args = shift;
    
    my $cfg = $args->{'config'};
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return('missing config file');
    
    return(undef,1);   
}

sub init_profile {
    my $self = shift;
    my $args = shift;
  
    require CIF::Profile;
    my $profile = CIF::Profile->new({
        config  => $args->{'config'},
    });

    $self->set_profile($profile);
    return(undef,1);
}

sub init_client {
    my $self = shift;
    my $args = shift;
    
    my ($err,$ret) = CIF::Client->new({
        config  => $args->{'config'},
    });
    return($err) if($err);
    $self->set_client($ret);
    return(undef,1);
    
}

sub init_apikey {
    my $self = shift;
    my $args = shift;
    
    my $p = $self->get_profile();
    
    ## TODO -- try/catch
    my $id = $p->user_add({
        userid          => 'TEST-FRAMEWORK',
        write           => 1,
        groups          => 'everyone',
        default_group   => 'everyone',
    });
    return($id);
}

sub purge_apikey {
    my $self = shift;
    my $arg  = shift;
    
    my $p = $self->get_profile();
    
    my $ret = $p->remove($arg);
    return ($ret);
}

sub process {
    my $self = shift;
    my $args = shift;
    
    $args->{'tests'} = $self->get_tests();
    
    foreach my $p (@{$self->get_plugins()}){
        debug('running: '.$p);
        $p->run($args);
    }
}

1;