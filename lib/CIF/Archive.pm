package CIF::Archive;
use base 'CIF::DBI';

require 5.008;
use strict;
use warnings;

# to make jeff teh happies!
use Try::Tiny;

use MIME::Base64;
require Iodef::Pb::Simple;
require Compress::Snappy;
use Digest::SHA1 qw/sha1_hex/;
use Data::Dumper;

use Module::Pluggable require => 1, except => qr/::Plugin::\S+::/;
use CIF qw/generate_uuid_url generate_uuid_random is_uuid generate_uuid_ns debug/;

__PACKAGE__->table('archive');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid data format reporttime created/);
__PACKAGE__->columns(Essential => qw/id uuid guid data created/);
__PACKAGE__->sequence('archive_id_seq');

my @plugins = __PACKAGE__->plugins();

our $root_uuid      = generate_uuid_ns('root');
our $everyone_uuid  = generate_uuid_ns('everyone');

sub insert {
    my $class = shift;
    my $data = shift;
        
    my $msg = Compress::Snappy::decompress(decode_base64($data->{'data'}));

    if($data->{'format'} && $data->{'format'} eq 'feed'){
        $msg = FeedType->decode($msg);
    } else {
        $msg = IODEFDocumentType->decode($msg);
        $data->{'uuid'}         = @{$msg->get_Incident}[0]->get_IncidentID->get_content();
        $data->{'reporttime'}   = @{$msg->get_Incident}[0]->get_ReportTime();
    }
    
    $data->{'uuid'} = generate_uuid_random() unless($data->{'uuid'});

    return ('id must be a uuid') unless(is_uuid($data->{'uuid'}));
    
    $data->{'guid'}     = generate_uuid_ns('root')                  unless($data->{'guid'});
    $data->{'created'}  = DateTime->from_epoch(epoch => time())     unless($data->{'created'});
   
    my ($err,$id);
    try {
        $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            format      => $CIF::VERSION,
            data        => $data->{'data'},
            created     => $data->{'created'},
            reporttime  => $data->{'reporttime'},
        });
    }
    catch {
        $err = shift;
    };
    return ($err) if($err);
    
    $data->{'data'} = $msg;    
    
    foreach my $p (@plugins){
        #debug($p);
        my ($pid,$err);
        try {
            ($err,$pid) = $p->insert($data);
        } catch {
            $err = shift;
        };
        if($err){
            $class->dbi_rollback() unless($class->db_Main->{'AutoCommit'});
            return $err;
        }
    }
    return(undef,$data->{'uuid'});
}

sub search {
    my $class = shift;
    my $data = shift;
      
    # just in case someone gets stupid
    ## TODO -- move to config??
    $data->{'limit'}        = 5000 unless($data->{'limit'});
    $data->{'confidence'}   = 0 unless(defined($data->{'confidence'}));
    $data->{'query'}        = lc($data->{'query'});
 
    my $ret;
    if(is_uuid($data->{'query'})){
        $ret = $class->SUPER::retrieve(uuid => $data->{'query'});
    } else {
        # log the query first
        debug('running query');
        unless($data->{'nolog'}){
            debug('logging search');
            my ($err,$ret) = $class->log_search($data);
            return($err) if($err);
        }
        foreach my $p (@plugins){
            my $err;
            debug('plugin: '.$p);
            try {
                $ret = $p->query($data);
            } catch {
                $err = shift;
            };
            if($err){
                warn $err;
                return($err);
            }
            last if(defined($ret));
        }
    }

    return unless($ret);
    my @recs = (ref($ret) ne 'CIF::Archive') ? reverse($ret->slice(0,$ret->count())) : ($ret);
    my @rr;
    foreach (@recs){
        # protect against orphans
        next unless($_->{'data'});
        if($data->{'decode'}){
            push(@rr,Compress::Snappy::decompress(decode_base64($_->{'data'})));
        } else {
            push(@rr,$_->{'data'});
        }
    }
    return(undef,\@rr);
}

sub log_search {
    my $class = shift;
    my $data = shift;
    
    my $q               = lc($data->{'query'});
    my $source          = $data->{'source'}         || 'unknown';
    my $confidence      = $data->{'confidence'}     || 50;
    my $restriction     = $data->{'restriction'}    || 'private';
    my $guid            = $data->{'guid'}           || $data->{'guid_default'} || $root_uuid;
    my $desc            = $data->{'description'}    || 'search';
    
    my $dt          = DateTime->from_epoch(epoch => time());
    $dt = $dt->ymd().'T'.$dt->hms().'Z';
    
    $source = generate_uuid_ns($source);
    
    my $id;
   
    my ($q_type,$q_thing);
    for(lc($desc)){
        # reg hashes
        if(/^search ([a-f0-9]{40}|[a-f0-9]{32})$/){
            $q_type = 'hash';
            $q_thing = $1;
            last;
        } 
        # asn
        if(/^search as(\d+)$/){
            $q_type = 'hash';
            $q_thing = sha1_hex($1); 
            last;
        } 
        # cc
        if(/^search ([a-z]{2})$/){
            $q_type = 'hash';
            $q_thing = sha1_hex($1);
            last;
        }
        m/^search (\S+)$/;
        $q_type = 'address',
        $q_thing = $1;
    }
   
    # thread friendly to load here
    ## TODO this could go in the client...?
    require Iodef::Pb::Simple;
    my $uuid = generate_uuid_random();
    
    my $doc = Iodef::Pb::Simple->new({
        description => $desc,
        assessment  => AssessmentType->new({
            Impact  => [
                ImpactType->new({
                    lang    => 'EN',
                    content => MLStringType->new({
                        content => 'search',
                        lang    => 'EN',
                    }),
                }),
            ],
            
            ## TODO -- change this to low|med|high
            Confidence  => ConfidenceType->new({
                content => $confidence,
                rating  => ConfidenceType::ConfidenceRating::Confidence_rating_numeric(),
            }),
        }),
        $q_type             => $q_thing,
        IncidentID          => IncidentIDType->new({
            content => $uuid,
            name    => $source,
        }),
        detecttime  => $dt,
        reporttime  => $dt,
        restriction => $restriction,
        guid        => $guid,
        restriction => RestrictionType::restriction_type_private(),
    });
   
    my $err;
    ($err,$id) = $class->insert({
        uuid        => $uuid,
        guid        => $guid,
        data        => encode_base64(Compress::Snappy::compress($doc->encode())),
        created     => $dt,
        feeds       => $data->{'feeds'},
        datatypes   => $data->{'datatypes'},
    });
    return($err) if($err);
    $class->dbi_commit() unless($class->db_Main->{'AutoCommit'});
    return(undef,$id);
}

1;