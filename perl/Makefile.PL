use inc::Module::Install;

name        'CIF-Msg';
all_from    'lib/CIF/Msg.pm';

requires    'Module::Install'           => '1.00';
requires    'Class::Accessor'           => '0.34';
requires    'Google::ProtocolBuffers'   => '0.08';

WriteAll();
