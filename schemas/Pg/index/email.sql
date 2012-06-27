SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_email_phishing;
CREATE INDEX idx_email_phishing ON email_phishing (reporttime, confidence, hash);

DROP INDEX IF EXISTS idx_email_registrant;
CREATE INDEX idx_email_registrant ON email_registrant (reporttime, confidence, hash);
