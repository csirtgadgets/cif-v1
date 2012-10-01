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
        foreach my $e (@{$i->get_EventData()}){
            $restriction = $e->get_restriction() if($e->get_restriction());
            my @flows = (ref($e->get_Flow()) eq 'ARRAY') ? @{$e->get_Flow()} : $e->get_Flow();
            foreach my $f (@flows){
                my @systems = (ref($f->get_System()) eq 'ARRAY') ? @{$f->get_System()} : $f->get_System();
                foreach my $s (@systems){
                    my @nodes = (ref($s->get_Node()) eq 'ARRAY') ? @{$s->get_Node()} : $s->get_Node();
                    $restriction = $s->get_restriction() if($s->get_restriction());
                    my $bgp = iodef_systems_bgp($s);
                    next unless($bgp->{'prefix'});
                    my $new_id = IncidentIDType->new({
                        content     => generate_uuid_random(),
                        instance    => $smrt->get_instance(),
                        name        => $smrt->get_name(),
                        restriction => $restriction,
                    });
                    my $new = Iodef::Pb::Simple->new({
                        address     => $bgp->{'prefix'},
                        prefix      => $bgp->{'prefix'},
                        cc          => $bgp->{'cc'},
                        rir         => $bgp->{'rir'},
                        asn         => $bgp->{'asn'},
                        asn_desc    => $bgp->{'asn_desc'},
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
            }
        }
        $i->set_RelatedActivity($altids) if($altids);
    }
    return(\@new_ids);
}

1;