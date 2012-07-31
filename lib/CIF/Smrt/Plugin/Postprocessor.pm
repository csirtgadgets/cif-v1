package CIF::Smrt::Plugin::Postprocessor;
use base 'CIF::Smrt';

use strict;
use warnings;

use CIF qw/generate_uuid_random generate_uuid_ns/;
use Iodef::Pb ':all';
use Net::Abuse::Utils qw(get_as_description get_asn_info);

sub process {}

sub degrade_confidence {
    my $class = shift;
    my $confidence = shift;
    
    for(lc($confidence)){
        if(/^\d+/){
            my $log = log($confidence) / log(500);
            $confidence = sprintf('%.3f',($confidence * $log));
            return($confidence);
        }
        if(/^high$/){
            return 'medium';
        }
        if(/^medium$/){
            return 'low';
        }
    }
}

sub resolve_bgp {
    my $class = shift;
    my $a = shift;
    return undef unless($a);
    
    # aggregate our cache, we could miss a more specific route, but unlikely
    ## TODO -- improve for ipv6
    my @bits = split(/\./,$a);
    $bits[$#bits] = '0/24';
    $a = join('.',@bits);
  
    my ($as,$network,$ccode,$rir,$date) = get_asn_info($a);
    my $as_desc;
    $as_desc = get_as_description($as) if($as);

    $as         = undef if($as && $as eq 'NA');
    $network    = undef if($network && $network eq 'NA');
    $ccode      = undef if($ccode && $ccode eq 'NA');
    $rir        = undef if($rir && $rir eq 'NA');
    $date       = undef if($date && $date eq 'NA');
    $as_desc    = undef if($as_desc && $as_desc eq 'NA');
    $a          = undef if($a eq '');
    
    return({
        asn         => $as,
        prefix      => $network,
        cc          => $ccode,
        date        => $date,
        asn_desc    => $as_desc,
        rir         => $rir,
    });
}

1;