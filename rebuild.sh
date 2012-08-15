autoreconf -vf
automake --add-missing
./configure
make
perl sbin/gen_protocol_bindings.pl
make dist
