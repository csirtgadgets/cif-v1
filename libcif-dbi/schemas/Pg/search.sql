SET default_tablespace = 'index';
DROP TABLE IF EXISTS search CASCADE;
CREATE TABLE search (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid NOT NULL,
    guid uuid,
    term text,
    confidence REAL,
    reporttime timestamp with time zone DEFAULT NOW(),
    created timestamp with time zone DEFAULT NOW()
);

-- upgrade from v1-FINAL
-- ALTER TABLE search RENAME COLUMN hash TO term;
-- ALTER TABLE search ALTER COLUMN term TYPE text;