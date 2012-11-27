SET default_tablespace = 'index';
DROP TABLE IF EXISTS search CASCADE;
CREATE TABLE search (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash varchar(40),
    confidence REAL,
    reporttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);