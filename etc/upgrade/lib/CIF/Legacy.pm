package CIF::Legacy;

use Module::Pluggable search_path => ['CIF::Legacy'], require => 1;
require JSON::XS;

my @plugins = __PACKAGE__->plugins();

sub hash_simple {
    my $data = shift;
    my $uuid = shift;
    
    $data = JSON::XS::decode_json($data);
    
    $data = $data->{'Incident'};

    my $impact = $data->{'Assessment'}->{'Impact'};
    $impact = $data->{'Assessment'}->{'Impact'}->{'content'} if(ref($impact) eq 'HASH');
    my $h = {
        id                          => $uuid,
        relatedid                   => $data->{'RelatedActivity'}->{'IncidentID'},
        description                 => $data->{'Description'},
        assessment                  => $impact,
        severity                    => $data->{'Assessment'}->{'Impact'}->{'severity'},
        confidence                  => $data->{'Assessment'}->{'Confidence'}->{'content'},
        source                      => $data->{'IncidentID'}->{'name'},
        restriction                 => $data->{'restriction'},
        alternativeid               => $data->{'AlternativeID'}->{'IncidentID'}->{'content'},
        alternativeid_restriction   => $data->{'AlternativeID'}->{'IncidentID'}->{'restriction'},
        detecttime                  => $data->{'DetectTime'},
        reporttime                  => $data->{'ReportTime'} || $data->{'DetectTime'},
        purpose                     => $data->{'purpose'},
    };

    foreach my $p (@plugins){
        my $ret = $p->hash_simple($data);
        next unless($ret);
        map { $h->{$_} = $ret->{$_} } keys (%$ret);
    }
    return ($h);
}

sub _throttle {
    my $throttle = shift;

    require Linux::Cpuinfo;
    my $cpu = Linux::Cpuinfo->new();
    return(DEFAULT_THROTTLE_FACTOR()) unless($cpu);
    
    my $cores = $cpu->num_cpus();
    return(DEFAULT_THROTTLE_FACTOR()) unless($cores && $cores =~ /^\d+$/);
    return(DEFAULT_THROTTLE_FACTOR()) if($cores eq 1);
    
    return($cores * (DEFAULT_THROTTLE_FACTOR() * 2))  if($throttle eq 'high');
    return($cores * DEFAULT_THROTTLE_FACTOR())  if($throttle eq 'medium');
    return($cores / 2) if($throttle eq 'low');
}