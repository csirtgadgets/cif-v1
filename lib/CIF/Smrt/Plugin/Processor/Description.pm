package CIF::Smrt::Plugin::Processor::Description;

sub process {
    my $class = shift;
    my $rec = shift;

    $rec->{'impact'} = lc($rec->{'impact'});
    unless($rec->{'description'}){
        $rec->{'description'} = $rec->{'impact'};
    }
    $rec->{'description'} = lc($rec->{'description'});
    return($rec);
}

1;
