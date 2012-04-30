package CIF;

use 5.008008;
use strict;
use warnings;

our $VERSION = '0.99_01';
$VERSION = eval $VERSION;

use DateTime::Format::DateParse;
use OSSP::uuid;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration   use CIF::Utils ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(is_uuid generate_uuid_random generate_uuid_url generate_uuid_hash normalize_timestamp generate_uuid_ns) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

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
    my $dt = shift;
    return $dt if($dt =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    if($dt && ref($dt) ne 'DateTime'){
        if($dt =~ /^\d+$/){
            if($dt =~ /^\d{8}$/){
                $dt.= 'T00:00:00Z';
                $dt = eval { DateTime::Format::DateParse->parse_datetime($dt) };
                unless($dt){
                    $dt = DateTime->from_epoch(epoch => time());
                }
            } else {
                $dt = DateTime->from_epoch(epoch => $dt);
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
    $dt = $dt->ymd().'T'.$dt->hms().'Z';
    return $dt;
}

=back
=cut


1;
__END__

=head1 SEE ALSO

 collectiveintel.net

=head1 AUTHOR

Wes Young, E<lt>wes@barely3am.comE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2011 by Wes Young (claimid.com/wesyoung)
 Copyright (C) 2011 by the Trustee's of Indiana University (www.iu.edu)
 Copyright (C) 2011 by the REN-ISAC (www.ren-isac.net)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut