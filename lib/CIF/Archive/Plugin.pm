package CIF::Archive::Plugin;
use base 'CIF::DBI';

use warnings;
use strict;

use Digest::SHA1 qw/sha1_hex/;

sub query {}

# sub tables are auto-defined by the plugin name
# eg: Domain::Phishing translates to:
# domain_phishing
sub sub_table {
    my $class = shift;
    my $plug = shift;
    
    $plug =~ m/Plugin::(\S+)::(\S+)$/;
    my ($type,$subtype) = (lc($1),lc($2));
    return $type.'_'.$subtype;
}
    
sub insert_hash {
    my $class = shift;
    my $data = shift;
    my $thing = shift;
    
    my $confidence = 50;
    my $id = CIF::Archive::Plugin::Hash->insert({
        uuid        => $data->{'uuid'},
        guid        => $data->{'guid'},
        confidence  => $confidence,
        hash        => $data->{'hash'},
    });
    return ($id);
}

sub iodef_assessments {
    my $class = shift;
    my $iodef = shift;

    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        push (@array,@{$i->get_Assessment()});
    }
    return(\@array);
}

sub iodef_impacts {
    my $class = shift;
    my $iodef = shift;
    
    my $assessments = $class->iodef_assessments($iodef);
    my @array;
    foreach my $a (@$assessments){
        push(@array,@{$a->get_Impact()});
    }
    return(\@array);
}

sub iodef_impacts_first {
    my $class = shift;
    my $iodef = shift;
    
    my $impacts = $class->iodef_impacts($iodef);
    my $impact = @{$impacts}[0]->get_content()->get_content();
    return($impact);
}

sub iodef_event_additional_data {
    my $class = shift;
    my $iodef = shift;
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        foreach my $e (@{$i->get_EventData()}){
            my @additional_data = (ref($e->get_AdditionalData()) eq 'ARRAY') ? @{e->get_AdditionalData()} : $e->get_AdditionalData();
            push(@array,@additional_data);
        }
    }
    return(\@array);
}

sub iodef_addresses {
    my $class = shift;
    my $iodef = shift;
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        foreach my $e (@{$i->get_EventData()}){
            my @flows = (ref($e->get_Flow()) eq 'ARRAY') ? @{$e->get_Flow()} : $e->get_Flow();
            foreach my $f (@flows){
                my @systems = (ref($f->get_System()) eq 'ARRAY') ? @{$f->get_System()} : $f->get_System();
                foreach my $s (@systems){
                    my @nodes = (ref($s->get_Node()) eq 'ARRAY') ? @{$s->get_Node()} : $s->get_Node();
                    foreach my $n (@nodes){
                        my $addresses = $n->get_Address();
                        $addresses = [$addresses] if(ref($addresses) eq 'AddressType');
                        push(@array,@$addresses);
                    }
                }
            }
        }
    }
    return(\@array);
}

sub iodef_systems {
    my $class = shift;
    my $iodef = shift;
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        foreach my $e (@{$i->get_EventData()}){
            my @flows = (ref($e->get_Flow()) eq 'ARRAY') ? @{$e->get_Flow()} : $e->get_Flow();
            foreach my $f (@flows){
                my @systems = (ref($f->get_System()) eq 'ARRAY') ? @{$f->get_System()} : $f->get_System();
                push(@array,@systems);
            }
        }
    }
    return(\@array);
}

sub iodef_systems_additional_data {
    my $class = shift;
    my $iodef = shift;
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        foreach my $e (@{$i->get_EventData()}){
            my @flows = (ref($e->get_Flow()) eq 'ARRAY') ? @{$e->get_Flow()} : $e->get_Flow();
            foreach my $f (@flows){
                my @systems = (ref($f->get_System()) eq 'ARRAY') ? @{$f->get_System()} : $f->get_System();
                foreach my $s (@systems){
                    my @additional_data = (ref($s->get_AdditionalData()) eq 'ARRAY') ? @{$s->get_AdditionalData()} : $s->get_AdditionalData();
                    push(@array,@additional_data);
                }
            }
        }
    }
    return(\@array);
}
1;