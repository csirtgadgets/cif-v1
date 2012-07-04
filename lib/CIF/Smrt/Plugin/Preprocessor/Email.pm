package CIF::Smrt::Plugin::Preprocessor::Email;

use strict;
use warnings;

sub process {
    my $class = shift;
    my $rules = shift;
    my $rec = shift;
    
    my $address = $rec->{'address'};    
    return $rec unless($address);
    
    # Regexp::Common qw/URI/ chokes on large urls
    return $rec if($address =~ /^(ftp|https?):\/\//);
   
    if($address =~ /([a-z0-9_.-]+\@[a-z0-9.-]+\.[a-z0-9.-]{2,6})/){
        $rec->{'address'} = $1;
    }
      
    return $rec;
}

1;
