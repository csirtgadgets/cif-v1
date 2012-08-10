SET default_tablespace = 'index';

DROP INDEX IF EXISTS idx_search;
CREATE INDEX idx_search ON search (detecttime DESC, confidence DESC, guid);
