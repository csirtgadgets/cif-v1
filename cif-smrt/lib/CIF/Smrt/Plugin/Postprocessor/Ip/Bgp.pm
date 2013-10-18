package CIF::Smrt::Plugin::Postprocessor::Ip::Bgp;
use base 'CIF::Smrt::Plugin::Postprocessor::Ip';

use warnings;
use strict;

use Iodef::Pb::Simple ':all';

sub process {
    my $self        = shift;
    my $smrt        = shift;
    my $data        = shift;
   
    foreach my $i (@{$data->get_Incident()}){
        my $systems = iodef_systems($i);
            
        foreach my $system (@$systems){
            my $nodes = (ref($system->get_Node()) eq 'ARRAY') ? $system->get_Node() : [ $system->get_Node() ];
            foreach my $node (@$nodes){
                my $addresses = (ref($node->get_Address()) eq 'ARRAY') ? $node->get_Address() : [ $node->get_Address() ];
                foreach my $addr (@$addresses){
                    next unless($self->is_ipv4($addr));
                    my $r = $self->resolve_bgp($addr->get_content());
                    
                    my @additional_data;
                    if($r->{'prefix'}){
                        push(@additional_data,ExtensionType->new({
                            dtype   => ExtensionType::DtypeType::dtype_type_string(),
                            meaning => 'prefix',
                            content => $r->{'prefix'},
                        }));
                    }
                    if($r->{'asn'}){
                    push(@additional_data,ExtensionType->new({
                        dtype   => ExtensionType::DtypeType::dtype_type_string(),
                        meaning => 'asn',
                        content => $r->{'asn'},
                    }));
                    }
                
                    if($r->{'asn_desc'}){
                        push(@additional_data,ExtensionType->new({
                            dtype   => ExtensionType::DtypeType::dtype_type_string(),
                            meaning => 'asn_desc',
                            content => $r->{'asn_desc'},
                        }));
                    }
                    
                    if($r->{'cc'}){
                        push(@additional_data,
                            ExtensionType->new({
                                dtype   => ExtensionType::DtypeType::dtype_type_string(),
                                meaning => 'cc',
                                content => uc($r->{'cc'}),
                            })
                        );
                    }
                    
                    if($r->{'rir'}){
                        push(@additional_data,
                            ExtensionType->new({
                                dtype   => ExtensionType::DtypeType::dtype_type_string(),
                                meaning => 'rir',
                                content => uc($r->{'rir'}),
                            })
                        );
                    }
                    
                    next unless($#additional_data > -1);
                    if($system->get_AdditionalData()){
                        push(@{$system->get_AdditionalData()},@additional_data);
                    } else {
                        $system->set_AdditionalData(\@additional_data);
                    }
                }
            }
        }
    }
}

1;