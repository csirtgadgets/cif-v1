SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_url_botnet;
CREATE INDEX idx_url_botnet ON url_botnet (detecttime DESC, confidence DESC, guid, hash);

DROP INDEX IF EXISTS idx_url_malware;
CREATE INDEX idx_url_malware ON url_malware (detecttime DESC, confidence DESC, guid, hash);

DROP INDEX IF EXISTS idx_url_phishing;
CREATE INDEX idx_url_phishing ON url_phishing (detecttime DESC, confidence DESC, guid, hash);
