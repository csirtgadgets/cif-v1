package CIF::Smrt::ParsePbIodef;

use Iodef::Pb::Simple;

sub parse {
    my $f = shift;
    my $content = shift;
    
    return;
    
    my $ret = IODEFDocumentType->decode($content);
    
    return unless($ret);
    
    my $t = Iodef::Pb::Format->new({
        data                => $ret,
    });
    
    my @array;
    foreach my $r (@$ret){
        my @a;
        my $h = $t->to_keypair($r);
        foreach $rr (@$h){
            if($f->{'detection'}){
                delete($rr->{'detecttime'});
                $rr->{'detection'} = $f->{'detection'};
            }
            push(@a,$rr);
        }
        push(@array,@a);
    }
    die ::Dumper(@array);
    return(\@array);
}

1;
