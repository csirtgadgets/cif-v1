package CIF::Archive::Plugin::Search;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Digest::SHA1 qw/sha1_hex/;

use Try::Tiny;

__PACKAGE__->table('search');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence detecttime created/);
__PACKAGE__->sequence('search_id_seq');

my @plugins = __PACKAGE__->plugins();

sub query { } # handled by the hash module

sub is_search {
    my $class = shift;
    my $data = shift;
    
    my $impacts = $class->iodef_impacts($data);
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /^search/);
    }
}

sub insert {
    my $class = shift;
    my $data = shift;

    return unless($class->is_search($data->{'data'}));
   
    my $uuid = $data->{'uuid'};
    my $confidence = $class->iodef_confidence($data->{'data'});
    $data->{'confidence'} = @{$confidence}[0]->get_content();
    
    my $tbl = $class->table();
    foreach(@plugins){
        if($_->prepare($data)){
            $class->table($class->sub_table($_));
            last;
        }
    }
    
    my @ids;
    my $additional_data = $class->iodef_additional_data($data->{'data'});
    return unless(@$additional_data);
    foreach my $entry (@$additional_data){
        ## TODO -- split this into plugins MD5, SHA1, UUID
        next unless($entry);
        next unless($entry->get_meaning() eq 'hash');
        next unless($entry->get_content() =~ /^[a-f0-9]{40}$/);
        if($class->test_feed($data)){
            warn $class->SUPER::insert({
                guid        => $data->{'guid'},
                uuid        => $data->{'uuid'},
                hash        => $entry->get_content(),
                confidence  => $data->{'confidence'},
            });
        }
        
        my $id = $class->insert_hash($data,$entry->get_content());
        push(@ids,$id);
    }    
      
    $class->table($tbl);
    return(undef,\@ids);
}

1;