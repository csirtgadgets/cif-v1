package CIF::Smrt::Plugin::Postprocessor::Fqdn::Spamhaus;
use base 'CIF::Smrt::Plugin::Postprocessor::Fqdn';

use strict;
use warnings;

use CIF qw/generate_uuid_random/;
use Net::Abuse::Utils::Spamhaus qw(check_fqdn);

sub process {
    my $class   = shift;
    my $smrt    = shift;
    my $data    = shift;

    my @new_ids;
    foreach my $i (@{$data->get_Incident()}){
        next unless($i->get_EventData());
        
        my $altids = $i->get_RelatedActivity();
        
        my $restriction = $i->get_restriction();
        my $assessment = $i->get_Assessment();
        
        my $confidence = @{$assessment}[0]->get_Confidence();
        $confidence = $confidence->get_content();
        $confidence = $class->degrade_confidence($confidence);
        
        my $guid;
        if(my $iad = $i->get_AdditionalData()){
            foreach (@$iad){
                next unless($_->get_meaning() =~ /^guid/);
                $guid = $_->get_content();
            }
        }
        
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
                            next unless($class->is_fqdn($addr));
                            my $ret = check_fqdn($addr->get_content(),2);
                            next unless($ret);
                            foreach my $r (@$ret){
                                my $id = IncidentIDType->new({
                                    content     => generate_uuid_random(),
                                    instance    => $smrt->get_instance(),
                                    name        => $smrt->get_name(),
                                    restriction => $restriction,
                                });
                                my $new = Iodef::Pb::Simple->new({
                                    address     => $addr->get_content(),
                                    IncidentID  => $id,
                                    assessment  => $r->{'assessment'},
                                    description => $r->{'description'},
                                    confidence  => 95,
                                    restriction     => $restriction,
                                    RelatedActivity => RelatedActivityType->new({
                                        IncidentID  => IncidentIDType->new({
                                            content     => 'http://www.spamhaus.org/query/dbl?domain='.$addr->get_content(),
                                            instance    => 'dbl.spamhaus.org',
                                            name        => 'spamhaus.org',
                                            restriction => RestrictionType::restriction_type_public(),
                                        }),
                                    }),
                                    Contact     => $i->get_Contact(),
                                    guid        => $guid,
                                    
                                });
                                push(@new_ids,@{$new->get_Incident()}[0]);
                                push(@$altids, RelatedActivityType->new({IncidentID => $id, restriction => $restriction }));
                                
                            }
                        }
                    }
                }
            }
        }
        $i->set_RelatedActivity($altids);
    }
    #push(@{$data->get_Incident()},@new_ids);
    return(\@new_ids);
}

1;
