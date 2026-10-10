ROLLBACK;

BEGIN;

CREATE SCHEMA IF NOT EXISTS "blm-system";

CREATE TABLE IF NOT EXISTS "blm-system"."Users"(
    "UserID" BIGSERIAL PRIMARY KEY,
    "Username" VARCHAR(50) NOT NULL UNIQUE,
    "Email" VARCHAR(255) NOT NULL UNIQUE,
    "PasswordHash" VARCHAR(255) NOT NULL,
    "SteamId" VARCHAR(255),
    "SteamApiKeyEncrypted" TEXT,
    "SteamFamilyIds" TEXT,
    "IgdbCredentialsEncrypted" TEXT,
    "SteamGridDbApiKeyEncrypted" TEXT,
    "DiscordWebhookUrlEncrypted" TEXT,
    "SteamAutoImportEnabled" BOOLEAN NOT NULL DEFAULT FALSE,
    "SteamWishlistImportedAt" TIMESTAMP,
    "IsAdmin" BOOLEAN NOT NULL DEFAULT FALSE,
    "TotpSecretEncrypted" TEXT,
    "TotpEnabled" BOOLEAN NOT NULL DEFAULT FALSE,
    "TokenVersion" INTEGER NOT NULL DEFAULT 0,
    "FailedLoginAttempts" INTEGER NOT NULL DEFAULT 0,
    "LockedUntil" TIMESTAMP,
    "SetupCompleted" BOOLEAN NOT NULL DEFAULT FALSE,
    "DefaultSort" VARCHAR(20) NOT NULL DEFAULT 'status',
    "Theme" VARCHAR(50) NOT NULL DEFAULT 'dark',
    "CustomThemes" JSONB NOT NULL DEFAULT '[]'::jsonb,
    "CreatedAt" TIMESTAMP NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    "UpdatedAt" TIMESTAMP NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP)
);

CREATE TABLE IF NOT EXISTS "blm-system"."UserBackupCodes" (
    "BackupCodeID" BIGSERIAL PRIMARY KEY,
    "UserID"       BIGINT NOT NULL,
    "CodeHash"     VARCHAR(255) NOT NULL,
    "CreatedAt"    TIMESTAMP NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    FOREIGN KEY ("UserID") REFERENCES "blm-system"."Users"("UserID")
    ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE IF NOT EXISTS "blm-system"."Spaces" (
    "SpaceID"   BIGSERIAL PRIMARY KEY,
    "CreatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    "UpdatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP)
);

CREATE TABLE IF NOT EXISTS "blm-system"."SpaceMembers" (
    "SpaceID"   BIGINT NOT NULL,
    "UserID"    BIGINT NOT NULL UNIQUE,
    "Status"    VARCHAR(10) NOT NULL CHECK ("Status" IN ('invited', 'active')),
    "CreatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    "UpdatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    PRIMARY KEY ("SpaceID", "UserID"),
    FOREIGN KEY ("SpaceID") REFERENCES "blm-system"."Spaces"("SpaceID")
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY ("UserID") REFERENCES "blm-system"."Users"("UserID")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "blm-system"."Categories" (
    "CategoryID"   BIGSERIAL PRIMARY KEY,
    "UserID"       BIGINT NOT NULL,
    "SpaceID"      BIGINT REFERENCES "blm-system"."Spaces"("SpaceID")
        ON DELETE CASCADE ON UPDATE CASCADE,
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
    "SpaceID"        BIGINT REFERENCES "blm-system"."Spaces"("SpaceID")
        ON DELETE CASCADE ON UPDATE CASCADE,
    "Title"          VARCHAR(255) NOT NULL,
    "Genre"          VARCHAR(100) NOT NULL,
    "Platform"       VARCHAR(100) NOT NULL,
    "ReleaseDate"    DATE,
    "ImageLink"      TEXT,
    "Description"    TEXT,
    "TrailerLink"    TEXT,
    "MainTime"       NUMERIC(10,2),
    "MainPlusExtraTime" NUMERIC(10,2),
    "CompletionTime" NUMERIC(10,2),
    "Playtime"       NUMERIC(10,2),
    "SteamAppId"     BIGINT,
    "SteamWishlistImport" BOOLEAN NOT NULL      DEFAULT FALSE,
    "Status"         VARCHAR(20) NOT NULL,
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

CREATE UNIQUE INDEX IF NOT EXISTS "BacklogEntries_UserID_SteamAppId_key"
    ON "blm-system"."BacklogEntries"("UserID", "SteamAppId") WHERE "SpaceID" IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "BacklogEntries_SpaceID_SteamAppId_key"
    ON "blm-system"."BacklogEntries"("SpaceID", "SteamAppId") WHERE "SpaceID" IS NOT NULL;

CREATE TABLE IF NOT EXISTS "blm-system"."SpaceEntryMemberData" (
    "BacklogEntryID" BIGINT NOT NULL,
    "UserID"         BIGINT NOT NULL,
    "Playtime"       NUMERIC(10,2),
    "ReviewStars"    INTEGER,
    "Review"         TEXT,
    PRIMARY KEY ("BacklogEntryID", "UserID"),
    FOREIGN KEY ("BacklogEntryID") REFERENCES "blm-system"."BacklogEntries"("BacklogEntryID")
        ON DELETE CASCADE ON UPDATE CASCADE,
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

CREATE TABLE IF NOT EXISTS "blm-system"."SteamAppInfo" (
    "SteamAppId"  BIGINT PRIMARY KEY,
    "Name"        VARCHAR(255) NOT NULL,
    "HeaderImage" TEXT,
    "ResolvedAt"  TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS "blm-system"."GamePrices" (
    "SteamAppId"            BIGINT PRIMARY KEY,
    "CheapsharkGameId"      BIGINT,
    "Deals"                 JSON,
    "CheapestPriceEver"     NUMERIC(10,2),
    "CheapestPriceEverDate" DATE,
    "OnSale"                BOOLEAN NOT NULL DEFAULT FALSE,
    "CheckedAt"             TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS "blm-system"."UserGamePriceAlerts" (
    "UserID"           BIGINT NOT NULL,
    "SteamAppId"       BIGINT NOT NULL,
    "LastAlertedPrice" NUMERIC(10,2) NOT NULL,
    "UpdatedAt"        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    PRIMARY KEY ("UserID", "SteamAppId"),
    FOREIGN KEY ("UserID") REFERENCES "blm-system"."Users"("UserID")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "blm-system"."CustomStatuses" (
    "StatusID"  BIGSERIAL PRIMARY KEY,
    "UserID"    BIGINT NOT NULL,
    "SpaceID"   BIGINT REFERENCES "blm-system"."Spaces"("SpaceID")
        ON DELETE CASCADE ON UPDATE CASCADE,
    "Name"      VARCHAR(20) NOT NULL,
    "CreatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    "UpdatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT DATE_TRUNC('minute', CURRENT_TIMESTAMP),
    FOREIGN KEY ("UserID") REFERENCES "blm-system"."Users"("UserID")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "CustomStatuses_UserID_Name_key"
    ON "blm-system"."CustomStatuses"("UserID", "Name") WHERE "SpaceID" IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "CustomStatuses_SpaceID_Name_key"
    ON "blm-system"."CustomStatuses"("SpaceID", "Name") WHERE "SpaceID" IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_categories_userid ON "blm-system"."Categories"("UserID");
CREATE TABLE IF NOT EXISTS "blm-system"."UserBackups" (
    "BackupID"      BIGSERIAL PRIMARY KEY,
    "UserID"        BIGINT NOT NULL,
    "Kind"          VARCHAR(20) NOT NULL,
    "Name"          VARCHAR(60),
    "ContentHash"   VARCHAR(64) NOT NULL,
    "EntryCount"    INTEGER NOT NULL,
    "CategoryCount" INTEGER NOT NULL,
    "Payload"       JSONB NOT NULL,
    "CreatedAt"     TIMESTAMP NOT NULL DEFAULT timezone('utc', clock_timestamp()),
    FOREIGN KEY ("UserID") REFERENCES "blm-system"."Users"("UserID")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_userbackups_userid ON "blm-system"."UserBackups"("UserID");

CREATE INDEX IF NOT EXISTS idx_backlogentries_userid ON "blm-system"."BacklogEntries"("UserID");
CREATE INDEX IF NOT EXISTS idx_backlogentries_spaceid ON "blm-system"."BacklogEntries"("SpaceID");
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

CREATE OR REPLACE TRIGGER trigger_update_completed_at
    BEFORE UPDATE ON "blm-system"."BacklogEntries"
    FOR EACH ROW
    EXECUTE FUNCTION "blm-system".update_completed_at();

-- set default schema
ALTER DATABASE "backlog-manager-db" SET search_path = "blm-system", public;

COMMIT;