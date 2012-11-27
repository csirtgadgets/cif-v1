package CIF::Archive::Plugin::Hash;
use base 'CIF::Archive::Plugin';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Iodef::Pb::Simple qw(iodef_confidence iodef_additional_data iodef_guid);
use CIF qw/debug/;

# work-around for cif-v1
use Regexp::Common qw/net/;
use Digest::SHA1 qw(sha1_hex);

my @plugins = __PACKAGE__->plugins();

__PACKAGE__->table('hash');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence reporttime created/);
__PACKAGE__->sequence('hash_id_seq');
__PACKAGE__->has_a(uuid => 'CIF::Archive');
__PACKAGE__->add_trigger(after_delete => \&trigger_after_delete);

sub trigger_after_delete {
    my $class = shift;
     
    my $archive = CIF::Archive->retrieve(uuid => $class->uuid());
    $archive->delete() if($archive);
}

sub prepare {}

sub insert {
    my $class   = shift;
    my $data    = shift;
    my $confidence;
    my @ids;
    my $tbl = $class->table();

    # we're explicitly placing a hash
    if($data->{'hash'}){
        $confidence = $data->{'confidence'};
        
        if(my $t = return_table($data->{'hash'})){
            $class->table($t);
        }
        my $id = $class->SUPER::insert({
            hash        => $data->{'hash'},
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            confidence  => $confidence,
            reporttime  => $data->{'reporttime'},
        });
        push(@ids,$id);
    } elsif(ref($data->{'data'}) eq 'IODEFDocumentType') {
        foreach my $i (@{$data->{'data'}->get_Incident()}){
            $confidence = iodef_confidence($i);
            $confidence = @{$confidence}[0]->get_content();
         
            # for now, we expect all hashes to be sent in
            # under Incident.AdditionalData
            # we can improve this in the future
            my $ad = iodef_additional_data($i);
            return unless($ad);
            
            my @ids;
            foreach my $a (@$ad){
                next unless($a->get_meaning() && lc($a->get_meaning()) =~ /^(md5|sha(\d+)|uuid|hash)$/);
                next unless($a->get_content());
                my $hash = $a->get_content();
                if(my $t = return_table($hash)){
                    $class->table($t);
                }
                my $id = $class->SUPER::insert({
                    hash        => $hash,
                    uuid        => $data->{'uuid'},
                    guid        => $data->{'guid'},
                    confidence  => $confidence,
                    reporttime  => $data->{'reporttime'},
                });
                push(@ids,$id);
            }
        }
    }
    $class->table($tbl);
    return(undef,\@ids); 
}

sub return_table {
    my $hash = shift;
    foreach (@plugins){
        next unless($_->prepare($hash));
        return $_->table();
        last;
    }
}

sub query {
    my $class   = shift;
    my $data    = shift;
    foreach (@plugins){
        my $r = $_->query($data);
        return ($r) if($r && $r->count());
    }
    return;
}

sub purge_hashes {
    my $self    = shift;
    my $args    = shift;
    
    my $ts = $args->{'timestamp'};
    
    my $ret = 0;
    my $count;
    do {
        debug('purging...');
        $ret = $self->sql_purge_hashes->execute($ts);
        $ret = $self->sql_purge_archive->execute($ts);
        debug('commit...');
        $self->dbi_commit();
        $ret = 0 unless($ret > 0);
        $count += $ret;
        debug($ret);
    } while($ret);
    
    debug('done...');
    return (undef,$ret);
}

__PACKAGE__->set_sql('purge_archive'    => qq{
    DELETE FROM archive
    WHERE reporttime <= ?
});

__PACKAGE__->set_sql('purge_hashes' => qq{
    DELETE FROM __TABLE__
    WHERE reporttime <= ?
});

__PACKAGE__->set_sql('lookup' => qq{
    SELECT t.id,t.uuid,archive.data
    FROM __TABLE__ t
    LEFT JOIN apikeys_groups on t.guid = apikeys_groups.guid
    LEFT JOIN archive ON archive.uuid = t.uuid
    WHERE 
        hash = ?
        AND confidence >= ?
        AND apikeys_groups.uuid = ?
        AND archive.uuid IS NOT NULL
    ORDER BY t.reporttime DESC, t.created DESC, t.id DESC
    LIMIT ?
});

1;