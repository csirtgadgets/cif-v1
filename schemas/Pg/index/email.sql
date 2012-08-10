SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_email_phishing;
CREATE INDEX idx_email_phishing ON email_phishing (detecttime, confidence, guid, hash);

DROP INDEX IF EXISTS idx_email_registrant;
CREATE INDEX idx_email_registrant ON email_registrant (detecttime, confidence, guid, hash);

DROP INDEX IF EXISTS idx_email_whitelist;
CREATE INDEX idx_email_whitelist ON email_whitelist (detecttime, confidence, guid, hash);

DROP INDEX IF EXISTS idx_email_suspicious;
CREATE INDEX idx_email_suspicious ON email_suspicious (detecttime, confidence, guid, hash);