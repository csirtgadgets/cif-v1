SUBDIRS = libcif libcif-dbi cif-router cif-smrt libcif-dbi-asn libcif-dbi-cc
EXTRA_DIST = sbin

ME=cif-v1
BUILD=$(shell git describe --tags)
SNAPSHOT=$(ME)-$(BUILD)

all: default

default:
	$(PERL) libcif/sbin/gen_protocol_bindings.pl

fixperms:
	chmod 0755 $(prefix)
	chown -R $(CIF_USER) $(prefix)
	chgrp -R $(CIF_GROUP) $(prefix)

install: files-install fixperms

files-install: libcif-install libcif-dbi-install cif-router-install cif-smrt-install

libcif-install:
	-( cd libcif && make install )

libcif-dbi-install:
	-( cd libcif-dbi && make install )
	if [ $(PLUGIN_DBI_ASN) ]; then cd libcif-dbi-asn && make install; fi
	if [ $(PLUGIN_DBI_CC) ]; then cd libcif-dbi-cc && make install; fi

purgedb:
	-( cd libcif-dbi && make purgedb )

initdb:
	-( cd libcif-dbi && make initdb && make tables)

tables:
	-( cd libcif-dbi && make tables )

cif-router-install:
	-( cd cif-router && make install )

cif-smrt-install:
	-( cd cif-smrt && make install )

depends: fixdeps

fixdeps:
	$(PERL) ./sbin/test-dependencies --verbose --install --prefix $(prefix)

testdeps:
	$(PERL) ./sbin/test-dependencies --verbose --prefix $(prefix)

clean:
	rm Makefile
	rm config.log
	rm config.status

realclean:
	clean
	rm Makefile.in
	rm configure
	rm aclocal.m4

reconf:
	autoreconf -vf

snapshot:
	git archive --format=tar --prefix=$(BUILD)/ $(BUILD) | gzip > $(SNAPSHOT).tar.gz
