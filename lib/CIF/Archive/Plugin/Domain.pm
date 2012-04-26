package CIF::Archive::Plugin::Domain;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

use Try::Tiny;

__PACKAGE__->table('domain');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid sha1 hash confidence detecttime created/);
__PACKAGE__->sequence('domain_id_seq');

my @plugins = __PACKAGE__->plugins();

sub query { } # handled by the hash module

sub insert {
    my $class = shift;
    my $data = shift;

    my $tbl = $class->table();
    foreach(@plugins){
        if($_->prepare($data)){
            $class->table($class->sub_table($_));
            last;
        }
    }
    my $uuid = $data->{'uuid'};
         
    my $addresses = $class->iodef_addresses($data->{'data'});
    return unless(@$addresses);
    
    my $confidence = $class->iodef_confidence($data->{'data'});
    $confidence = @{$confidence}[0]->get_content();
    
    my @ids;
    foreach my $address (@$addresses){
        my $addr = lc($address->get_content());
        next if($addr =~ /^(ftp|https?):\/\//);
        next unless($addr =~ /[a-z0-9.\-_]+\.[a-z]{2,6}$/);
        my @a1 = reverse(split(/\./,$addr));
        my @a2 = @a1;
        foreach (0 ... $#a1-1){
            my $a = join('.',reverse(@a2));
            pop(@a2);
            my $hash = $class->SUPER::generate_sha1($a);
            my $id = $class->SUPER::insert({
                uuid        => $data->{'uuid'},
                guid        => $data->{'guid'},
                hash        => $hash,
                confidence  => $confidence,
            });
            push(@ids,$id);
            $id = $class->insert_hash($data,$hash);
        }
    }
    $class->table($tbl);
    return(undef,@ids);
}

1;