package CIF::Archive;
use base 'CIF::DBI';

# to make jeff teh happies!
use Try::Tiny;

use MIME::Base64;
use OSSP::uuid;
require Iodef::Pb;

require 5.008;
use strict;
use warnings;

use Module::Pluggable require => 1, except => qr/::Plugin::\S+::/;
use CIF::Utils qw/generate_uuid_url generate_uuid_random is_uuid/;

__PACKAGE__->table('archive');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid data created/);
__PACKAGE__->columns(Essential => qw/id uuid guid data created/);
__PACKAGE__->sequence('archive_id_seq');

my @plugins = __PACKAGE__->plugins();

sub insert {
    my $class = shift;
    my $data = shift;
    
    my $id;
    
    $data->{'uuid'}     = generate_uuid_random() unless($data->{'uuid'});
    $data->{'guid'}     = generate_uuid_url('root') unless($data->{'guid'});
    $data->{'created'}  = DateTime->from_epoch(epoch => time()) unless($data->{'created'});
    
    try {
        $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            data        => encode_base64($data->{'data'}),
            created     => $data->{'created'},
        });
    }
    catch {
        my $err = shift;
        return($err,undef);
    };
    
    $data->{'data'} = IODEFDocumentType->decode($data->{'data'});
    foreach my $p (@plugins){
        my ($pid,$err);
        try {
            ($err,$pid) = $p->insert($data);
        } catch {
            $err = shift;
            return($err,undef);
        };
    }
    return(undef,$data->{'uuid'});
}

sub query {
    my $class = shift;
    my $data = shift;
    
    # just in case someone gets stupid
    $data->{'limit'}        = 1000 unless($data->{'limit'});
    $data->{'confidence'}   = 0 unless(defined($data->{'confidence'}));
    $data->{'decode'}       = 1 unless(defined($data->{'decode'}) && $data->{'decode'} == 0);
    $data->{'query'}        = lc($data->{'query'});
 
    my $ret;
    if(is_uuid($data->{'query'})){
        # TODO -- finish
    } else {
        # log the query first
        $class->log_query($data) unless($data->{'nolog'});
        
        foreach my $p (@plugins){
            try {
                $ret = $p->query($data);
            } catch {
                my $err = shift;
                return($err);
            };
            last if(defined($ret));
        }
    }
    return(undef,undef) unless($ret);
    my @recs = (ref($ret) ne 'CIF::Archive') ? reverse($ret->slice(0,$ret->count())) : @$ret;
    my @rr;
    foreach (@recs){
        # protect against orphans
        next unless($_->{'data'});
        if($data->{'decode'}){
            push(@rr,decode_base64($_->{'data'}));
        } else {
            push(@rr,$_->{'data'});
        }
    }
    return(undef,\@rr);
}

sub log_query {
    my $class = shift;
    my $data = shift;
    
    my $q           = lc($data->{'query'});
    my $source      = $data->{'source'}         || 'unknown';
    my $confidence  = $data->{'confidence'}     || 50;
    my $restriction = $data->{'restriction'}    || 'private';
    my $guid        = $data->{'guid'}           || 'root';
    
    my $dt          = DateTime->from_epoch(epoch => time());
        
    $source = generate_uuid_url($source);
    $guid   = generate_uuid_url($guid);
    
    my $id;
    my $q_type = 'address';
    for($q){
        if(/^[a-f0-9]{32}$/){
            $q_type = 'md5';
            last;
        }
        if(/^[a-f0-9]{40}$/){
            $q_type = 'sha1';
            last;
        }
    }
    
    # thread friendly to load here
    require Iodef::Pb::Simple;
    my $doc = Iodef::Pb::Simple->new({
        description => 'search '.$q,
        assessment  => AssessmentType->new({
            Impact  => ImpactType->new({
                lang    => 'EN',
                content => MLStringType->new({
                    content => 'search '.$q,
                    lang    => 'EN',
                }),
            }),
        }),
        $q_type     => $q,
        confidence  => $confidence,
    });
    
    try {
        $id = $class->SUPER::insert({
            uuid    => generate_uuid_random(),
            guid    => $guid,
            data    => encode_base64($doc->encode()),
            created => $dt,
        });
    } catch {
        my $err = shift;
        $class->dbi_rollback() unless($class->db_Main->{'AutoCommit'});
        return($err);
    };
    
    $class->dbi_commit() unless($class->db_Main->{'AutoCommit'});
    return(undef,$id);
}

sub prune {}




1;