package CIF::Smrt::Plugin::Postprocessor::Carboncopy;
use base 'CIF::Smrt::Plugin::Postprocessor';

use strict;
use warnings;

use CIF qw/generate_uuid_random/;

sub process {
    my $class   = shift;
    my $smrt    = shift;
    my $data    = shift;
    
    ## TODO -- check this
    return unless($data && $data->get_Incident());
   
    my $new_ids;
    foreach my $i (@{$data->get_Incident()}){
        next unless($i->get_Contact());
        my $restriction = $i->get_restriction();
        my @contacts = (ref($i->get_Contact()) eq 'ARRAY') ? @{$i->get_Contact()} : $i->get_Contact();
        my $altids;
        # we assume the first contact is the point of origin, although i dunno that we need it?
        # long as we have the AltID?
        foreach my $c (1 ... $#contacts){
            next unless($contacts[$c]->get_role() == ContactType::ContactRole::Contact_role_cc());
            my $restriction = $contacts[$c]->get_restriction();
            
            my $new_id = IncidentIDType->new({
                content     => generate_uuid_random(),
                instance    => $smrt->get_instance(),
                name        => $smrt->get_name(),
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
            push(@$new_ids,@{$new->get_Incident()}[0]);
            
            push(@$altids, AlternativeIDType->new({
                restriction => $restriction,
                IncidentID  => $new_id
            }));           
        }
        ## TODO -- check this
        push(@{$i->get_AlternativeID()},@$altids) if($altids);
    }
    return($new_ids);
}
1;