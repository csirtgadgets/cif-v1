EXTRA_DIST = lib bin sbin schemas

ME=libcif-dbi
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
    
initdb: create_db create_archive create_index

create_db:
	$(PSQL) -U $(DB_DBA) -h $(DB_HOST) -p $(DB_PORT) -c 'CREATE DATABASE $(DB_DATABASE)'
    
create_archive:
	[ -d $(DB_ARCHIVE_LOC) ] || mkdir -p $(DB_ARCHIVE_LOC) && chown $(DB_UNIXOWNER):$(DB_UNIXOWNER) $(DB_ARCHIVE_LOC) 
	$(PSQL) -U $(DB_DBA) -h $(DB_HOST) -p $(DB_PORT) -d $(DB_DATABASE) -c "CREATE TABLESPACE archive LOCATION '$(DB_ARCHIVE_LOC)'"
    
create_index:
	[ -d $(DB_INDEX_LOC) ] || mkdir -p $(DB_INDEX_LOC) && chown $(DB_UNIXOWNER):$(DB_UNIXOWNER) $(DB_INDEX_LOC) 
	$(PSQL) -U $(DB_DBA) -h $(DB_HOST) -p $(DB_PORT) -d $(DB_DATABASE) -c "CREATE TABLESPACE index LOCATION '$(DB_INDEX_LOC)'"

tables: create_tables create_indicies

create_tables:
	-( cd schemas/$(DB_TYPE) && find -type f -print | grep -v index | sort ) | while read file ; do \
    $(PSQL) -U $(DB_DBA) -d $(DB_DATABASE) -h $(DB_HOST) -p $(DB_PORT) < "schemas/$(DB_TYPE)/$$file" ; \
    done
	@echo "Tables built"
    
create_indicies:
	-( cd schemas/$(DB_TYPE)/index && find -type f -print | sort ) | while read file ; do \
    $(PSQL) -U $(DB_DBA) -d $(DB_DATABASE) -h $(DB_HOST) -p $(DB_PORT) < "schemas/$(DB_TYPE)/index/$$file" ; \
    done
	@echo "Table Indicies built"

dropdb: drop_database drop_archive drop_index

drop_database:
	$(PSQL) -U $(DB_DBA) -h $(DB_HOST) -p $(DB_PORT) -c 'DROP DATABASE IF EXISTS $(DB_DATABASE)'

drop_archive:
	$(PSQL) -U $(DB_DBA) -h $(DB_HOST) -p $(DB_PORT) -c "DROP TABLESPACE IF EXISTS archive"

drop_index:
	$(PSQL) -U $(DB_DBA) -h $(DB_HOST) -p $(DB_PORT) -c "DROP TABLESPACE IF EXISTS index"
	
purgedb:
	$(PSQL) -U $(DB_DBA) -h $(DB_HOST) -p $(DB_PORT) -d $(DB_DATABASE) < "schemas/pg_purge.sql"

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
