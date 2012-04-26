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

CREATE TABLE infrastructure_botnet () INHERITS (infrastructure);
ALTER TABLE infrastructure_botnet ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_malware () INHERITS (infrastructure);
ALTER TABLE infrastructure_malware ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_whitelist () INHERITS (infrastructure);
ALTER TABLE infrastructure_whitelist ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_scan () INHERITS (infrastructure);
ALTER TABLE infrastructure_scan ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_spam () INHERITS (infrastructure);
ALTER TABLE infrastructure_spam ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_network () INHERITS (infrastructure);
ALTER TABLE infrastructure_network ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_suspicious () INHERITS (infrastructure);
ALTER TABLE infrastructure_suspicious ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_phishing () INHERITS (infrastructure);
ALTER TABLE infrastructure_phishing ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_search () INHERITS (infrastructure);
ALTER TABLE infrastructure_search ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_passivedns () INHERITS (infrastructure);
ALTER TABLE infrastructure_passivedns ADD PRIMARY KEY (id);

CREATE TABLE infrastructure_warez () INHERITS (infrastructure);
ALTER TABLE infrastructure_warez ADD PRIMARY KEY (id);