package CIF;

use 5.008008;
use strict;
use warnings;

our $VERSION = '1.0.2';

use DateTime::Format::DateParse;
use OSSP::uuid;
use CIF::Msg;
use CIF::Msg::Feed;
require Iodef::Pb::Simple;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration   use CIF::Utils ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
    is_uuid generate_uuid_random generate_uuid_url generate_uuid_hash 
    normalize_timestamp generate_uuid_ns debug init_logging to_feed
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

use vars qw($Logger);

=head1 NAME

CIF::Utils - Perl extension for misc 'helper' CIF like functions

=head1 SYNOPSIS

  use CIF::Utils;
  use Data::Dumper;

  my $dt = time()
  $dt = CIF::Utils::normalize_timestamp($dt);
  warn $dt;

  my $uuid = generate_uuid_random();
  my $uuid = generate_uuid_domain('example.com');
  my $uuid = generate_uuid_hash($source,$json_text);

=head1 DESCRIPTION
 
  These are mostly helper functions to be used within CIF::Archive. We did some extra work to better parse timestamps and provide some internal uuid, cpu throttling and thread-batching for various CIF functions.

=head1 Functions

=over

=item is_uuid($uuid)

  Returns 1 if the argument matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
  Returns 0 if it doesn't

=cut

sub is_uuid {
    my $arg = shift;
    return undef unless($arg && $arg =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    return(1);
}

=item debug($string)

  outputs debug information when called

=cut

## TODO -- clean this and init_logging up

sub debug {
    return unless($::debug);

    my $msg = shift;
    my ($pkg,$f,$line,$sub) = caller(1);
    
    unless($f){
        ($pkg,$f,$line) = caller();
    }
    
    $sub = '' unless($sub);
    my $ts = DateTime->from_epoch(epoch => time());
    $ts = $ts->ymd().'T'.$ts->hms().'Z';
    
    if($CIF::Logger){
         if($::debug > 5){
            $CIF::Logger->debug("[DEBUG][$ts][$f:$sub:$line]: $msg");
        } elsif($::debug > 1) {
            $CIF::Logger->debug("[DEBUG][$ts][$sub]: $msg");
        } else {
            $CIF::Logger->debug("[DEBUG][$ts]: $msg");
        }
    } else {
        if($::debug > 5){
            print("[DEBUG][$ts][$f:$sub:$line]: $msg\n");
        } elsif($::debug > 1) {
            print("[DEBUG][$ts][$sub]: $msg\n");
        } else {
            print("[DEBUG][$ts]: $msg\n");
        }
    }
}

sub init_logging {
    my $d = shift;
    return unless($d);
    
    $::debug = $d;
    require Log::Dispatch;
    unless($CIF::Logger){
        $CIF::Logger = Log::Dispatch->new();
        require Log::Dispatch::Screen;
        $CIF::Logger->add( 
            Log::Dispatch::Screen->new(
                name        => 'screen',
                min_level   => 'debug',
                stderr      => 1,
                newline     => 1
             )
        );
    }
}   

=item generate_uuid()

  generates a random "v4" uuid and returns it as a string

=cut

sub generate_uuid_random {
    my $uuid    = OSSP::uuid->new();
    $uuid->make('v4');
    my $str = $uuid->export('str');
    undef $uuid;
    return($str);
}

sub generate_uuid_ns {
    my $source = shift;
    my $uuid = OSSP::uuid->new();
    my $uuid_ns = OSSP::uuid->new();
    $uuid_ns->load('ns::URL');
    $uuid->make("v3",$uuid_ns,$source);
    my $str = $uuid->export('str');
    undef $uuid;
    return($str);
}

# deprecate
sub generate_uuid_url {
    return generate_uuid_ns(shift);
}

=item normalize_timestamp($ts)

  Takea in a timestamp (see DateTime::Format::DateParse), does a little extra normalizing and returns a DateTime object

=cut

sub normalize_timestamp {
    my $dt  = shift;
    my $now = shift || DateTime->from_epoch(epoch => time()); # better perf in loops if we can pass the default now value
    
    return DateTime::Format::DateParse->parse_datetime($dt) if($dt =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    
    # already epoch
    return DateTime->from_epoch(epoch => $dt) if($dt =~ /^\d{10}$/);
    
    # something else
    if($dt && ref($dt) ne 'DateTime'){
        if($dt =~ /^\d+$/){
            if($dt =~ /^\d{8}$/){
                $dt.= 'T00:00:00Z';
                $dt = eval { DateTime::Format::DateParse->parse_datetime($dt) };
                unless($dt){
                    $dt = $now;
                }
            } else {
                $dt = $now;
            }
        } elsif($dt =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\S+)?$/) {
            my ($year,$month,$day,$hour,$min,$sec,$tz) = ($1,$2,$3,$4,$5,$6,$7);
            $dt = DateTime::Format::DateParse->parse_datetime($year.'-'.$month.'-'.$day.' '.$hour.':'.$min.':'.$sec,$tz);
        } else {
            $dt =~ s/_/ /g;
            $dt = DateTime::Format::DateParse->parse_datetime($dt);
            return undef unless($dt);
        }
    }
    return $dt;
}

=back
=cut

sub to_feed {
    my $args = shift;
    
    my $data        = $args->{'data'};
    my $description = $args->{'description'}    || 'unknown';
    my $confidence  = $args->{'confidence'}     || 0;
    my $timestamp   = $args->{'timestamp'};
    my $guid        = $args->{'guid'}           || generate_uuid_ns('everyone');
    
    unless($timestamp){
        $timestamp = DateTime->from_epoch(epoch => time());
        $timestamp = $timestamp->ymd().'T'.$timestamp->hms().'Z';
    }
    
    my @feed;
    foreach (@$data){
        unless(ref($_) eq 'IODEFDocumentType'){
            $_ = { $_ } unless(ref($_) eq 'HASH');
            $_ = Iodef::Pb::Simple->new($_);
        }
        push(@feed,$_->encode());
    }
    
    my $f = FeedType->new({
        version         => $VERSION,
        confidence      => $confidence,
        description     => $description,
        ReportTime      => $timestamp,
        data            => \@feed,
        uuid            => generate_uuid_random(),
        guid            => $guid,
    });
    return $f->encode();
}
1;
