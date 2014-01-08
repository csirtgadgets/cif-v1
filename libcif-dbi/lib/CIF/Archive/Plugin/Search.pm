package CIF::Archive::Plugin::Search;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Digest::SHA qw/sha1_hex/;
use Try::Tiny;
use Iodef::Pb::Simple qw(iodef_confidence iodef_impacts iodef_additional_data iodef_guid);

__PACKAGE__->table('search');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid term confidence reporttime created/);
__PACKAGE__->sequence('search_id_seq');

my @plugins = __PACKAGE__->plugins();

sub query { } # handled by the hash module

sub is_search {
    my $class = shift;
    my $data = shift;
    
    my $impacts = iodef_impacts($data);
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /^search/);
    }
}

sub insert {
    my $class = shift;
    my $data = shift;

    return unless($data->{'search'}); # don't ask
    return unless($class->test_datatype($data));
    return unless(ref($data->{'data'}) eq 'IODEFDocumentType');
    my $tbl = $class->table();
    my @ids;

    foreach my $i (@{$data->{'data'}->get_Incident()}){
        next unless($class->is_search($i));
        my $confidence = iodef_confidence($i);
        $confidence = @{$confidence}[0]->get_content();
        my $reporttime = $i->get_ReportTime();
     
        foreach(@plugins){
            if($_->prepare($data)){
                $class->table($class->sub_table($_));
                last;
            }
        }
        if($class->test_feed($data)){
            $class->SUPER::insert({
                    guid        => iodef_guid($i) || $data->{'guid'},
                    uuid        => $i->get_IncidentID->get_content(),
                    term        => $data->{'search'},
                    confidence  => $confidence,
                    reporttime  => $reporttime,
             });
        }
            
        my $id = $class->insert_hash({ 
            uuid        => $data->{'uuid'}, 
            guid        => $data->{'guid'}, 
            confidence  => $confidence,
            reporttime  => $reporttime,
        },$class->SUPER::generate_sha1($data->{'search'}));
        push(@ids,$id);  
    }
    $class->table($tbl);
    return(undef,\@ids);
}

1;