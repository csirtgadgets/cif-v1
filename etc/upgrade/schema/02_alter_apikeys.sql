set default_tablespace = archive;

ALTER TABLE apikeys DROP COLUMN access;
ALTER TABLE apikeys ADD COLUMN restricted_access boolean default false;
ALTER TABLE apikeys ADD COLUMN expires timestamp with time zone;

CREATE TABLE apikeys_restrictions (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid references apikeys(uuid) on delete cascade not null,
    access varchar(40) not null,
    created timestamp with time zone DEFAULT NOW(),
    UNIQUE(uuid,access)
);