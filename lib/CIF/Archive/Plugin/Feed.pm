package CIF::Archive::Plugin::Feed;
use base 'CIF::Archive::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];

my @plugins = __PACKAGE__->plugins();

__PACKAGE__->table('feed');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence reporttime created/);
__PACKAGE__->columns(Essential => qw/id uuid guid hash confidence reporttime created/);
__PACKAGE__->sequence('feed_id_seq');
__PACKAGE__->has_a(uuid => 'CIF::Archive');
__PACKAGE__->add_trigger(after_delete => \&trigger_after_delete);

sub trigger_after_delete {
    my $class = shift;
    
    my $hash = CIF::Archive::Plugin::Hash->retrieve(uuid => $class->uuid());
    $hash->delete() if($hash);
    
    my $archive = CIF::Archive->retrieve(uuid => $class->uuid());
    $archive->delete() if($archive);
}

sub insert {
    my $class = shift;
    my $data = shift;
    
    return unless(ref($data->{'data'}) eq 'FeedType');

    my $hash    = $data->{'data'}->get_description();
    $hash       = $class->SUPER::generate_sha1($hash);
    
    $data->{'confidence'} = $data->{'data'}->get_confidence();
        
    $class->SUPER::insert({
        guid        => $data->{'guid'},
        uuid        => $data->{'uuid'},
        hash        => $hash,
        confidence  => $data->{'confidence'},
        reporttime  => $data->{'reporttime'},
    });
    my $id = $class->insert_hash($data,$hash);
    
    return(undef,$id);
}

__PACKAGE__->set_sql(feeds => qq{
    SELECT count(hash),hash,confidence 
    FROM __TABLE__ t
    GROUP BY hash,confidence
    ORDER BY count desc
});

__PACKAGE__->set_sql(feed_group => qq{
    SELECT *
    FROM __TABLE__ t
    WHERE hash = ?
    AND confidence = ?
    ORDER BY id ASC
});
1;
