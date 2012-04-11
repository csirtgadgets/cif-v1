SET default_tablespace = 'index';
DROP TABLE IF EXISTS countrycode CASCADE;
CREATE TABLE countrycode (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    cc varchar(5),
    confidence REAL,
    detecttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);