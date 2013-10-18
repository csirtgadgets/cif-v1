package CIF::Smrt::Plugin::Pull::Cif;

use strict;
use warnings;

use CIF;
use CIF::Client;
use Iodef::Pb::Simple;

sub pull {
    my $class   = shift;
    my $f       = shift;
    return unless($f->{'cif'} && $f->{'cif'} eq 'true');
    
    my ($err,$ret) = CIF::Client->new({
        config          => $f->{'config'} || $f->{'client_config'} || $ENV{'/home/cif/.cif'},
    }); 
    return($err) if($err);
    
    my $confidence = $f->{'confidence'} || 85;
    
    ($err,$ret) = $ret->search({
        query       => $f->{'feed'},
        confidence  => $confidence,
        nolog       => 1,
        no_decode   => 1,
    });
    return($err) if($err);
    # multiple...
      
    $ret = 'application/cif'."\n".join("\n",@$ret);
    
    return(undef,$ret); 
}

1;
