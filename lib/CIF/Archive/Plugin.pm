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

sub generate_sha1 {
    my $self    = shift;
    my $thing   = shift || return;
    
    return $thing if(lc($thing) =~ /^[a-f0-9]{40}$/);
    return sha1_hex($thing);
}

sub test_feed {
    my $class = shift;
    my $data = shift;
    my $feeds = $data->{'feeds'};
        
    return unless($feeds);
    $feeds = [$feeds] unless(ref($feeds) eq 'ARRAY');
    return unless(@$feeds);
    foreach my $f (@$feeds){
        return 1 if(lc($class) =~ /$f$/);
    }
}
    
sub insert_hash {
    my $class = shift;
    my $data = shift;
    my $hash = shift;
    
    $hash = sha1_hex($hash) unless($hash =~ /^[a-f0-9]{40}$/);
    
    my $id = CIF::Archive::Plugin::Hash->insert({
        uuid        => $data->{'uuid'},
        guid        => $data->{'guid'},
        confidence  => $data->{'confidence'},
        hash        => $hash,
    });
    return ($id);
}

sub iodef_descriptions {
    my $class = shift;
    my $iodef = shift;
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        my $desc = $i->get_Description();
        $desc = [$desc] unless(ref($desc) eq 'ARRAY');
        push(@array,@$desc);
    }
    return(\@array);
}

sub iodef_assessments {
    my $class = shift;
    my $iodef = shift;
    
    return [] unless(ref($iodef) eq 'IODEFDocumentType');

    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        push (@array,@{$i->get_Assessment()});
    }
    return(\@array);
}

sub iodef_confidence {
    my $class = shift;
    my $iodef = shift;
    
    my $ret = $class->iodef_assessments($iodef);
    my @array;
    foreach my $a (@$ret){
        push(@array,$a->get_Confidence());
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

sub iodef_additional_data {
    my $class = shift;
    my $iodef = shift;
    
    return [] unless(ref($iodef) eq 'IODEFDocumentType');
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        my @additional_data = (ref($i->get_AdditionalData()) eq 'ARRAY') ? @{$i->get_AdditionalData()} : $i->get_AdditionalData();
        push(@array,@additional_data);
    }
    return(\@array);
}

sub iodef_event_additional_data {
    my $class = shift;
    my $iodef = shift;
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        next unless($i->get_EventData());
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
    
    return [] unless(ref($iodef) eq 'IODEFDocumentType');
        
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        next unless($i->get_EventData());
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

sub iodef_services {
    my $class = shift;
    my $iodef = shift;
    
    my @array;
    foreach my $i (@{$iodef->get_Incident()}){
        next unless($i->get_EventData());
        foreach my $e (@{$i->get_EventData()}){
            my @flows = (ref($e->get_Flow()) eq 'ARRAY') ? @{$e->get_Flow()} : $e->get_Flow();
            foreach my $f (@flows){
                my @systems = (ref($f->get_System()) eq 'ARRAY') ? @{$f->get_System()} : $f->get_System();
                foreach my $s (@systems){
                    my $services = $s->get_Service();
                    $services = [$services] unless(ref($services) eq 'ARRAY');
                    foreach my $svc (@$services){
                        $svc = [$svc] unless(ref($svc) eq 'ARRAY');
                        push(@array,@$svc);
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
        next unless($i->get_EventData());
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
        next unless($i->get_EventData());
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