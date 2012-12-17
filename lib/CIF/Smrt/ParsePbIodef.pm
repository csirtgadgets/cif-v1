package CIF::Smrt::ParsePbIodef;

use Iodef::Pb::Simple;
use Iodef::Pb::Format;
use MIME::Base64;
use Compress::Snappy;

sub parse {
    my $f = shift;
    my $content = shift;
    
    # as internally defined by rt-cifminimal for now
    return unless($content =~ /^application\/base64\+snappy\+pb\+iodef\n([\S\n]+)\n$/);
    
    # this whole thing is stupid, it'll suck-less, later... maybe.
    # when i'm a millionaire, i'll fix it.
    my @blobs = split(/\n\n/,$1);
    @blobs = map { IODEFDocumentType->decode(decompress(decode_base64($_))) } @blobs;
    
    @blobs = @{Iodef::Pb::Format->new({
        data    => \@blobs,
        format  => 'Raw',
    })};
    
    foreach my $r (@blobs){
        foreach $rr (@$h){
            if($f->{'detection'}){
                delete($rr->{'detecttime'});
                $rr->{'detection'} = $f->{'detection'};
            }
        }
    }
    return(\@blobs);
}

1;
