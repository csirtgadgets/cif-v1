package CIF::Archive::Plugin::Url;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Digest::SHA1 qw/sha1_hex/;

__PACKAGE__->table('url');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence detecttime created/);
__PACKAGE__->sequence('url_id_seq');

sub query { } # handled by hash lookup

sub insert {
    my $class = shift;
    my $data = shift;
 
    my $addresses = $class->iodef_addresses($data->{'data'});
    return unless(@$addresses);
    
    my $confidence = $class->iodef_confidence($data->{'data'});
    $confidence = @{$confidence}[0]->get_content();
    
    my @ids;
    foreach my $address (@$addresses){
        my $addr = lc($address->get_content());
        next unless($addr =~ /^(ftp|https?):\/\//);
        my $hash = $class->SUPER::generate_sha1($addr);
        my $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            hash        => $hash,
            confidence  => $confidence,
            
        });
        push(@ids,$id);
        $id = $class->insert_hash($data,$hash);
    }
    return(undef,\@ids);
}

1;