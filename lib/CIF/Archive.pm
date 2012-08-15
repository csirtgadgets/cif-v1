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

use Module::Pluggable require => 1, except => qr/::Plugin::\S+::/;
use CIF qw/generate_uuid_url generate_uuid_random is_uuid generate_uuid_ns/;

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
        
    ## TODO -- adapt this to take in array references
    ## $data = [$data] unless(ref($data) eq 'ARRAY');

    my $id;
    
    $data->{'uuid'}     = generate_uuid_random()                    unless($data->{'uuid'});
    $data->{'guid'}     = generate_uuid_ns('root')                  unless($data->{'guid'});
    $data->{'created'}  = DateTime->from_epoch(epoch => time())     unless($data->{'created'});
        
    my $err;
    try {
        $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            format      => $data->{'format'},
            ## TODO -- move encode/compress to the client?
            #data        => encode_base64(Compress::Snappy::compress($data->{'data'}->encode())),
            data        => $data->{'data'},
            created     => $data->{'created'},
        });
    }
    catch {
        $err = shift;
        warn $err;
    };
    return($err,undef) if($err);
    
    ## TODO -- this is all gonna happen as an indexing correlation at some point
    ## router shouldn't be doing this.
    
    $data->{'data'} = Compress::Snappy::decompress(decode_base64($data->{'data'}));
    
    if($data->{'format'} && $data->{'format'} eq 'feed'){
        $data->{'data'} = FeedType->decode($data->{'data'});
    } else {
        $data->{'data'} = IODEFDocumentType->decode($data->{'data'});
    }
    
    foreach my $p (@plugins){
        my ($pid,$err);
        try {
            ($err,$pid) = $p->insert($data);
        } catch {
            $err = shift;
        };
        
        if($err){
            warn 'fail...';
            warn $err;
            $class->dbi_rollback() unless($class->db_Main->{'AutoCommit'});
            return($err,undef);
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
        # TODO -- finish
    } else {
        # log the query first
        unless($data->{'nolog'}){
            my ($err,$ret) = $class->log_search($data);
            return($err) if($err);
        }
        foreach my $p (@plugins){
            my $err;
            try {
                $ret = $p->query($data);
            } catch {
                $err = shift;
                warn $err if($::debug);
                warn $err;
            };
            return($err,undef) if($err);
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
    my $q_type = 'address';
    
    ## TODO: clean this up
    $q_type = 'hash' if($q =~ /^([a-f0-9]{40}|[a-f0-9]{32})$/);
   
    # thread friendly to load here
    ## TODO this could go in the client...?
    require Iodef::Pb::Simple;
    ## TODO -- have the client pass along a description
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
        $q_type     => $q,
        IncidentID          => IncidentIDType->new({
            content => generate_uuid_random(),
            name    => $source,
        }),
        detecttime  => $dt,
        reporttime  => $dt,
        restriction => $restriction,
        guid        => $guid,
        restriction => RestrictionType::restriction_type_private(),
    });
    
    my $err;
    try {
        $id = $class->insert({
            uuid    => generate_uuid_random(),
            guid    => $guid,
            data    => $doc,
            created => $dt,
            feeds   => $data->{'feeds'},
        });
    } catch {
        $err = shift;
        warn $err;
        $class->dbi_rollback() unless($class->db_Main->{'AutoCommit'});
    };
    warn $err if($err);
    return($err,undef) if($err);
    $class->dbi_commit() unless($class->db_Main->{'AutoCommit'});
    return(undef,$id);
}

sub prune {}

1;