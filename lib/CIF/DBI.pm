package CIF::DBI;
use base 'Class::DBI';

our $VERSION = '0.99_05';
$VERSION = eval $VERSION;

use strict;
use warnings;

use CIF qw/debug/;
use Config::Simple;

sub new {
    my $class = shift;
    my $args = shift;
    
    my $self = {};
    bless($self,$class);

    my ($err,$ret) = $self->init($args);
    return $err if($err);
    return(undef,$self);
}

sub init {
    my $self = shift;
    my $args = shift;
    
    my $config = Config::Simple->new($args->{'config'}) || return('missing config file');
    
    my $datatypes   = $config->param(-block => 'archive')->{'datatypes'} || ['infrastructure','domain','url','email','malware','search'];
    my $feeds       = $config->param(-block => 'archive')->{'feeds'};
    
    $self->{'datatypes'}    = $datatypes;
    $self->{'feeds'}        = $feeds;
    
    my ($err,$ret) = $self->init_db($args);
    return $err unless($ret);
    
    return (undef,$ret);
} 

sub init_db {
    my $self = shift;
    my $args = shift;
    
    my $config = Config::Simple->new($args->{'config'}) || return('missing config file');

    $config = $config->param(-block => 'db');
    
    my $db          = $config->{'database'} || 'cif';
    my $user        = $config->{'user'}     || 'postgres';
    my $password    = $config->{'password'} || '';
    my $host        = $config->{'host'}     || '127.0.0.1';
    
    my $dbi = 'DBI:Pg:database='.$db.';host='.$host;
    my $ret = $self->connection($dbi,$user,$password,{ AutoCommit => 0});
    return(undef,$ret);
}

# because UUID's are really primary keys too in our schema
# this overrides some of the default functionality of Class::DBI and 'id'
sub retrieve {
    my $class = shift;

    return $class->SUPER::retrieve(@_) if(@_ == 1);
    my %keys = @_;

    my @recs = $class->search_retrieve_uuid($keys{'uuid'});
    return unless(defined($#recs) && $#recs > -1);
    return($recs[0]);
}

sub vacuum {
    my $class = shift;
    my $args = shift;
    
    my $ts = $args->{'timestamp'};
    
    my ($ret,$err);
    
    ## TODO -- try catch?
    $ret = $class->sql_vacuum->execute($ts);
    $class->dbi_commit() unless($class->db_Main->{'AutoCommit'});
    return (undef,$ret);
}

__PACKAGE__->set_sql('retrieve_uuid' => qq{
    SELECT *
    FROM __TABLE__
    WHERE uuid = ?
    ORDER BY id DESC
    LIMIT 1
});

__PACKAGE__->set_sql('vacuum' => qq{
    DELETE FROM __TABLE__
    WHERE reporttime <= ?;
});


1;
