use Test::More;
BEGIN { use_ok('CIF') };

use UUID::Tiny ':std';
use CIF qw/generate_uuid_ns generate_uuid_random/;

ok(create_uuid_as_string(UUID_RANDOM));
ok(create_uuid_as_string(UUID_V3, UUID_NIL, 'everyone') eq '8c864306-d21a-37b1-8705-746a786719bf');
ok(create_uuid_as_string(UUID_V3, UUID_NIL, 'root') eq '1893558f-9371-3bcd-9369-aa4942339231');

ok(generate_uuid_random() ne generate_uuid_random());
ok(generate_uuid_ns('everyone') eq '8c864306-d21a-37b1-8705-746a786719bf');
ok(generate_uuid_ns('root') eq '1893558f-9371-3bcd-9369-aa4942339231');
ok(generate_uuid_ns('p1.example.com') eq '13805ea4-fe04-3ac6-9339-40ad396b6d41');

done_testing();
