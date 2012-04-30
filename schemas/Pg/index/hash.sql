SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_hash_query_md5;
DROP INDEX IF EXISTS idx_hash_created_md5;
CREATE INDEX idx_hash_query_md5 ON hash_md5 (hash, detecttime DESC, confidence DESC, id DESC);
CREATE INDEX idx_hash_created_md5 ON hash_md5 (created);

DROP INDEX IF EXISTS idx_hash_query_sha1;
DROP INDEX IF EXISTS idx_hash_created_sha1;
CREATE INDEX idx_hash_query_sha1 ON hash_sha1 (hash, detecttime DESC, confidence DESC, id DESC);
CREATE INDEX idx_hash_created_sha1 ON hash_sha1 (created);

DROP INDEX IF EXISTS idx_hash_query_uuid;
DROP INDEX IF EXISTS idx_hash_created_uuid;
CREATE INDEX idx_hash_query_uuid ON hash_uuid (hash, detecttime DESC, confidence DESC, id DESC);
CREATE INDEX idx_hash_created_uuid ON hash_uuid (created);