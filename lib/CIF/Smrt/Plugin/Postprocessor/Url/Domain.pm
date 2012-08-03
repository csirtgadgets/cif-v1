package CIF::Smrt::Plugin::Postprocessor::Url::Domain;
use base 'CIF::Smrt::Plugin::Postprocessor::Url';


use strict;
use warnings;

use CIF qw/generate_uuid_random/;
use Regexp::Common qw/net/;
use Iodef::Pb ':all';

my @postprocessors = CIF::Smrt->plugins();
@postprocessors = grep(/Postprocessor::[0-9a-zA-Z_]+$/,@postprocessors);

sub process {
    my $class   = shift;
    my $smrt    = shift;
    my $data    = shift;
    
    my @new_incidents;
    foreach my $i (@{$data->get_Incident()}){
        next unless($i->get_purpose && $i->get_purpose == IncidentType::IncidentPurpose::Incident_purpose_mitigation());
        next unless($i->get_EventData());
        my $description = $i->get_Description();
        my $restriction = $i->get_restriction();
        my $assessment = $i->get_Assessment();
        my $confidence = @{$assessment}[0]->get_Confidence();
        $confidence = $confidence->get_content();
        $confidence = $class->degrade_confidence($confidence);
        my $impact = iodef_impacts_first($data);
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
                            next unless($class->is_url($addr));
                            $addr = $addr->get_content();
                            my $port;
                            if($addr =~ /^(https?:\/\/)?([a-z0-9-.]+\.[a-z]{2,6})(:\d+)?(\/)?/){
                                $addr = $2;
                            } elsif($addr =~ /^(https?\:\/\/)?($RE{'net'}{'IPv4'})(:\d+)?(\/)?/) {
                                $addr = $2;
                                $port = $3;
                            } else {
                                return;
                            }
                            $port =~ s/^:// if($port);
                            $port = 80 unless($port && ($port ne ''));
                            my $id = IncidentIDType->new({
                                content     => generate_uuid_random(),
                                instance    => $smrt->get_instance(),
                                name        => $smrt->get_name(),
                                restriction => $restriction,
                            });
                            my $new = Iodef::Pb::Simple->new({
                                purpose     => 'mitigation',
                                address     => $addr,
                                portlist    => $port,
                                protocol    => 6,
                                IncidentID  => $id,
                                assessment  => $impact->get_content(),
                                description => $description,
                                confidence  => $confidence,
                                AlternativeID   => $i->get_IncidentID(),
                                restriction     => $restriction,       
                            });
                            ## TODO -- these stack on eachother
                            foreach (@postprocessors){
                                $_->process($new);
                            }
                            push(@new_incidents,@{$new->get_Incident()});
                            my $altids = $i->get_AlternativeID();
                            push(@$altids, { IncidentID => $id });
                            $i->set_AlternativeID($altids);
                            
                        }
                    }
                }
            }
        }
    }
    push(@{$data->get_Incident()},@new_incidents) if($#new_incidents > -1);
}

1;