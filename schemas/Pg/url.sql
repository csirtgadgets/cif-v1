SET default_tablespace = 'index';
DROP TABLE IF EXISTS url CASCADE;
CREATE TABLE url (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    confidence REAL,
    detecttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);