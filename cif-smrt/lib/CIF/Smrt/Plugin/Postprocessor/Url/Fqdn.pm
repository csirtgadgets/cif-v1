package CIF::Smrt::Plugin::Postprocessor::Url::Fqdn;
use base 'CIF::Smrt::Plugin::Postprocessor::Url';

use strict;
use warnings;

use CIF qw/generate_uuid_random/;
use Regexp::Common qw/net/;
use Iodef::Pb::Simple ':all';

my @postprocessors = CIF::Smrt->plugins();
@postprocessors = grep(/Postprocessor::[0-9a-zA-Z_]+$/,@postprocessors);

sub process {
    my $class   = shift;
    my $smrt    = shift;
    my $data    = shift;
    
    ## TODO -- FIX!
    my @new_incidents;
    foreach my $i (@{$data->get_Incident()}){
        next unless($i->get_purpose && $i->get_purpose == IncidentType::IncidentPurpose::Incident_purpose_mitigation());
        next unless($i->get_EventData());
        my $description = @{$i->get_Description()}[0]->get_content();
        my $restriction = $i->get_restriction();
        my $assessment = $i->get_Assessment();
        my $confidence = @{$assessment}[0]->get_Confidence();
        $confidence = $confidence->get_content();
        $confidence = $class->degrade_confidence($confidence);
        my $impact = iodef_impacts_first($i);
        $impact = $impact->get_content->get_content();
        
        my $guid;
        if(my $iad = $i->get_AdditionalData()){
            foreach (@$iad){
                next unless($_->get_meaning() =~ /^guid/);
                $guid = $_->get_content();
            }
        }
        
        my $rids = $i->get_RelatedActivity();
        $rids = $rids->get_IncidentID() if($rids);
        
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
                                address     => $addr,
                                portlist    => $port,
                                protocol    => 6,
                                IncidentID  => $id,
                                assessment  => $impact,
                                description => $description,
                                confidence  => $confidence,
                                RelatedActivity   => RelatedActivityType->new({
                                    IncidentID  => [ $i->get_IncidentID() ],
                                    restriction => $restriction,
                                }),
                                restriction     => $restriction,
                                guid            => $guid, 
                                AlternativeID   => $i->get_AlternativeID(),
                            });
                            foreach (@postprocessors){
                                my $ret = $_->process($smrt,$new);
                                push(@new_incidents,@$ret) if($ret);
                            }
                            push(@new_incidents,@{$new->get_Incident()});
                            push(@$rids,$id);
                            
                        }
                    }
                }
            }
        }
        if($rids){
            $i->set_RelatedActivity(
                RelatedActivityType->new({
                    IncidentID  => $rids,
                })
            );
        }
    }
    return(\@new_incidents);
}

1;