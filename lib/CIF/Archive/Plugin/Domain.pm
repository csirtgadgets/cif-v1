package CIF::Archive::Plugin::Domain;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Iodef::Pb::Simple qw(iodef_addresses iodef_confidence iodef_guid);
use Digest::SHA1 qw/sha1_hex/;

__PACKAGE__->table('domain');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid hash address confidence reporttime created/);
__PACKAGE__->sequence('domain_id_seq');

my @plugins = __PACKAGE__->plugins();

sub query { } # handled by the address module

sub insert {
    my $class = shift;
    my $data = shift;
    
    return unless($class->test_datatype($data));
    return unless(ref($data->{'data'}) eq 'IODEFDocumentType');

    my $tbl = $class->table();
    my @ids;
 
    foreach my $i (@{$data->{'data'}->get_Incident()}){
        foreach(@plugins){
            if($_->prepare($i)){
                $class->table($class->sub_table($_));
                last;
            }
        }
        my $reporttime = $i->get_ReportTime();
        my $uuid = $i->get_IncidentID->get_content();
             
        my $addresses = iodef_addresses($i);
        return unless(@$addresses);
        
        my $confidence = iodef_confidence($i);
        $confidence = @{$confidence}[0]->get_content();
        
        foreach my $address (@$addresses){
            my $addr = lc($address->get_content());
            next if($addr =~ /^(ftp|https?):\/\//);
            # this way we can change the regex as we go if needed
            next if(CIF::Archive::Plugin::Email::is_email($addr));
            next unless($addr =~ /[a-z0-9.\-_]+\.[a-z]{2,6}$/);
            if($class->test_feed($data)){
                $class->SUPER::insert({
                    uuid        => $data->{'uuid'},
                    guid        => $data->{'guid'},
                    hash        => sha1_hex($addr),
                    address     => $addr,
                    confidence  => $confidence,
                    reporttime  => $reporttime,
                });
            }
            
            my @a1 = reverse(split(/\./,$addr));
            my @a2 = @a1;
            foreach (0 ... $#a1-1){
                my $a = join('.',reverse(@a2));
                pop(@a2);
                my $hash = $class->SUPER::generate_sha1($a);
                my $id = $class->insert_hash({ 
                    uuid        => $data->{'uuid'}, 
                    guid        => $data->{'guid'}, 
                    confidence  => $confidence,
                    reporttime  => $reporttime,
                },$hash);
                push(@ids,$id);
            }
        }
    }
    $class->table($tbl);
    return(undef,\@ids);
}

1;