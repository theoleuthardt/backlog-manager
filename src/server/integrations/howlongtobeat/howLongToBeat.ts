import {stringify} from "node:querystring";
import type {HltbGame, HltbSearchResult, HltbSearchResultItem} from "~/server/integrations/types";

export async function SearchGame(input: string) {
    const response = await fetch('https://hltbapi1.azurewebsites.net/hltb/search', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            searchTerm: input,
            matchType: 1,
            platform: ''
        })
    })
    const data = await response.json();

    const result: HltbSearchResult = data.map((item: any) => ({
        id: item.id,
        hltbId: item.hltbId,
        title: item.title,
        imageUrl: item.imageUrl,
        steamAppId: item.steamAppId,
        gogAppId: item.gogAppId,
        mainStory: item.mainStory,
        mainStoryWithExtras: item.mainStoryWithExtras,
        completionist: item.completionist,
        lastUpdatedAt: item.lastUpdatedAt
    }));
    return result
}

export async function GetGameByID(id: number) {
    const URL = "https://hltbapi1.azurewebsites.net/hltb/" + id
    const response = await fetch(URL)
    const data = await response.json();

    const result: HltbGame = {
        id: data.id,
        hltbId: data.hltbId,
        title: data.title,
        imageUrl: data.imageUrl,
        steamAppId: data.steamAppId,
        gogAppId: data.gogAppId,
        mainStory: data.mainStory,
        mainStoryWithExtras: data.mainStoryWithExtras,
        completionist: data.completionist,
        lastUpdatedAt: data.lastUpdatedAt
    };
    return result
    }
