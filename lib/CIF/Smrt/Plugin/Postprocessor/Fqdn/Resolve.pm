package CIF::Smrt::Plugin::Postprocessor::Fqdn::Resolve;
use base 'CIF::Smrt::Plugin::Postprocessor::Fqdn';

use strict;
use warnings;

use CIF qw(generate_uuid_random);
use Iodef::Pb ':all';

my @postprocessors = CIF::Smrt->plugins();
@postprocessors = grep(/Postprocessor::[0-9a-zA-Z_]+$/,@postprocessors);

sub process {
    my $class   = shift;
    my $config  = shift;
    my $data    = shift;
 
    my @alt_ids;
    my @new_incidents;
    
    foreach my $i (@{$data->get_Incident()}){
        next unless($i->get_purpose && $i->get_purpose == IncidentType::IncidentPurpose::Incident_purpose_mitigation());
        next unless($i->get_EventData());
        my $restriction = $i->get_restriction();
        my $assessment = $i->get_Assessment();
        my $impact = iodef_impacts_first($data);
        my $description = $i->get_Description->get_content();
        my $confidence = @{$assessment}[0]->get_Confidence();
        $confidence = $confidence->get_content();
        $confidence = $class->degrade_confidence($confidence);
        foreach my $e (@{$i->get_EventData()}){
            $restriction = $e->get_restriction() if($e->get_restriction());
            my @flows = (ref($e->get_Flow()) eq 'ARRAY') ? @{$e->get_Flow()} : $e->get_Flow();
            foreach my $f (@flows){
                my @systems = (ref($f->get_System()) eq 'ARRAY') ? @{$f->get_System()} : $f->get_System();
                foreach my $s (@systems){
                    my @nodes = (ref($s->get_Node()) eq 'ARRAY') ? @{$s->get_Node()} : $s->get_Node();
                    $restriction = $s->get_restriction() if($s->get_restriction());
                    my @additional_data;
                    foreach my $n (@nodes){
                        my $addresses = $n->get_Address();
                        $addresses = [$addresses] if(ref($addresses) eq 'AddressType');
                        foreach my $addr (@$addresses){
                            next unless($class->is_fqdn($addr));
                            
                            my $ret = $class->resolve($addr->get_content());
                            foreach my $rr (@$ret){
                                ## TODO -- CNAME, etc...
                                next unless($rr->{'type'} eq 'A');
                                    
                                push(@additional_data,ExtensionType->new({
                                    dtype   => ExtensionType::DtypeType::dtype_type_string(),
                                    meaning => 'A',
                                    content => $rr->{'address'},
                                }));
                                
                                my $id = IncidentIDType->new({
                                    content     => generate_uuid_random(),
                                    instance    => $config->{'instance'},
                                    name        => $config->{'name'},
                                    restriction => $restriction,
                                });
                                my $new = Iodef::Pb::Simple->new({
                                    purpose         => 'traceback',
                                    description     => $description,
                                    address         => $rr->{'address'},
                                    IncidentID      => $id,
                                    assessment      => $impact->get_content(),
                                    confidence      => $confidence,
                                    RelatedActivity => RelatedActivityType->new({
                                        IncidentID  => $i->get_IncidentID(),
                                    }),
                                    restriction     => $restriction,
                                    
                                });
                                ## TODO -- these stack on eachother
                                foreach (@postprocessors){
                                    $_->process($new);
                                }
                                push(@new_incidents,@{$new->get_Incident()});
                                my $altids = $i->get_RelatedActivity();
                                push(@$altids, RelatedActivityType->new({IncidentID => $id }));
                                $i->set_RelatedActivity($altids);
                            }
                        }
                    }
                    next unless($#additional_data > -1);
                    if($s->get_AdditionalData()){
                        push(@{$s->get_AdditionalData()},@additional_data);
                    } else {
                        $s->set_AdditionalData(\@additional_data);
                    }
                }
            }
        }
    }
    push(@{$data->get_Incident()},@new_incidents) if($#new_incidents > -1);
}

1;