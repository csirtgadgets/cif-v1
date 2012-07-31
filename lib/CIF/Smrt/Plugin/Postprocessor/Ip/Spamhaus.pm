package CIF::Smrt::Plugin::Postprocessor::Ip::Spamhaus;
use base 'CIF::Smrt::Plugin::Postprocessor::Ip';

use strict;
use warnings;

use CIF qw/generate_uuid_random/;
use Regexp::Common qw/net/;
use Net::Abuse::Utils::Spamhaus qw(check_ip);
use Iodef::Pb qw(/iodef_impacts_first/);

sub process {
    my $class   = shift;
    my $config  = shift;
    my $data    = shift;
    
    my @new_ids;
    foreach my $i (@{$data->get_Incident()}){
        next unless($i->get_purpose && $i->get_purpose == IncidentType::IncidentPurpose::Incident_purpose_mitigation());
        next unless($i->get_EventData());
        
        my $restriction = $i->get_restriction();
        my $assessment = $i->get_Assessment();
        my $confidence = @{$assessment}[0]->get_Confidence();
        $confidence = $confidence->get_content();
        $confidence = $class->degrade_confidence($confidence);
        
        my $impact = iodef_impacts_first($data);
        return if($impact->get_content()->get_content() =~ /^scan/);
        
        my $altids = $i->get_AlternativeID();
        foreach my $e (@{$i->get_EventData()}){
            $restriction = $e->get_restriction() if($e->get_restriction());
            my @flows = (ref($e->get_Flow()) eq 'ARRAY') ? @{$e->get_Flow()} : $e->get_Flow();
            foreach my $f (@flows){
                my @systems = (ref($f->get_System()) eq 'ARRAY') ? @{$f->get_System()} : $f->get_System();
                foreach my $s (@systems){
                    my @nodes = (ref($s->get_Node()) eq 'ARRAY') ? @{$s->get_Node()} : $s->get_Node();
                    $restriction = $s->get_restriction() if($s->get_restriction());
                    foreach my $n (@nodes){
                        my $addresses = $n->get_Address();
                        $addresses = [$addresses] if(ref($addresses) eq 'AddressType');
                        foreach my $addr (@$addresses){
                            next unless($class->is_ipv4($addr));
                            my $ret = check_ip($addr->get_content(),2);
                            foreach my $rr (@$ret){
                                my $new_id = IncidentIDType->new({
                                    content     => generate_uuid_random(),
                                    instance    => $config->{'instance'},
                                    name        => $config->{'name'},
                                    restriction => $restriction,
                                });
                                my $asn = $class->resolve_bgp($addr);
                                my $new = Iodef::Pb::Simple->new({
                                    purpose     => 'traceback',
                                    address     => $addr,
                                    prefix      => $asn->{'prefix'},
                                    cc          => $asn->{'cc'},
                                    rir         => $asn->{'rir'},
                                    asn         => $asn->{'asn'},
                                    asn_desc    => $asn->{'asn_desc'},
                                    IncidentID  => $new_id,
                                    assessment  => $rr->{'assessment'},
                                    description => $rr->{'description'},
                                    confidence  => 95,
                                    restriction     => $restriction,
                                    RelatedActivity => [
                                        RelatedActivityType->new({
                                            IncidentID  => IncidentIDType->new({
                                                content     => 'http://www.spamhaus.org/query/bl?ip='.$addr,
                                                instance    => 'zen.spamhaus.org',
                                                name        => 'spamhaus.org',
                                                restriction => 'public',
                                            }),
                                        }),
                                        RelatedActivityType->new({
                                            IncidentID  => $i->get_IncidentID(),
                                            restrcition => $restriction,
                                        })
                                    ],
                                    Contact         => $i->get_Contact(),
                                    
                                });
                                push(@new_ids,@{$new->get_Incident()}[0]);
                                push(@$altids, RelatedActivityType->new({IncidentID => $new_id }));
                                
                            }
                        }
                    }
                }
            }
        }
        $i->set_RelatedActivity($altids);
    }
    push(@{$data->get_Incident()},@new_ids);
}

1;