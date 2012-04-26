SET default_tablespace = 'index';
DROP TABLE IF EXISTS url CASCADE;
CREATE TABLE url (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash text,
    confidence REAL,
    detecttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);

CREATE TABLE url_botnet () INHERITS (url);
ALTER TABLE url_botnet ADD PRIMARY KEY (id);

CREATE TABLE url_malware () INHERITS (url);
ALTER TABLE url_malware ADD PRIMARY KEY (id);

CREATE TABLE url_phishing () INHERITS (url);
ALTER TABLE url_phishing ADD PRIMARY KEY (id);

CREATE TABLE url_search () INHERITS (url);
ALTER TABLE url_search ADD PRIMARY KEY (id);