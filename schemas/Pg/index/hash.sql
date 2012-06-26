SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_hash_md5;
CREATE INDEX idx_hash_md5 ON hash_md5 (hash, reporttime DESC, confidence DESC);

DROP INDEX IF EXISTS idx_hash_sha1;
CREATE INDEX idx_hash_sha1 ON hash_sha1 (hash, reporttime DESC, confidence DESC);

DROP INDEX IF EXISTS idx_hash_uuid;
CREATE INDEX idx_hash_uuid ON hash_uuid (hash, reporttime DESC, confidence DESC);