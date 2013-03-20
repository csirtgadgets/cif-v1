package CIF::Smrt::ParsePbIodef;

use Iodef::Pb::Simple;
use MIME::Base64;
use Compress::Snappy;

sub parse {
    my $f = shift;
    my $content = shift;
    
    # as internally defined by rt-cifminimal for now
    return unless($content =~ /^application\/base64\+snappy\+pb\+iodef\n([\S\n]+)\n$/);
    
    my @blobs = split(/\n\n/,$1);
    @blobs = map { IODEFDocumentType->decode(decompress(decode_base64($_))) } @blobs;
    
    @blobs = @{Iodef::Pb::Format->new({
        data    => \@blobs,
        format  => 'Raw',
    })};
      
    foreach my $r (@blobs){
        foreach $rr (@$h){
            # work-around for 'active lists'
            if($f->{'refresh'}){
                # this will get reset in the sort
               delete($rr->{'reporttime'});
            }
        }
    }

    return(\@blobs);
}

1;
