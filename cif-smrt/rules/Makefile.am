EXTRA_DIST = etc

ME=cif-smrt-rules
BUILD=$(shell git describe --tags)
SNAPSHOT=$(ME)-$(BUILD)

all: default

default:
	@echo "Please read the README before beginning your installation."

fixperms:
	chmod 0755 $(prefix)
	chown -R $(CIF_USER) $(prefix)
	chgrp -R $(CIF_GROUP) $(prefix)

install: etc-install fixperms

etc-link:
	[ -d /etc/cif ] || ln -sf $(prefix)/etc /etc/cif
    
etc-install:
	[ -d $(sysconfdir) ] || $(INSTALL) -m 0755 -d $(sysconfdir)
	-( cd etc && find . -type d -print ) | while read dir ; do \
    $(INSTALL) -m 0750 -d "$(sysconfdir)/$$dir" ; \
    done
	-( cd etc && find . -type f -print ) | while read file ; do \
    $(INSTALL) -m 0640 "etc/$$file" "$(sysconfdir)/$$file" ; \
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

reconf:
	autoreconf -vf

snapshot:
	git archive --format=tar --prefix=$(BUILD)/ $(BUILD) | gzip > $(SNAPSHOT).tar.gz
