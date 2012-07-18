package CIF::APIKey;
use base 'CIF::DBI';

__PACKAGE__->table('apikeys');
__PACKAGE__->columns(Primary => 'uuid');
__PACKAGE__->columns(All => qw/uuid uuid_alias description parentid revoked write access expires created/);
__PACKAGE__->sequence('apikeys_id_seq');
__PACKAGE__->has_many(groups  => 'CIF::APIKeyGroups');

use CIF qw/is_uuid generate_uuid_random generate_uuid_url/;

# because UUID's are really primary keys too in our schema
# this overrides some of the default functionality of Class::DBI and 'id'
sub retrieve {
    my $class = shift;
    my %keys = @_;

    return $class->SUPER::retrieve(@_) unless($keys{'uuid'});

    my @recs = $class->search(uuid => $keys{'uuid'});
    return unless(@recs);
    return($recs[0]);
}

sub add_groups {
    my ($self,$default_guid,$groups) = @_;
    if($default_guid){
        $default_guid = generate_uuid_url($default_guid) unless(is_uuid($default_guid));
    }

    foreach (split(',',$groups)){
        $_ = generate_uuid_url($_) unless(is_uuid($_));
        my $isDefault = 1 if($default_guid && ($_ eq $default_guid));
        my $id = eval {
            CIF::APIKeyGroups->insert({
                uuid            => $self->uuid(),
                guid            => $_,
                default_guid    => $isDefault,
            });
        };
        if($@){
            die($@) unless($@ =~ /unique constraint/);
        }
    }
}

sub default_guid {
    my $self = shift;
    my @groups = $self->groups();
    foreach (@groups){
        return($_->guid()) if($_->default_guid());
    }
    # this shouldn't happen... in theory.
    return(0);
}

sub inGroup {
    return in_group(\@_);
}

sub in_group {
    my $self = shift;
    my $grp = shift;
    return unless($grp);
    $grp = lc($grp);
    $grp = generate_uuid_url($grp) unless(is_uuid($grp));

    my @groups = $self->groups();
    foreach (@groups){
        return(1) if($grp eq $_->guid());
    }
    return(0);
}

sub mygroups {
    return groups(\@_);
}

sub my_groups {
    my $self = shift;
    
    my @groups = $self->groups();
    return unless($#groups > -1);
    my $g = '';
    foreach (@groups){
        $g .= $_->guid().',';
    }
    $g =~ s/,$//;
    return $g;
}

## TODO -- move this to PROFILE
sub expired {
    my $self = shift;
    my $args = shift;

    return 0 unless($self->expires());
    
    my $time = DateTime::Format::DateParse->parse_datetime($self->expires());
    return 1 if(time() > $time);
    return 0;
}

1;