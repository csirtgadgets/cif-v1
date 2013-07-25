package CIF::Smrt::ParseCifFeed;

use Iodef::Pb::Format;
use CIF;
use MIME::Base64;
use Compress::Snappy;

sub parse {
    my $f       = shift;
    my $content = shift;

    return unless($content =~ /^application\/cif\n([\S\s]+)$/);
   
    # this could all be done a better way, and will be in the future
    
    my @array = split("\n\n",$1);
    my @return;

    foreach (@array){
        my $ret = decompress(decode_base64($1));
        
        $ret = FeedType->decode($ret);
        next unless($ret->get_data());
        
        my @blobs = @{$ret->get_data()};
        
        @blobs = map { IODEFDocumentType->decode(decompress(decode_base64($_))) } @blobs;
        
        @blobs = @{Iodef::Pb::Format->new({
            data    => \@blobs,
            format  => 'Raw',
        })};
        if($f->{'guid'}){
            foreach my $b (@blobs){
                $b->{'guid'} = $f->{'guid'};
            }
        }
        push(@return,@blobs); 
    }
    return(\@return);
}

1;
