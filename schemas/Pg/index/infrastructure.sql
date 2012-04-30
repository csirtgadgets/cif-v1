SET default_tablespace = 'index';

CREATE INDEX idx_query_infrastructure ON infrastructure (address, detecttime DESC, confidence DESC);