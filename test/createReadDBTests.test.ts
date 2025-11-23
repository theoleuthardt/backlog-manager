import { describe, it, expect, beforeAll, afterAll } from "vitest";
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
  addCategoryToBacklogEntry,
} from "~/server/db/CRUD/create";
import {
  getAllUsers,
  getUserById,
  getUserByUsername,
  getUserByEmail,
  getCategoriesByUser,
  getBacklogEntriesByUser,
  getBacklogEntryById,
  getBacklogEntriesByStatus,
  getCategoriesForBacklogEntry,
  getBacklogEntriesForCategory,
} from "~/server/db/CRUD/read";

describe("Database Read Operations", () => {
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

    await createUser(postgresPool, {
      username: "John Doe",
      email: "john@doe",
      passwordHash: "1234567890",
    });
    await createUser(postgresPool, {
      username: "Jane Doe",
      email: "jane@doe",
      passwordHash: "1234567890",
    });

    await createCategory(postgresPool, {
      userId: 1,
      categoryName: "Action",
      color: "#FF0000",
      description: "A game with action and adventure",
    });
    await createCategory(postgresPool, {
      userId: 1,
      categoryName: "Adventure",
      color: "#00FF00",
    });
    await createCategory(postgresPool, {
      userId: 2,
      categoryName: "Indie",
      color: "#0000FF",
    });

    await createBacklogEntry(postgresPool, {
      userId: 1,
      title: "Elden Ring",
      genre: "RPG",
      platform: "PC",
      status: "Not Started",
      owned: true,
      interest: 2,
      releaseDate: new Date(),
      imageLink: "Pictures/EldenRing.jpg",
      mainTime: 50,
      mainPlusExtraTime: 100,
      completionTime: 150,
      reviewStars: 4,
      review: "This is a review",
      note: "This is a note",
    });
    await createBacklogEntry(postgresPool, {
      userId: 1,
      title: "Hollow Knight",
      genre: "Metroidvania",
      platform: "PC",
      status: "In Progress",
      owned: false,
      interest: 3,
    });
    await createBacklogEntry(postgresPool, {
      userId: 2,
      title: "Elden Ring",
      genre: "RPG",
      platform: "PC",
      status: "Completed",
      owned: true,
      interest: 7,
    });

    await addCategoryToBacklogEntry(postgresPool, {
      categoryId: 1,
      backlogEntryId: 1,
    });
    await addCategoryToBacklogEntry(postgresPool, {
      categoryId: 2,
      backlogEntryId: 1,
    });
  }, 60000);

  afterAll(async () => {
    await postgresPool.end();
    await postgresContainer.stop();
  });

  describe("User Read Operations", () => {
    const now = new Date();
    now.setHours(now.getHours() - 2);
    now.setSeconds(0, 0);

    it("should get all users", async () => {
      const users = await getAllUsers(postgresPool);
      expect(users).toHaveLength(2);
      expect(users[0]!.name).toBe("John Doe");
      expect(users[1]!.name).toBe("Jane Doe");
    });

    it("should get user by id", async () => {
      const user = await getUserById(postgresPool, 1);
      expect(user).toMatchObject({
        id: 1,
        name: "John Doe",
        email: "john@doe",
        passwordHash: "1234567890",
      });
    });

    it("should get user by username", async () => {
      const user = await getUserByUsername(postgresPool, "Jane Doe");
      expect(user?.name).toBe("Jane Doe");
      expect(user?.email).toBe("jane@doe");
    });

    it("should get user by email", async () => {
      const userJohn = await getUserByEmail(postgresPool, "john@doe");
      expect(userJohn).not.toBeNull();
      expect(userJohn?.Username).toBe("John Doe");
      expect(userJohn?.Email).toBe("john@doe");
  
      const userJane = await getUserByEmail(postgresPool, "jane@doe");
      expect(userJane).not.toBeNull();
      expect(userJane?.Username).toBe("Jane Doe");
      expect(userJane?.Email).toBe("jane@doe");
    });

    it("should return undefined for non-existent email", async () => {
      const user = await getUserByEmail(postgresPool, "nonexistent@example.com");
      expect(user).toBeUndefined();
    });
  });

  describe("Category Read Operations", () => {
    it("should get categories by user", async () => {
      const categories = await getCategoriesByUser(postgresPool, 1);
      expect(categories).toHaveLength(2);
      expect(categories[0]!.categoryID).toBe(1);
      expect(categories[0]!.userID).toBe(1);
      expect(categories[0]!.name).toBe("Action");
      expect(categories[0]!.color).toBe("#FF0000");
      expect(categories[0]!.description).toBe(
        "A game with action and adventure",
      );
    });

    it("should get categories for different user", async () => {
      const categories = await getCategoriesByUser(postgresPool, 2);
      expect(categories).toHaveLength(1);
      expect(categories[0]!.name).toBe("Indie");
    });
  });

  describe("Backlog Entry Read Operations", () => {
    const now = new Date();
    now.setHours(now.getHours() - 2);
    now.setSeconds(0, 0);

    it("should get backlog entries by user", async () => {
      const entries = await getBacklogEntriesByUser(postgresPool, 1);
      expect(entries).toHaveLength(2);

      const entry = entries[0];
      expect(entry).toMatchObject({
        backlogEntryID: 1,
        userID: 1,
        title: "Elden Ring",
        genre: "RPG",
        platform: "PC",
        status: "Not Started",
        owned: true,
        interest: 2,
        reviewStars: 4,
        review: "This is a review",
        note: "This is a note",
      });
    });

    it("should get backlog entry by id", async () => {
      const entry = await getBacklogEntryById(postgresPool, 1);
      expect(entry.status).toBe("Not Started");
    });

    it("should get backlog entries by status", async () => {
      const notStarted = await getBacklogEntriesByStatus(postgresPool, {
        userId: 1,
        status: "Not Started",
      });
      expect(notStarted).toHaveLength(1);
      expect(notStarted[0]!.title).toBe("Elden Ring");

      const inProgress = await getBacklogEntriesByStatus(postgresPool, {
        userId: 1,
        status: "In Progress",
      });
      expect(inProgress).toHaveLength(1);
      expect(inProgress[0]!.title).toBe("Hollow Knight");

      const completed = await getBacklogEntriesByStatus(postgresPool, {
        userId: 1,
        status: "Completed",
      });
      expect(completed).toHaveLength(0);
    });

    it("should get categories for backlog entry", async () => {
      const categories = await getCategoriesForBacklogEntry(postgresPool, 1);
      expect(categories).toHaveLength(2);
      expect(categories[0]!.name).toBe("Action");
      expect(categories[1]!.name).toBe("Adventure");
    });

    it("should return empty array for backlog entry without categories", async () => {
      const categories = await getCategoriesForBacklogEntry(postgresPool, 3);
      expect(categories).toHaveLength(0);
    });

    it("should get backlog entries for category with all fields", async () => {
      const backlogEntries = await getBacklogEntriesForCategory(
        postgresPool,
        1,
      );

      expect(backlogEntries).toHaveLength(1);

      expect(backlogEntries[0]!.backlogEntryID).toBe(1);
      expect(backlogEntries[0]!.userID).toBe(1);
      expect(backlogEntries[0]!.title).toBe("Elden Ring");
      expect(backlogEntries[0]!.status).toBe("Not Started");
    });

    it("should get multiple backlog entries for category", async () => {
      const backlogEntries = await getBacklogEntriesForCategory(
        postgresPool,
        2,
      );

      expect(backlogEntries).toHaveLength(1);
      expect(backlogEntries[0]!.backlogEntryID).toBe(1);
      expect(backlogEntries[0]!.title).toBe("Elden Ring");
    });

    it("should return empty array for category without backlog entries", async () => {
      const backlogEntries = await getBacklogEntriesForCategory(
        postgresPool,
        3,
      );
      expect(backlogEntries).toHaveLength(0);
    });
  });
});
