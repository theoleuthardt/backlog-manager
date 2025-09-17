ROLLBACK;

BEGIN;

CREATE SCHEMA IF NOT EXISTS backlogmanagerdb;

CREATE TABLE IF NOT EXISTS backlogmanagerdb."Users" (
    "UserID" BIGSERIAL PRIMARY KEY,
    "Username" VARCHAR(50) NOT NULL UNIQUE,
    "Email" VARCHAR(255) NOT NULL UNIQUE,
    "PasswordHash" VARCHAR(255) NOT NULL,
    "CreatedAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS backlogmanagerdb."Games" (
    "GameID" BIGSERIAL PRIMARY KEY,
    "Title" VARCHAR(255) NOT NULL,
    "Genre" VARCHAR(100) NOT NULL,
    "Platform" VARCHAR(100) NOT NULL,
    "ReleaseDate" DATE,
    "ImageLink" TEXT,
    "HowLongToBeat" INTEGER[] -- Array für verschiedene Spielzeiten (Main, Extras, Completionist)
);

CREATE TABLE IF NOT EXISTS backlogmanagerdb."Categories" (
    "CategoryID" BIGSERIAL PRIMARY KEY,
    "UserID" BIGINT NOT NULL,
    "CategoryName" VARCHAR(100) NOT NULL,
    "Color" VARCHAR(7) NOT NULL DEFAULT '#000000',
    "Description" TEXT DEFAULT 'No description',
    "CreatedAt" TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("UserID") REFERENCES backlogmanagerdb."Users"("UserID") 
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS backlogmanagerdb."BacklogEntries" (
    "BacklogEntryID" BIGSERIAL PRIMARY KEY,
    "UserID" BIGINT NOT NULL,
    "GameID" BIGINT NOT NULL,
    "Status" VARCHAR(20) NOT NULL CHECK ("Status" IN ('Not Started', 'In Progress', 'Completed', 'On Hold', 'Dropped')),
    "Owned" BOOLEAN NOT NULL DEFAULT FALSE,
    "Interest" INTEGER NOT NULL CHECK ("Interest" >= 1 AND "Interest" <= 10),
    "ReviewNote" TEXT,
    "AddedAt" TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    "CompletedAt" TIMESTAMP WITHOUT TIME ZONE,
    FOREIGN KEY ("UserID") REFERENCES backlogmanagerdb."Users"("UserID") 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY ("GameID") REFERENCES backlogmanagerdb."Games"("GameID") 
        ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE("UserID", "GameID")
);

-- Junction Table für Many-to-Many Beziehung zwischen Categories und Backlog Entries
CREATE TABLE IF NOT EXISTS backlogmanagerdb."CategoryBacklogEntries" (
    "CategoryID" BIGINT NOT NULL,
    "BacklogEntryID" BIGINT NOT NULL,
    PRIMARY KEY ("CategoryID", "BacklogEntryID"),
    FOREIGN KEY ("CategoryID") REFERENCES backlogmanagerdb."Categories"("CategoryID") 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY ("BacklogEntryID") REFERENCES backlogmanagerdb."BacklogEntries"("BacklogEntryID") 
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_categories_userid ON backlogmanagerdb."Categories"("UserID");
CREATE INDEX IF NOT EXISTS idx_backlogentries_userid ON backlogmanagerdb."BacklogEntries"("UserID");
CREATE INDEX IF NOT EXISTS idx_backlogentries_gameid ON backlogmanagerdb."BacklogEntries"("GameID");
CREATE INDEX IF NOT EXISTS idx_backlogentries_status ON backlogmanagerdb."BacklogEntries"("Status");

-- Trigger um CompletedAt automatisch zu setzen wenn Status auf 'Completed' geändert wird
CREATE OR REPLACE FUNCTION backlogmanagerdb.update_completed_at()
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
    BEFORE UPDATE ON backlogmanagerdb."BacklogEntries"
    FOR EACH ROW
    EXECUTE FUNCTION backlogmanagerdb.update_completed_at();

COMMIT;