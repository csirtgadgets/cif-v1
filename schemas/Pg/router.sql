SET default_tablespace = 'archive';
DROP TABLE IF EXISTS apikeys_groups;
DROP TABLE IF EXISTS apikeys;
CREATE TABLE apikeys (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid not null,
    uuid_alias text NOT NULL,
    description text,
    parentid uuid null,
    revoked bool default null,
    access varchar(100) default 'all',
    write bool default null,
    created timestamp with time zone DEFAULT NOW(),
    UNIQUE(uuid)
);

CREATE TABLE apikeys_groups (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid references apikeys(uuid) on delete cascade not null,
    guid uuid not null,
    default_guid bool,
    created timestamp with time zone default now(),
    unique(uuid,guid)
);
