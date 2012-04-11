package CIF::Archive::Plugin::Domain;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Digest::SHA1 qw/sha1_hex/;

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
    my $confidence  = 50;
    
    my @ids;
    my $addresses = $class->iodef_addresses($data->{'data'});
    foreach my $address (@$addresses){
        my $addr = lc($address->get_content());
        next unless($addr =~ /[a-z0-9.\-_]+\.[a-z]{2,6}$/);
        my @a1 = reverse(split(/\./,$addr));
        my @a2 = @a1;
        foreach (0 ... $#a1-1){
            my $a = join('.',reverse(@a2));
            pop(@a2);
            $data->{'hash'} = sha1_hex($a);
            my $id = $class->SUPER::insert({
                uuid        => $data->{'uuid'},
                guid        => $data->{'guid'},
                hash        => $data->{'hash'},
                confidence  => $confidence,
            });
            push(@ids,$id);
            $id = $class->insert_hash($data,$a);
        }
    }
    $class->table($tbl);
    return(undef,@ids);
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT DISTINCT on (__TABLE__.uuid) __TABLE__.uuid, confidence, archive.data
    FROM __TABLE__
    LEFT JOIN archive ON __TABLE__.uuid = archive.uuid
    WHERE
        detecttime >= ?
        AND __TABLE__.confidence >= ?
        AND NOT EXISTS (
            SELECT dw.address FROM domain_whitelist dw
            WHERE
                    dw.detecttime >= ?
                    AND dw.confidence >= 25
                    AND dw.hash = __TABLE__.hash
        )
    ORDER BY __TABLE__.uuid ASC, __TABLE__.id ASC
    LIMIT ?
});

1;