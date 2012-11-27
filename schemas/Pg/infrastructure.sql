SET default_tablespace = 'index';

DROP TABLE IF EXISTS infrastructure CASCADE;
CREATE TABLE infrastructure (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    hash text,
    address text,
    confidence real,
    reporttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);

DROP TABLE IF EXISTS infrastructure_botnet;
CREATE TABLE infrastructure_botnet () INHERITS (infrastructure);
ALTER TABLE infrastructure_botnet ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_malware;
CREATE TABLE infrastructure_malware () INHERITS (infrastructure);
ALTER TABLE infrastructure_malware ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_fastflux;
CREATE TABLE infrastructure_fastflux () INHERITS (infrastructure);
ALTER TABLE infrastructure_fastflux ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_whitelist;
CREATE TABLE infrastructure_whitelist () INHERITS (infrastructure);
ALTER TABLE infrastructure_whitelist ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_scan;
CREATE TABLE infrastructure_scan () INHERITS (infrastructure);
ALTER TABLE infrastructure_scan ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_spam;
CREATE TABLE infrastructure_spam () INHERITS (infrastructure);
ALTER TABLE infrastructure_spam ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_spamvertising;
CREATE TABLE infrastructure_spamvertising () INHERITS (infrastructure);
ALTER TABLE infrastructure_spamvertising ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_suspicious;
CREATE TABLE infrastructure_suspicious () INHERITS (infrastructure);
ALTER TABLE infrastructure_suspicious ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_phishing;
CREATE TABLE infrastructure_phishing () INHERITS (infrastructure);
ALTER TABLE infrastructure_phishing ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_nameserver;
CREATE TABLE infrastructure_nameserver () INHERITS (infrastructure);
ALTER TABLE infrastructure_nameserver ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_warez;
CREATE TABLE infrastructure_warez () INHERITS (infrastructure);
ALTER TABLE infrastructure_warez ADD PRIMARY KEY (id);

DROP TABLE IF EXISTS infrastructure_passive;
CREATE TABLE infrastructure_passive () INHERITS (infrastructure);
ALTER TABLE infrastructure_passive ADD PRIMARY KEY (id);
