set default_tablespace = archive;

DROP TYPE IF EXISTS severity;
DROP TYPE IF EXISTS restriction;

ALTER TABLE apikeys DROP COLUMN access;
ALTER TABLE apikeys ADD COLUMN restricted_access boolean default false;

CREATE TABLE apikeys_restrictions (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    uuid uuid references apikeys(uuid) on delete cascade not null,
    access varchar(40) not null,
    created timestamp with time zone DEFAULT NOW(),
    UNIQUE(uuid,access)
);