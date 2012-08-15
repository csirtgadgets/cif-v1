SET default_tablespace = 'archive';
DROP TABLE IF EXISTS apikeys_groups;
DROP TABLE IF EXISTS apikeys_restrictions;
DROP TABLE IF EXISTS apikeys;
CREATE TABLE apikeys (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid not null,
    uuid_alias text NOT NULL,
    description text,
    parentid uuid null,
    revoked bool default null,
    restricted_access bool default false,
    write bool default null,
    created timestamp with time zone DEFAULT NOW(),
    expires timestamp with time zone,
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

CREATE TABLE apikeys_restrictions (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid references apikeys(uuid) on delete cascade not null,
    access varchar(40) not null,
    created timestamp with time zone DEFAULT NOW(),
    UNIQUE(uuid,access)
);
