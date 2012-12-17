SET default_tablespace = 'index';

-- MD5 table
DROP INDEX IF EXISTS idx_hash_md5_1;
CREATE INDEX idx_hash_md5 ON hash_md5 (hash,confidence);

DROP INDEX IF EXISTS idx_hash_md5_2;
CREATE INDEX idx_hash_md5_2 ON hash_md5 (uuid);

DROP INDEX IF EXISTS idx_hash_md5_3;
CREATE INDEX idx_hash_md5_3 ON hash_md5 (reporttime);

-- SHA1 Table
DROP INDEX IF EXISTS idx_hash_sha1_1;
CREATE INDEX idx_hash_sha1_1 ON hash_sha1 (hash,confidence);

DROP INDEX IF EXISTS idx_hash_sha1_2;
CREATE INDEX idx_hash_sha1_2 ON hash_sha1 (uuid);

DROP INDEX IF EXISTS idx_hash_sha1_3;
CREATE INDEX idx_hash_sha1_3 ON hash_sha1 (reporttime);

--UUID table
DROP INDEX IF EXISTS idx_hash_uuid_1;
CREATE INDEX idx_hash_uuid_1 ON hash_uuid (hash,confidence);

DROP INDEX IF EXISTS idx_hash_uuid_2;
CREATE INDEX idx_hash_uuid_2 ON hash_uuid (uuid);

DROP INDEX IF EXISTS idx_hash_uuid_3;
CREATE INDEX idx_hash_uuid_3 ON hash_uuid (reporttime);