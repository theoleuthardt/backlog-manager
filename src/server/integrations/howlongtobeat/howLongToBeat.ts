import type { HltbGame, HltbSearchResult } from "~/server/integrations/types";

interface HltbApiGame {
  id: number;
  hltbId: number;
  title: string;
  imageUrl: string;
  steamAppId: number | null;
  gogAppId: number | null;
  mainStory: number;
  mainStoryWithExtras: number;
  completionist: number;
  lastUpdatedAt: string;
}

export async function SearchGame(input: string) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 60000);

    const response = await fetch(
      "https://hltbapi1.azurewebsites.net/hltb/search",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          searchTerm: input,
          matchType: 1,
          platform: "",
        }),
        signal: controller.signal,
      },
    );

    clearTimeout(timeoutId);

    if (!response.ok) {
      console.error(`HowLongToBeat API error: ${response.status}`);
      return [];
    }

    const data: unknown = await response.json();

    if (!Array.isArray(data)) {
      return [];
    }

    const result: HltbSearchResult = (data as HltbApiGame[]).map((item) => ({
      id: item.id,
      hltbId: item.hltbId,
      title: item.title,
      imageUrl: item.imageUrl,
      steamAppId: item.steamAppId,
      gogAppId: item.gogAppId,
      mainStory: item.mainStory,
      mainStoryWithExtras: item.mainStoryWithExtras,
      completionist: item.completionist,
      lastUpdatedAt: item.lastUpdatedAt,
    }));
    return result;
  } catch (error) {
    console.error("SearchGame error:", error);
    return [];
  }
}

export async function GetGameByID(id: number) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);

    const URL = "https://hltbapi1.azurewebsites.net/hltb/" + id;
    const response = await fetch(URL, {
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`HowLongToBeat API error: ${response.status}`);
    }

    const data: unknown = await response.json();
    const apiData = data as HltbApiGame;

    const result: HltbGame = {
      id: apiData.id,
      hltbId: apiData.hltbId,
      title: apiData.title,
      imageUrl: apiData.imageUrl,
      steamAppId: apiData.steamAppId,
      gogAppId: apiData.gogAppId,
      mainStory: apiData.mainStory,
      mainStoryWithExtras: apiData.mainStoryWithExtras,
      completionist: apiData.completionist,
      lastUpdatedAt: apiData.lastUpdatedAt,
    };
    return result;
  } catch (error) {
    console.error("GetGameByID error:", error);
    throw error;
  }
}
