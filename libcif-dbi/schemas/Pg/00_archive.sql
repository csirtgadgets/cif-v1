SET default_tablespace = 'archive';
DROP TABLE IF EXISTS archive CASCADE;

CREATE TABLE archive (
    id BIGSERIAL NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    format text,
    reporttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW(),
    data text not null
);

SET default_tablespace = 'index';
ALTER TABLE archive ADD PRIMARY KEY (id);
CREATE INDEX idx_archive_uuid ON archive (uuid);
CREATE INDEX idx_archive_created ON archive (created);