package CIF::Smrt::Plugin::Postprocessor::Carboncopy;
use base 'CIF::Smrt::Plugin::Postprocessor';

use strict;
use warnings;

use CIF qw/generate_uuid_random/;

sub process {
    my $class   = shift;
    my $config  = shift;
    my $data    = shift;
  
    return;    
    my @new_ids;
    foreach my $i (@{$data->get_Incident()}){
        next unless($i->get_purpose && $i->get_purpose == IncidentType::IncidentPurpose::Incident_purpose_mitigation());
        next unless($i->get_Contact());
        my $restriction = $i->get_restriction();
        my @contacts = (ref($i->get_Contact()) eq 'ARRAY') ? @{$i->get_Contact()} : $i->get_Contact();
        if(my $ad = $i->get_AdditionalData()){
            foreach my $d (@{$ad}){
                next unless($d->get_meaning() eq 'cc_restriction');
                $restriction = $d->get_content();
                if($restriction =~ /^(private|public|default|need-to-know)$/){
                    $restriction = eval "RestrictionType::restriction_type_$restriction()";
                }
            }
        }
        my $altids = $i->get_AlternativeID();
        foreach my $c (1 ... $#contacts){
            next unless($contacts[$c]->get_role() == ContactType::ContactRole::Contact_role_cc());
            
            my $new_id = IncidentIDType->new({
                content     => generate_uuid_random(),
                instance    => $config->{'instance'},
                name        => $config->{'name'},
                restriction => $restriction,
            });
            my $new = Iodef::Pb::Simple->new({
                IncidentID      => $new_id,
                EventData       => @{$i->get_EventData()},
                AlternativeID   => AlternativeIDType->new({
                    IncidentID  => $i->get_IncidentID(),
                    restriction => $restriction,
                }),
                restriction     => $restriction,
                ## TODO -- fix this [0] stuff
                ## should priority filter creator, admin, irt, etc..
                ## for now we'll just assume the first contact is the traceback contact
                Contact         => $contacts[0],
                detecttime      => $i->get_DetectTime(),
                Assessment      => @{$i->get_Assessment()},
            });
            push(@new_ids,@{$new->get_Incident()}[0]);
            
            push(@$altids, AlternativeIDType->new({
                restriction => $restriction,
                IncidentID  => $new_id
            }));           
        }
        $i->set_AlternativeID($altids);
    }
    push(@{$data->get_Incident()},@new_ids) if($#new_ids > -1);
}
1;