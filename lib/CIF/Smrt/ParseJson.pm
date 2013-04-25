package CIF::Smrt::ParseJson;

use JSON;

sub parse {
    my $f = shift;
    my $content = shift;

    my @feed        = @{from_json($content)};
    my @fields      = split(',',$f->{'fields'});
    my @fields_map  = split(',',$f->{'fields_map'});
    my @array;
    foreach my $a (@feed){
        foreach (0 ... $#fields_map){
            $a->{$fields_map[$_]} = lc($a->{$fields[$_]});
        }
        map { $a->{$_} = $f->{$_} } keys %$f;
        push(@array,$a);
    }
    return(\@array);
}

1;
