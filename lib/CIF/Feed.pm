package CIF::Feed;
use base 'Class::Accessor';

use 5.008008;
use strict;
use warnings;

our $VERSION = '0.99_01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

use CIF qw/generate_uuid_ns generate_uuid_random is_uuid/;
use CIF::APIKey;
use Module::Pluggable require => 1, except => qr/CIF::Feed::Plugin::\S+::/;
use Data::Dumper;
use Digest::SHA1 qw(sha1_hex);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(config db_config feeds confidence roles limit limit_days start_time report_time group_map restriction_map));

my @plugins = __PACKAGE__->plugins();

sub new {
    my $class = shift;
    my $args = shift;
    
    my $self = {};
    bless($self,$class);
    
    $self->init($args);

    return (undef,$self);
}

sub init {
    my $self = shift;
    my $args = shift;
    
    $self->init_config( $args);   
    $self->init_db(     $args);
    
    my $report_time = $args->{'report_time'} || time();
    
    if($report_time =~ /^\d+$/){
        $report_time = DateTime->from_epoch(epoch => $report_time);
        $report_time = $report_time->ymd().'T'.$report_time->hms().'Z';
    }
    $self->set_report_time($report_time);
    
    my $start_time = DateTime->from_epoch(epoch => time - ($self->get_limit_days() * 84600));
    $self->set_start_time($start_time->ymd().'T'.$start_time->hms().'Z');
}

sub init_config {
    my $self = shift;
    my $args = shift;
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return(undef,'missing config file');
    
    $self->set_config(          $args->{'config'}->param(-block => 'cif_feeds'));
    $self->set_db_config(       $args->{'config'}->param(-block => 'db'));
    $self->set_restriction_map( $args->{'config'}->param(-block => 'restriction_map')); 
    $self->set_group_map(       $args->{'config'}->param(-block => 'groups'));
    
    ## TODO: add groups here 
    
    if(my $c = $args->{'confidence'}){
        unless(ref($c) eq 'ARRAY'){
            my @a = split(/,/,$c);
            $c = \@a;
        }
        $self->set_confidence($c);
    }
    
    $self->set_limit(       $args->{'limit'}        || $self->get_config->{'limit'}         || 10000);
    $self->set_limit_days(  $args->{'limit_days'}   || $self->get_config->{'limit_days'}    ||3);
    
    if(my $roles = $args->{'roles'} || $self->get_config->{'roles'}){
        unless(ref($roles) eq 'ARRAY'){
            my @a = split(/,/,$roles);
            $roles = \@a;
        }
        $self->set_roles($roles);
    }
    
    my $enabled = $args->{'specific_feeds'} || $self->get_config->{'enabled'};
    return ('no feeds specified') unless($enabled);
    
    my @array = (ref($enabled) eq 'ARRAY') ? @$enabled : split(/,/,$enabled);
    
    $self->set_feeds(\@array);
    
    my $confidence = $args->{'confidence'} || $self->get_config->{'confidence'} || '95,85';
    my @array2 = (ref($confidence) eq 'ARRAY') ? @$confidence : split(/,/,$confidence);
    $self->set_confidence(\@array2);
    
    $self->init_restriction_map();
    $self->init_group_map();
}

sub init_db {
    my $self = shift;
    my $args = shift;
    
    my $config = $self->get_db_config();
    
    my $db          = $config->{'database'} || 'cif';
    my $user        = $config->{'user'}     || 'postgres';
    my $password    = $config->{'password'} || '';
    my $host        = $config->{'host'}     || '127.0.0.1';
    
    my $dbi = 'DBI:Pg:database='.$db.';host='.$host;
    
    require CIF::DBI;
    my $ret = CIF::DBI->connection($dbi,$user,$password,{ AutoCommit => 0});
    return $ret;   
}

sub init_restriction_map {
    my $self = shift;
    
    return unless($self->get_restriction_map());
    my $array;
    foreach (keys %{$self->get_restriction_map()}){
        
        ## TODO map to the correct Protobuf RestrictionType
        my $m = FeedType::MapType->new({
            key => $_,
            value   => $self->get_restriction_map->{$_},
        });
        push(@$array,$m);
    }
    $self->set_restriction_map($array);
}

sub init_group_map {
    my $self = shift;
    
    return unless($self->get_group_map());
    my $g = $self->get_group_map->{'groups'};
    
    # system wide groups
    push(@$g, qw(everyone root));
    my $array;
    foreach (@$g){
        my $m = FeedType::MapType->new({
            key     => generate_uuid_ns($_),
            value   => $_,
        });
        push(@$array,$m);
    }
    
    $self->set_group_map($array);
}

sub process {
    my $self = shift;
    my $feed = shift;
  
    my @ids;
    foreach my $confidence (@{$self->get_confidence()}){
        foreach my $role (@{$self->get_roles()}){
            my $p = 'CIF::Feed::Plugin::'.ucfirst($feed);
            my $ret = $p->generate_feeds({
                confidence      => $confidence,
                guid            => generate_uuid_ns($role),
                limit           => $self->get_limit(),
                start_time      => $self->get_start_time(),
                report_time     => $self->get_report_time(),
                group_map       => $self->get_group_map(),
                restriction_map => $self->get_restriction_map(),
            });
            next unless(@$ret);
                       
            foreach my $f (@$ret){
                my ($err,$id) = CIF::Archive->insert({
                    data    => $f,
                    guid    => $f->get_guid(),
                    created => $f->get_ReportTime(),
                });
                if($err){
                    warn $err;
                    CIF::Archive->dbi_rollback() unless(CIF::Archive->db_Main->{'AutoCommit'});
                    return($err);
                }
                push(@ids,$id);
                warn 'id: '.$id.' confidence: '.$confidence.' desc: '.$f->get_description().' role: '.$role if($::debug);
            }
            
            CIF::Archive->dbi_commit() unless(CIF::Archive->db_Main->{'AutoCommit'});
        }
    }
    return(undef,\@ids);
}

sub purge_feeds {
    my $self = shift;
    my $args = shift;
    
    my $timestamp = $args->{'timestamp'};
    my @array = CIF::Archive::Plugin::Feed->retrieve_from_sql(qq{
        reporttime < '$timestamp'
    });

    if($#array > -1){
        foreach (@array){
            warn 'removing: '.$_->uuid() if($::debug);
            $_->delete();
            
        }
        CIF::Archive::Plugin::Feed->dbi_commit() unless(CIF::Archive::Plugin::Feed->db_Main->{'AutoCommit'});
    }
}
    

1;
