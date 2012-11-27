SET default_tablespace = 'index';

DROP TABLE IF EXISTS domain CASCADE;
CREATE TABLE domain (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash text,
    address text,
    confidence real,
    reporttime timestamp with time zone default NOW(),
    created timestamp with time zone DEFAULT NOW()
);

DROP TABLE IF EXISTS domain_botnet;
CREATE TABLE domain_botnet () INHERITS (domain);
ALTER TABLE domain_botnet ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS domain_malware;
CREATE TABLE domain_malware () INHERITS (domain);
ALTER TABLE domain_malware ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS domain_fastflux;
CREATE TABLE domain_fastflux () INHERITS (domain);
ALTER TABLE domain_fastflux ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS domain_whitelist;
CREATE TABLE domain_whitelist () INHERITS (domain);
ALTER TABLE domain_whitelist ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS domain_suspicious;
CREATE TABLE domain_suspicious () INHERITS (domain);
ALTER TABLE domain_suspicious ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS domain_phishing;
CREATE TABLE domain_phishing () INHERITS (domain);
ALTER TABLE domain_phishing ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS domain_nameserver;
CREATE TABLE domain_nameserver () INHERITS (domain);
ALTER TABLE domain_nameserver ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS domain_spamvertising;
CREATE TABLE domain_spamvertising () INHERITS (domain);
ALTER TABLE domain_spamvertising ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS domain_passive;
CREATE TABLE domain_passive () INHERITS (domain);
ALTER TABLE domain_passive ADD PRIMARY KEY (id);