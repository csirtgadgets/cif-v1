make clean
rm *.tar.gz
autoreconf -vfi
./configure
make dist
