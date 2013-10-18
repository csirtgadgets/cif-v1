package CIF::APIKeyGroups;
use base 'CIF::DBI';

__PACKAGE__->table('apikeys_groups');
__PACKAGE__->columns(Primary => qw/uuid guid/);
__PACKAGE__->columns(All => qw/uuid guid default_guid created/);
__PACKAGE__->sequence('apikeys_groups_id_seq');
__PACKAGE__->has_a(uuid => 'CIF::APIKey');

1;