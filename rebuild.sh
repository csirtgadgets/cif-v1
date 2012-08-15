autoreconf -vf
automake --add-missing
./configure
make
make dist
