SET default_tablespace = 'index';
DROP TABLE IF EXISTS feed CASCADE;
CREATE TABLE feed (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash varchar(40),
    confidence real,
    reporttime timestamp with time zone default NOW(),
    created timestamp with time zone DEFAULT NOW()
);