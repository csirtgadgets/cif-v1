make clean
rm *.tar.gz
autoreconf -vf
./configure
make dist
