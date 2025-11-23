ROLLBACK;

BEGIN;

CREATE SCHEMA IF NOT EXISTS "blm-system";

CREATE TABLE IF NOT EXISTS "blm-system"."Users"(
    "UserID" BIGSERIAL PRIMARY KEY,
    "Username" VARCHAR(50) NOT NULL UNIQUE,
    "Email" VARCHAR(255) NOT NULL UNIQUE,
    "PasswordHash" VARCHAR(255) NOT NULL,
    "SteamId" VARCHAR(255),
    "CreatedAt" TIMESTAMP NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    "UpdatedAt" TIMESTAMP NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP)
);


CREATE TABLE IF NOT EXISTS "blm-system"."Categories" (
    "CategoryID"   BIGSERIAL PRIMARY KEY,
    "UserID"       BIGINT NOT NULL,
    "CategoryName" VARCHAR(100) NOT NULL,
    "Color"        VARCHAR(7) NOT NULL         DEFAULT '#000000',
    "Description"  TEXT                        DEFAULT 'No description',
    "CreatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    "UpdatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    FOREIGN KEY ("UserID") REFERENCES "blm-system"."Users"("UserID")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "blm-system"."BacklogEntries" (
    "BacklogEntryID" BIGSERIAL PRIMARY KEY,
    "UserID"         BIGINT NOT NULL,
    "Title"          VARCHAR(255) NOT NULL,
    "Genre"          VARCHAR(100) NOT NULL,
    "Platform"       VARCHAR(100) NOT NULL,
    "ReleaseDate"    DATE,
    "ImageLink"      TEXT,
    "MainTime"       NUMERIC(10,2),
    "MainPlusExtraTime" NUMERIC(10,2),
    "CompletionTime" NUMERIC(10,2),
    "Status"         VARCHAR(20) NOT NULL CHECK ("Status" IN ('Not Started', 'In Progress', 'Completed', 'On Hold', 'Dropped')),
    "Owned"          BOOLEAN NOT NULL            DEFAULT FALSE,
    "Interest"       INTEGER NOT NULL CHECK ("Interest" >= 1 AND "Interest" <= 10),
    "ReviewStars"    INTEGER,
    "Review"         TEXT,
    "Note"           TEXT,
    "CompletedAt"    TIMESTAMP WITHOUT TIME ZONE,
    "CreatedAt"      TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    "UpdatedAt"      TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    FOREIGN KEY ("UserID") REFERENCES "blm-system"."Users"("UserID")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "blm-system"."CategoryBacklogEntries" (
    "CategoryID" BIGINT     NOT NULL,
    "BacklogEntryID" BIGINT NOT NULL,
    "CreatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    "UpdatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    PRIMARY KEY ("CategoryID", "BacklogEntryID"),
    FOREIGN KEY ("CategoryID") REFERENCES "blm-system"."Categories"("CategoryID")
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY ("BacklogEntryID") REFERENCES "blm-system"."BacklogEntries"("BacklogEntryID")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_categories_userid ON "blm-system"."Categories"("UserID");
CREATE INDEX IF NOT EXISTS idx_backlogentries_userid ON "blm-system"."BacklogEntries"("UserID");
CREATE INDEX IF NOT EXISTS idx_backlogentries_status ON "blm-system"."BacklogEntries"("Status");

-- set CompletedAt automatically if status is set to 'Completed'
CREATE OR REPLACE FUNCTION "blm-system".update_completed_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW."Status" = 'Completed' AND OLD."Status" != 'Completed' THEN
        NEW."CompletedAt" = CURRENT_TIMESTAMP;
    ELSIF NEW."Status" != 'Completed' THEN
        NEW."CompletedAt" = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_completed_at
    BEFORE UPDATE ON "blm-system"."BacklogEntries"
    FOR EACH ROW
    EXECUTE FUNCTION "blm-system".update_completed_at();

-- set default schema
ALTER DATABASE "backlog-manager-db" SET search_path = "blm-system", public;

COMMIT;