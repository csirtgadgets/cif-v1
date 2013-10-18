set default_tablespace = archive;

DROP TYPE IF EXISTS severity;
DROP TYPE IF EXISTS restriction;

ALTER TABLE archive DROP COLUMN source;
ALTER TABLE archive DROP COLUMN restriction;
ALTER TABLE archive DROP COLUMN description;
ALTER TABLE archive RENAME COLUMN created TO reporttime;
ALTER TABLE archive ADD COLUMN created timestamp with time zone default now();

set default_tablespace = index;

ALTER INDEX archive_uuid_key RENAME TO idx_archive_uuid;