SET default_tablespace = 'index';

-- MD5 table
DROP INDEX IF EXISTS idx_hash_md5;
CREATE INDEX idx_hash_md5 ON hash_md5 (uuid,hash,reporttime,confidence);

DROP INDEX IF EXISTS idx_hash_md5_uuid;
CREATE INDEX idx_hash_md5_uuid ON hash_md5 (uuid,hash,reporttime,confidence);

-- SHA1 Table
DROP INDEX IF EXISTS idx_hash_sha1;
CREATE INDEX idx_hash_sha1_1 ON hash_sha1 (hash,confidence);

DROP INDEX IF EXISTS idx_hash_sha1_2;
CREATE INDEX idx_hash_sha1_2 ON hash_sha1 (uuid);

DROP INDEX IF EXISTS idx_hash_sha1_uuid;
CREATE INDEX idx_hash_sha1_uuid ON hash_sha1 (uuid,hash,reporttime,confidence);

--UUID table
DROP INDEX IF EXISTS idx_hash_uuid;
CREATE INDEX idx_hash_uuid ON hash_uuid (uuid,hash,reporttime,confidence);

DROP INDEX IF EXISTS idx_hash_uuid_uuid;
CREATE INDEX idx_hash_uuid_uuid ON hash_uuid (uuid,hash,reporttime,confidence);