SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_domain_botnet;
CREATE INDEX idx_domain_botnet ON domain_botnet (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_domain_malware;
CREATE INDEX idx_domain_malware ON domain_malware (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_domain_fastflux;
CREATE INDEX idx_domain_fastflux ON domain_fastflux (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_domain_whitelist;
CREATE INDEX idx_domain_whitelist ON domain_whitelist (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_domain_suspicious;
CREATE INDEX idx_domain_suspicious ON domain_suspicious (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_domain_phishing;
CREATE INDEX idx_domain_phishing ON domain_phishing (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_domain_nameserver;
CREATE INDEX idx_domain_nameserver ON domain_nameserver (reporttime, confidence, address);
