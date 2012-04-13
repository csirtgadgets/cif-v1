package CIF::Smrt::Plugin::Processor::Uri;

use strict;

use Digest::SHA1 qw/sha1_hex/;
use Digest::MD5 qw/md5_hex/;
use Regexp::Common qw/URI/;
use URI::Escape;

sub process {
    my $class = shift;
    my $rec = shift;

    return $rec unless($rec->{'address'});
    return $rec unless($rec->{'impact'});
    return $rec unless($rec->{'impact'} =~ /url$/);

    if($rec->{'address'} !~ /^(http|https|ftp):\/\//){
        if($rec->{'address'} =~ /[\/]+/){
            $rec->{'address'} = 'http://'.$rec->{'address'};
        }
    }

    if($rec->{'address'} && $rec->{'address'} =~ /^$RE{'URI'}/){
        # we do this here so ::Plugin::Hash will pick it up
        $rec->{'address'} = uri_escape($rec->{'address'},'\x00-\x1f\x7f-\xff');
        $rec->{'address'} = lc($rec->{'address'});
        $rec->{'md5'} = md5_hex($rec->{'address'});
        $rec->{'sha1'} = sha1_hex($rec->{'address'});
    }

    return($rec);
}

1;
