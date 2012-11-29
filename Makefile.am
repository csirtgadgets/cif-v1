EXTRA_DIST = lib sbin bin

ME=libcif
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

files-install: libs-install bin-install

depends: fixdeps

fixdeps:
	$(PERL) ./sbin/test-dependencies --verbose --install --prefix $(prefix)

testdeps:
	$(PERL) ./sbin/test-dependencies --verbose --prefix $(prefix)

libs-install: 
	[ -d $(libdir) ] || $(INSTALL) -m 0755 -d $(libdir)
	-( cd lib && find . -type d -print ) | while read dir ; do \
    $(INSTALL) -m 0755 -d "$(libdir)/$$dir" ; \
    done
	-( cd lib && find . -type f -print ) | while read file ; do \
    $(INSTALL) -m 0644 "lib/$$file" "$(libdir)/$$file" ; \
    done

bin-install:	
	[ -d $(bindir) ] || $(INSTALL) -m 0770 -d $(bindir)
	-( cd bin && find . -type f -print ) | while read file ; do \
        $(INSTALL) -m 0750 "bin/$$file" "$(bindir)/$$file" ; \
    done

clean:
	rm Makefile
	rm config.log
	rm config.status

realclean:
	clean
	rm Makefile.in
	rm configure
	rm aclocal.m4
 
bindings:
	$(PERL) ./sbin/gen_protocol_bindings.pl

reconf:
	autoreconf -vf

snapshot:
	git archive --format=tar --prefix=$(BUILD)/ $(BUILD) | gzip > $(SNAPSHOT).tar.gz
