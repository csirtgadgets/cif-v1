SUBDIRS = libcif libcif-dbi cif-router cif-smrt

ME=cif-v1
BUILD=$(shell git describe --tags)
SNAPSHOT=$(ME)-$(BUILD)

all: default

default:
	@echo "Please read the README before beginning your installation."

fixperms:
	chmod 0755 $(prefix)
	chown -R $(CIF_USER) $(prefix)
	chgrp -R $(CIF_GROUP) $(prefix)

install: files-install fixperms

files-install: libcif-install libcif-dbi-install cif-router-install cif-smrt-install

depends: fixdeps

fixdeps:
	$(PERL) ./libcif/sbin/test-dependencies --verbose --install --prefix $(prefix)
	$(PERL) ./libcif-dbi/sbin/test-dependencies --verbose --install --prefix $(prefix)
	$(PERL) ./cif-router/sbin/test-dependencies --verbose --install --prefix $(prefix)
	$(PERL) ./cif-smrt/sbin/test-dependencies --verbose --install --prefix $(prefix)

testdeps:
	$(PERL) ./libcif/sbin/test-dependencies --verbose --prefix $(prefix)
	$(PERL) ./libcif-dbi/sbin/test-dependencies --verbose --prefix $(prefix)
	$(PERL) ./cif-router/sbin/test-dependencies --verbose --prefix $(prefix)
	$(PERL) ./cif-smrt/sbin/test-dependencies --verbose --prefix $(prefix)

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
