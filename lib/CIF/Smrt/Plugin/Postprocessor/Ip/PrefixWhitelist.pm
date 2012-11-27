package CIF::Smrt::Plugin::Postprocessor::Ip::PrefixWhitelist;
use base 'CIF::Smrt::Plugin::Postprocessor::Ip';

use strict;
use warnings;

use CIF qw/generate_uuid_random/;
use Regexp::Common qw/net/;
use Iodef::Pb::Simple ':all';

sub process {
    my $class   = shift;
    my $smrt    = shift;
    my $data    = shift;
    
    my @new_ids;
    foreach my $i (@{$data->get_Incident()}){
        next unless($i->get_EventData());
              
        my $impact = iodef_impacts_first($i);
        ## TODO -- this is a work-around
        return unless($impact->get_content()->get_content() =~ /^whitelist$/);
        
        my $assessment = $i->get_Assessment();
        my $confidence = @{$assessment}[0]->get_Confidence();
        $confidence = $confidence->get_content();
        $confidence = $class->degrade_confidence($confidence);
        
        next unless($confidence > 25);
        
        my $restriction = $i->get_restriction();
        my $description = $i->get_Description->get_content();
        
        my $altids = $i->get_RelatedActivity();
        my $bgp = iodef_bgp($i) || next();
        foreach (@$bgp){
            next unless($_->{'prefix'});
            my $new_id = IncidentIDType->new({
                content     => generate_uuid_random(),
                instance    => $smrt->get_instance(),
                name        => $smrt->get_name(),
                restriction => $restriction,
            });
            my $new = Iodef::Pb::Simple->new({
                address     => $_->{'prefix'},
                prefix      => $_->{'prefix'},
                cc          => $_->{'cc'},
                rir         => $_->{'rir'},
                asn         => $_->{'asn'},
                asn_desc    => $_->{'asn_desc'},
                IncidentID  => $new_id,
                assessment  => 'whitelist',
                description => $description.' prefix',
                confidence  => $confidence,
                restriction     => $restriction,
                RelatedActivity => RelatedActivityType->new({
                        IncidentID  => $i->get_IncidentID(),
                        restrcition => $restriction,
                }),
                guid            => iodef_guid($i),
                
            });
            push(@new_ids,@{$new->get_Incident()}[0]);
            push(@$altids, RelatedActivityType->new({IncidentID => $new_id }));
        }
        $i->set_RelatedActivity($altids) if($altids);
    }
    return(\@new_ids);
}

1;