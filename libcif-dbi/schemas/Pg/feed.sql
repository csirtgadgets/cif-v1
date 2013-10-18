SET default_tablespace = 'index';
DROP TABLE IF EXISTS feed CASCADE;
CREATE TABLE feed (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash text,
    confidence real,
    reporttime timestamp with time zone default NOW(),
    created timestamp with time zone DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_feed;
CREATE INDEX idx_feed ON feed (hash,confidence);

DROP INDEX IF EXISTS idx_feed_uuid;
CREATE INDEX idx_feed_uuid ON feed (uuid);