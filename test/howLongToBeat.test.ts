import { describe, it, expect } from "vitest";
import {
  GetGameByID,
  SearchGameOnHLTB,
} from "~/server/integrations/howlongtobeat/howLongToBeat";

describe("HowLongToBeat Integration", () => {
  describe("SearchGame", () => {
    it("should find game by title", async () => {
      const result = await SearchGameOnHLTB("Fortnite");
      expect(result).toBeDefined();
      expect(result.length).toBeGreaterThan(0);
      expect(result[0]?.title).toBe("Fortnite");
    });

    it("should return game with time fields", async () => {
      const result = await SearchGameOnHLTB("Elden Ring");
      expect(result).toBeDefined();
      expect(result.length).toBeGreaterThan(0);

      const game = result[0];
      expect(game).toBeDefined();

      // Verify the three separate time fields exist (API field names)
      // Note: Some games might not have all times, so we just check the properties exist
      expect(game).toHaveProperty("mainStory");
      expect(game).toHaveProperty("mainStoryWithExtras");
      expect(game).toHaveProperty("completionist");
    });

    it("should return empty array for non-existent game", async () => {
      const result = await SearchGameOnHLTB("NonExistentGame123XYZ456789");
      expect(result).toEqual([]);
    });

    it("should handle search with special characters", async () => {
      const result = await SearchGameOnHLTB("The Legend of Zelda");
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe("GetGameByID", () => {
    it("should retrieve game by ID", async () => {
      const result = await GetGameByID(2224);
      expect(result).toBeDefined();
      expect(result.hltbId).toBe(2224);
      expect(result.title).toBeDefined();
    });

    it("should return game with time data structure", async () => {
      const result = await GetGameByID(2224);

      // Verify the three separate time fields exist in the response (API field names)
      expect(result).toHaveProperty("mainStory");
      expect(result).toHaveProperty("mainStoryWithExtras");
      expect(result).toHaveProperty("completionist");

      // If times are provided, they should be numbers
      if (result.mainStory !== null && result.mainStory !== undefined) {
        expect(typeof result.mainStory).toBe("number");
      }
      if (
        result.mainStoryWithExtras !== null &&
        result.mainStoryWithExtras !== undefined
      ) {
        expect(typeof result.mainStoryWithExtras).toBe("number");
      }
      if (result.completionist !== null && result.completionist !== undefined) {
        expect(typeof result.completionist).toBe("number");
      }
    });

    it("should retrieve different game successfully", async () => {
      // Testing with a well-known game ID
      const result = await GetGameByID(10270); // The Witcher 3
      expect(result).toBeDefined();
      expect(result.hltbId).toBe(10270);
    });
  });
});
