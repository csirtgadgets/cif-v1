SET default_tablespace = 'index';

-- DROP INDEX IF EXISTS idx_infrastructure_botnet;
-- CREATE INDEX idx_infrastructure_botnet ON infrastructure_botnet (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_malware;
-- CREATE INDEX idx_infrastructure_malware ON infrastructure_malware (detecttime, confidence);

-- DROP INDEX IF EXISTS idx_infrastructure_fastflux;
-- CREATE INDEX idx_infrastructure_fastflux ON infrastructure_fastflux (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_whitelist;
-- CREATE INDEX idx_infrastructure_whitelist ON infrastructure_whitelist (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_suspicious;
-- CREATE INDEX idx_infrastructure_suspicious ON infrastructure_suspicious (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_phishing;
-- CREATE INDEX idx_infrastructure_phishing ON infrastructure_phishing (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_nameserver;
-- CREATE INDEX idx_infrastructure_nameserver ON infrastructure_nameserver (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_warez;
-- CREATE INDEX idx_infrastructure_warez ON infrastructure_warez (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_scan;
-- CREATE INDEX idx_infrastructure_scan ON infrastructure_scan (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_spam;
-- CREATE INDEX idx_infrastructure_spam ON infrastructure_spam (detecttime, confidence, guid);

-- DROP INDEX IF EXISTS idx_infrastructure_passive;
-- CREATE INDEX idx_infrastructure_passive ON infrastructure_passive (detecttime, confidence, guid);