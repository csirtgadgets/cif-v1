package CIF::Smrt::ParseJsonIodef;

use strict;
use warnings;

sub parse {
    my $f = shift;
    my $content = shift;

    require JSON;
    my $ret = JSON::from_json($content);
    require CIF::Client::Plugin::Iodef;
    my @array;
    foreach my $r (@$ret){
        my @a;
        my $h = CIF::Client::Plugin::Iodef->hash_simple($r);
        foreach my $rr (@$h){
            if($f->{'detection'}){
                delete($rr->{'detecttime'});
                $rr->{'detection'} = $f->{'detection'};
            }
            push(@a,$rr);
        }
        push(@array,@a);
    }
    return(\@array);
}

1;
