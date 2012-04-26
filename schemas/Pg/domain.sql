SET default_tablespace = 'index';
DROP TABLE IF EXISTS domain CASCADE;
CREATE TABLE domain (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash varchar(40),
    confidence REAL,
    detecttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);

CREATE TABLE domain_whitelist() INHERITS (domain);
ALTER TABLE domain_whitelist ADD PRIMARY KEY (id);

CREATE TABLE domain_fastflux() INHERITS (domain);
ALTER TABLE domain_fastflux ADD PRIMARY KEY (id);

CREATE TABLE domain_nameserver() INHERITS (domain);
ALTER TABLE domain_nameserver ADD PRIMARY KEY (id);

CREATE TABLE domain_malware() INHERITS (domain);
ALTER TABLE domain_malware ADD PRIMARY KEY (id);

CREATE TABLE domain_botnet() INHERITS (domain);
ALTER TABLE domain_botnet ADD PRIMARY KEY (id);

CREATE TABLE domain_passivedns() INHERITS (domain);
ALTER TABLE domain_passivedns ADD PRIMARY KEY (id);

CREATE TABLE domain_search() INHERITS (domain);
ALTER TABLE domain_search ADD PRIMARY KEY (id);

CREATE TABLE domain_phishing() INHERITS (domain);
ALTER TABLE domain_phishing ADD PRIMARY KEY (id);

CREATE TABLE domain_suspicious() INHERITS (domain);
ALTER TABLE domain_suspicious ADD PRIMARY KEY (id);