SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_infrastructure_botnet;
CREATE INDEX idx_infrastructure_botnet ON infrastructure_botnet (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_malware;
CREATE INDEX idx_infrastructure_malware ON infrastructure_malware (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_fastflux;
CREATE INDEX idx_infrastructure_fastflux ON infrastructure_fastflux (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_whitelist;
CREATE INDEX idx_infrastructure_whitelist ON infrastructure_whitelist (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_suspicious;
CREATE INDEX idx_infrastructure_suspicious ON infrastructure_suspicious (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_phishing;
CREATE INDEX idx_infrastructure_phishing ON infrastructure_phishing (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_nameserver;
CREATE INDEX idx_infrastructure_nameserver ON infrastructure_nameserver (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_warez;
CREATE INDEX idx_infrastructure_warez ON infrastructure_warez (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_scan;
CREATE INDEX idx_infrastructure_scan ON infrastructure_scan (detecttime DESC, confidence DESC, guid, address);

DROP INDEX IF EXISTS idx_infrastructure_spam;
CREATE INDEX idx_infrastructure_spam ON infrastructure_spam (detecttime DESC, confidence DESC, guid, address);
