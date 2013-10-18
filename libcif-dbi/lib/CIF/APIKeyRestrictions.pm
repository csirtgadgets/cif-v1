package CIF::APIKeyRestrictions;
use base 'CIF::DBI';

__PACKAGE__->table('apikeys_restrictions');
__PACKAGE__->columns(Primary => qw/uuid access/);
__PACKAGE__->columns(All => qw/uuid access created/);
__PACKAGE__->sequence('apikeys_restrictions_id_seq');
__PACKAGE__->has_a(uuid => 'CIF::APIKey');

1;