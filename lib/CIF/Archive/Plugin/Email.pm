package CIF::Archive::Plugin::Email;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Digest::SHA1 qw(sha1_hex);
use Iodef::Pb::Simple qw(iodef_addresses iodef_confidence iodef_guid);

__PACKAGE__->table('email');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(Essential => qw/id uuid guid hash confidence reporttime created/);
__PACKAGE__->sequence('email_id_seq');

my @plugins = __PACKAGE__->plugins();


sub is_email {
    my $e = shift;
    return unless($e);
    return if($e =~ /^(ftp|https?):\/\//);
    return unless(lc($e) =~ /^[a-z0-9_.-]+\@[a-z0-9.-]+\.[a-z0-9.-]{2,5}$/);
    return(1);
}

sub insert {
    my $class = shift;
    my $data = shift;
    
    return unless($class->test_datatype($data));
    return unless(ref($data->{'data'}) eq 'IODEFDocumentType');

    my $addresses = iodef_addresses($data->{'data'});
    return unless(@$addresses);

    my $tbl = $class->table();
    my @ids;
    foreach my $i (@{$data->{'data'}->get_Incident()}){
        foreach(@plugins){
            if($_->prepare($i)){
                $class->table($_->table());
                last;
            }
        }
        my $reporttime = $i->get_ReportTime();
        my $confidence = iodef_confidence($i);
        $confidence = @{$confidence}[0]->get_content();
        
        foreach my $address (@$addresses){
            my $addr = lc($address->get_content());
            next unless(is_email($addr));
            my $hash = $class->SUPER::generate_sha1($addr);
            if($class->test_feed($data)){
                $class->SUPER::insert({
                    uuid        => $data->{'uuid'},
                    guid        => $data->{'guid'},
                    hash        => $hash,
                    confidence  => $confidence,
                    reporttime  => $reporttime,
                });
            }
            $addr =~ /\@([a-z0-9.-]+\.[a-z0-9.-]{2,5}$)/;
            $addr = $1;
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