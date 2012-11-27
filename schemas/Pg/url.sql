SET default_tablespace = 'index';
DROP TABLE IF EXISTS url CASCADE;
CREATE TABLE url (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash varchar(40),
    confidence REAL,
    reporttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);

CREATE TABLE url_botnet () INHERITS (url);
ALTER TABLE url_botnet ADD PRIMARY KEY (id);

CREATE TABLE url_malware () INHERITS (url);
ALTER TABLE url_malware ADD PRIMARY KEY (id);

CREATE TABLE url_phishing () INHERITS (url);
ALTER TABLE url_phishing ADD PRIMARY KEY (id);

CREATE TABLE url_suspicious () INHERITS (url);
ALTER TABLE url_suspicious ADD PRIMARY KEY (id);

CREATE TABLE url_spam () INHERITS (url);
ALTER TABLE url_spam ADD PRIMARY KEY (id);

CREATE TABLE url_spamvertising () INHERITS (url);
ALTER TABLE url_spamvertising ADD PRIMARY KEY (id);

CREATE TABLE url_whitelist () INHERITS (url);
ALTER TABLE url_whitelist ADD PRIMARY KEY (id);