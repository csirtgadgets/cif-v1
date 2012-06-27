SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_infrastructure_botnet;
CREATE INDEX idx_infrastructure_botnet ON infrastructure_botnet (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_malware;
CREATE INDEX idx_infrastructure_malware ON infrastructure_malware (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_fastflux;
CREATE INDEX idx_infrastructure_fastflux ON infrastructure_fastflux (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_whitelist;
CREATE INDEX idx_infrastructure_whitelist ON infrastructure_whitelist (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_suspicious;
CREATE INDEX idx_infrastructure_suspicious ON infrastructure_suspicious (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_phishing;
CREATE INDEX idx_infrastructure_phishing ON infrastructure_phishing (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_nameserver;
CREATE INDEX idx_infrastructure_nameserver ON infrastructure_nameserver (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_warez;
CREATE INDEX idx_infrastructure_warez ON infrastructure_warez (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_scan;
CREATE INDEX idx_infrastructure_scan ON infrastructure_scan (reporttime, confidence, address);

DROP INDEX IF EXISTS idx_infrastructure_spam;
CREATE INDEX idx_infrastructure_spam ON infrastructure_spam (reporttime, confidence, address);
