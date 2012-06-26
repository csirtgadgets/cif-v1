package CIF::Archive::Plugin::Url;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

my @plugins = __PACKAGE__->plugins();

__PACKAGE__->table('url');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence detecttime created/);
__PACKAGE__->sequence('url_id_seq');

sub query { } # handled by hash lookup

sub insert {
    my $class = shift;
    my $data = shift;
     
    return unless(ref($data->{'data'}) eq 'IODEFDocumentType');
     
    my $addresses = $class->iodef_addresses($data->{'data'});
    return unless(@$addresses);
    
    my $tbl = $class->table();
    foreach(@plugins){
        if($_->prepare($data)){
            $class->table($_->table());
        }
    }
    
    my $confidence = $class->iodef_confidence($data->{'data'});
    $confidence = @{$confidence}[0]->get_content();
    $data->{'confidence'} = $confidence;
    
    my @ids;
    foreach my $address (@$addresses){
        my $addr = lc($address->get_content());
        next unless($addr =~ /^(ftp|https?):\/\//);
        my $hash = $class->SUPER::generate_sha1($addr);
        if($class->test_feed($data)){
            $class->SUPER::insert({
                guid        => $data->{'guid'},
                uuid        => $data->{'uuid'},
                hash        => $hash,
                confidence  => $confidence,
            });
        }
        
        my $id = $class->insert_hash($data,$hash);
        push(@ids,$id);
    }
    $class->table($tbl);
    return(undef,\@ids);
}

1;