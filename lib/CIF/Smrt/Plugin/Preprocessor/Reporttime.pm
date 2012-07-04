package CIF::Smrt::Plugin::Processor::Reporttime;

sub process {
    my $class   = shift;
    my $rules   = shift;
    my $rec     = shift;

    my $dt = $rec->{'reporttime'};
    if($dt){
        $rec->{'reporttime'} = CIF::Smrt::normalize_timestamp($rec->{'reporttime'});
        return $rec;
    }
    
    $dt = DateTime->from_epoch(epoch => time());
    $rec->{'reporttime'} = $dt->ymd().'T'.$dt->hms().'Z';
    
    return $rec;
}

1;