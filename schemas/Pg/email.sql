SET default_tablespace = 'index';

DROP TABLE IF EXISTS email CASCADE;
CREATE TABLE email (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash varchar(40),
    confidence real,
    reporttime timestamp with time zone default NOW(),
    created timestamp with time zone DEFAULT NOW()
);

DROP TABLE IF EXISTS email_suspicious;
CREATE TABLE email_suspicious () INHERITS (email);
ALTER TABLE email_suspicious ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS email_phishing;
CREATE TABLE email_phishing () INHERITS (email);
ALTER TABLE email_phishing ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS email_registrant;
CREATE TABLE email_registrant () INHERITS (email);
ALTER TABLE email_registrant ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS email_whitelist;
CREATE TABLE email_whitelist () INHERITS (email);
ALTER TABLE email_whitelist ADD PRIMARY KEY (id);