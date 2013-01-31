autoreconf -vf
automake --add-missing
./configure
make bindings
make dist
