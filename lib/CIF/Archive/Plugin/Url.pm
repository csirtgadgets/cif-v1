package CIF::Archive::Plugin::Url;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Regexp::Common qw/URI/;

__PACKAGE__->table('url');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid confidence detecttime created/);
__PACKAGE__->sequence('url_id_seq');

sub query { } # handled by hash lookup

sub insert {
    my $class = shift;
    my $data = shift;
 
    my @ids;
    
    my $addresses = $class->iodef_addresses($data->{'data'});
    foreach my $address (@$addresses){
        my $addr = lc($address->get_content());
        next unless($addr =~ /^$RE{'URI'}/ || $addr =~ /^$RE{'URI'}{'HTTP'}{-scheme => 'https'}$/);
        my $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            confidence  => $data->{'confidence'},
        });
        push(@ids,$id);
        $id = $class->insert_hash($data,$addr);
    }
    return(undef,\@ids);
}

1;