package CIF::Archive::Plugin;
use base 'CIF::DBI';

use warnings;
use strict;

use Digest::SHA1 qw/sha1_hex/;

sub query {}

# sub tables are auto-defined by the plugin name
# eg: Domain::Phishing translates to:
# domain_phishing
sub sub_table {
    my $class = shift;
    my $plug = shift;
    
    $plug =~ m/Plugin::(\S+)::(\S+)$/;
    my ($type,$subtype) = (lc($1),lc($2));
    return $type.'_'.$subtype;
}

sub generate_sha1 {
    my $self    = shift;
    my $thing   = shift || return;
    
    return $thing if(lc($thing) =~ /^[a-f0-9]{40}$/);
    return sha1_hex($thing);
}

sub test_feed {
    my $class = shift;
    my $data = shift;
    my $feeds = $data->{'feeds'};
    
    return unless($feeds);
    $feeds = [$feeds] unless(ref($feeds) eq 'ARRAY');
    return unless(@$feeds);
    foreach my $f (@$feeds){
        return 1 if(lc($class) =~ /$f$/);
    }
}
    
sub insert_hash {
    my $class = shift;
    my $data = shift;
    my $hash = shift;
    
    $hash = sha1_hex($hash) unless($hash =~ /^[a-f0-9]{40}$/);
    
    my $id = CIF::Archive::Plugin::Hash->insert({
        uuid        => $data->{'uuid'},
        guid        => $data->{'guid'},
        confidence  => $data->{'confidence'},
        hash        => $hash,
    });
    return ($id);
}

1;