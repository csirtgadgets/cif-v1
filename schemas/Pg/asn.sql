SET default_tablespace = 'index';
DROP TABLE IF EXISTS asn CASCADE;
CREATE TABLE asn (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    asn float not null,
    confidence real,
    detecttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);