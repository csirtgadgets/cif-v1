package CIF::Archive::Plugin::Domain;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

use Try::Tiny;

__PACKAGE__->table('domain');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid address confidence detecttime created/);
__PACKAGE__->sequence('domain_id_seq');

my @plugins = __PACKAGE__->plugins();

sub query { } # handled by the address module

sub insert {
    my $class = shift;
    my $data = shift;
    
    return unless(ref($data->{'data'}) eq 'IODEFDocumentType');

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
    $data->{'confidence'} = $confidence;
    
    my @ids;
    foreach my $address (@$addresses){
        my $addr = lc($address->get_content());
        next if($addr =~ /^(ftp|https?):\/\//);
        # this way we can change the regex as we go if needed
        next if(CIF::Archive::Plugin::Email::is_email($addr));
        next unless($addr =~ /[a-z0-9.\-_]+\.[a-z]{2,6}$/);
        if($class->test_feed($data)){
            $class->SUPER::insert({
                guid        => $data->{'guid'},
                uuid        => $data->{'uuid'},
                address        => $addr,
                confidence  => $confidence,
            });
        }
        
        my @a1 = reverse(split(/\./,$addr));
        my @a2 = @a1;
        foreach (0 ... $#a1-1){
            my $a = join('.',reverse(@a2));
            pop(@a2);
            my $hash = $class->SUPER::generate_sha1($a);
            my $id = $class->insert_hash($data,$hash);
            push(@ids,$id);
        }
    }
    $class->table($tbl);
    return(undef,@ids);
}

1;