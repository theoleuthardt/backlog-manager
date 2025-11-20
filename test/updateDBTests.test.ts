import { describe, it, expect, beforeAll, afterAll, beforeEach } from "vitest";
import { Pool } from "pg";
import {
  PostgreSqlContainer,
  type StartedPostgreSqlContainer,
} from "@testcontainers/postgresql";
import fs from "fs";
import path from "path";
import {
  createUser,
  createCategory,
  createBacklogEntry,
} from "~/server/db/CRUD/create";
import { getUserById, getBacklogEntryById } from "~/server/db/CRUD/read";
import {
  updateUser,
  updateCategory,
  updateBacklogEntry,
} from "~/server/db/CRUD/update";

describe("Database Update Operations", () => {
  let postgresContainer: StartedPostgreSqlContainer;
  let postgresPool: Pool;

  beforeAll(async () => {
    postgresContainer = await new PostgreSqlContainer("postgres:16")
      .withDatabase("backlog-manager-db")
      .withUsername("testuser")
      .withPassword("testpass")
      .start();

    postgresPool = new Pool({
      user: "testuser",
      password: "testpass",
      host: postgresContainer.getHost(),
      port: postgresContainer.getPort(),
      database: "backlog-manager-db",
    });

    const sql = fs.readFileSync(
      path.resolve(__dirname, "../postgres/backlogmanagerdb-init.sql"),
      "utf-8",
    );

    await postgresPool.query(sql);
  }, 60000);

  afterAll(async () => {
    await postgresPool.end();
    await postgresContainer.stop();
  });

  describe("User Update Operations", () => {
    let userId: number;

    beforeEach(async () => {
      await postgresPool.query(
        'TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE',
      );
      await createUser(postgresPool, {
        username: "John Doe",
        email: "john@doe.com",
        passwordHash: "oldpassword123",
      });
      userId = 1;
    });

    it("should update user with all fields", async () => {
      const updatedUser = await updateUser(postgresPool, {
        userId,
        username: "John Smith",
        email: "john@smith.com",
        passwordHash: "newpassword456",
      });

      expect(updatedUser.id).toBe(1);
      expect(updatedUser.name).toBe("John Smith");
      expect(updatedUser.email).toBe("john@smith.com");
      expect(updatedUser.passwordHash).toBe("newpassword456");
    });

    it("should update only username", async () => {
      const updatedUser = await updateUser(postgresPool, {
        userId,
        username: "Jane Doe",
        email: "john@doe.com",
        passwordHash: "oldpassword123",
      });

      expect(updatedUser.name).toBe("Jane Doe");
      expect(updatedUser.email).toBe("john@doe.com");
      expect(updatedUser.passwordHash).toBe("oldpassword123");
    });

    it("should update UpdatedAt timestamp", async () => {
      const originalUser = await getUserById(postgresPool, userId);

      await new Promise((resolve) => setTimeout(resolve, 1000));

      const updatedUser = await updateUser(postgresPool, {
        userId,
        username: "Updated Name",
        email: "john@doe.com",
        passwordHash: "oldpassword123",
      });

      expect(new Date(updatedUser.UpdatedAt).getTime()).toBeGreaterThanOrEqual(
        new Date(originalUser.UpdatedAt).getTime(),
      );
    });
  });

  describe("Category Update Operations", () => {
    let categoryId: number;

    beforeEach(async () => {
      await postgresPool.query(
        'TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE',
      );
      await postgresPool.query(
        'TRUNCATE TABLE "blm-system"."Categories" RESTART IDENTITY CASCADE',
      );
      await createUser(postgresPool, {
        username: "John Doe",
        email: "john@doe.com",
        passwordHash: "password123",
      });
      await createCategory(postgresPool, {
        userId: 1,
        categoryName: "Action",
        color: "#FF0000",
        description: "Action games",
      });
      categoryId = 1;
    });

    it("should update category with all fields", async () => {
      const updatedCategory = await updateCategory(postgresPool, {
        categoryId,
        categoryName: "Adventure",
        color: "#00FF00",
        description: "Adventure games description",
      });

      expect(updatedCategory.categoryID).toBe(1);
      expect(updatedCategory.name).toBe("Adventure");
      expect(updatedCategory.color).toBe("#00FF00");
      expect(updatedCategory.description).toBe("Adventure games description");
    });

    it("should update only category name", async () => {
      const updatedCategory = await updateCategory(postgresPool, {
        categoryId,
        categoryName: "RPG",
        color: "#FF0000",
        description: "Action games",
      });

      expect(updatedCategory.name).toBe("RPG");
      expect(updatedCategory.color).toBe("#FF0000");
      expect(updatedCategory.description).toBe("Action games");
    });

    it("should update description to empty string", async () => {
      const updatedCategory = await updateCategory(postgresPool, {
        categoryId,
        categoryName: "Action",
        color: "#FF0000",
        description: "",
      });

      expect(updatedCategory.description).toBe("");
    });
  });

  describe("Backlog Entry Update Operations", () => {
    let backlogEntryId: number;

    beforeEach(async () => {
      await postgresPool.query(
        'TRUNCATE TABLE "blm-system"."Users" RESTART IDENTITY CASCADE',
      );
      await postgresPool.query(
        'TRUNCATE TABLE "blm-system"."BacklogEntries" RESTART IDENTITY CASCADE',
      );

      await createUser(postgresPool, {
        username: "John Doe",
        email: "john@doe.com",
        passwordHash: "password123",
      });
      await createBacklogEntry(postgresPool, {
        userId: 1,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "Not Started",
        owned: false,
        interest: 3,
        note: "Initial note",
      });
      backlogEntryId = 1;
    });

    it("should update backlog entry with all fields", async () => {
      const updatedEntry = await updateBacklogEntry(postgresPool, {
        backlogEntryId,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "Completed",
        owned: true,
        interest: 5,
        releaseDate: new Date("2024-01-15"),
        imageLink: "image.jpg",
        mainTime: 50,
        mainPlusExtraTime: 100,
        completionTime: 150,
        reviewStars: 5,
        review: "Amazing game!",
        note: "Finished after 100 hours",
      });

      expect(updatedEntry.backlogEntryID).toBe(1);
      expect(updatedEntry.title).toBe("Elden Ring");
      expect(updatedEntry.genre).toBe("RPG");
      expect(updatedEntry.platform).toBe("PC");
      expect(updatedEntry.status).toBe("Completed");
      expect(updatedEntry.owned).toBe(true);
      expect(updatedEntry.interest).toBe(5);
      expect(updatedEntry.reviewStars).toBe(5);
      expect(updatedEntry.review).toBe("Amazing game!");
      expect(updatedEntry.note).toBe("Finished after 100 hours");
    });

    it("should update status from Not Started to In Progress", async () => {
      const updatedEntry = await updateBacklogEntry(postgresPool, {
        backlogEntryId,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "In Progress",
        owned: false,
        interest: 3,
      });

      expect(updatedEntry.status).toBe("In Progress");
      expect(updatedEntry.reviewStars).toBeUndefined();
      expect(updatedEntry.review).toBeUndefined();
    });

    it("should update owned status", async () => {
      const updatedEntry = await updateBacklogEntry(postgresPool, {
        backlogEntryId,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "Not Started",
        owned: true,
        interest: 3,
      });

      expect(updatedEntry.owned).toBe(true);
    });

    it("should update interest level", async () => {
      const updatedEntry = await updateBacklogEntry(postgresPool, {
        backlogEntryId,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "Not Started",
        owned: false,
        interest: 5,
      });

      expect(updatedEntry.interest).toBe(5);
    });

    it("should add review and rating to entry without them", async () => {
      const updatedEntry = await updateBacklogEntry(postgresPool, {
        backlogEntryId,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "Completed",
        owned: true,
        interest: 5,
        reviewStars: 4,
        review: "Good game but has some flaws",
        note: "Completed main story",
      });

      expect(updatedEntry.status).toBe("Completed");
      expect(updatedEntry.reviewStars).toBe(4);
      expect(updatedEntry.review).toBe("Good game but has some flaws");
      expect(updatedEntry.note).toBe("Completed main story");
    });

    it("should clear optional fields", async () => {
      await updateBacklogEntry(postgresPool, {
        backlogEntryId,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "Completed",
        owned: true,
        interest: 5,
        reviewStars: 5,
        review: "Great game",
        note: "Some notes",
      });

      const updatedEntry = await updateBacklogEntry(postgresPool, {
        backlogEntryId,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "Completed",
        owned: true,
        interest: 5,
      });

      expect(updatedEntry.reviewStars).toBeUndefined();
      expect(updatedEntry.review).toBeUndefined();
      expect(updatedEntry.note).toBeUndefined();
    });

    it("should update UpdatedAt timestamp", async () => {
      const originalEntry = await getBacklogEntryById(
        postgresPool,
        backlogEntryId,
      );

      await new Promise((resolve) => setTimeout(resolve, 1000));

      const updatedEntry = await updateBacklogEntry(postgresPool, {
        backlogEntryId,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "In Progress",
        owned: false,
        interest: 4,
      });

      expect(new Date(updatedEntry.UpdatedAt).getTime()).toBeGreaterThanOrEqual(
        new Date(originalEntry.UpdatedAt).getTime(),
      );
    });
  });
});
