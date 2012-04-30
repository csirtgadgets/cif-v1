SET default_tablespace = 'index';
DROP TABLE IF EXISTS infrastructure CASCADE;
CREATE TABLE infrastructure (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    address INET NOT NULL,
    portlist varchar(255),
    protocol int,
    confidence real,
    detecttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);