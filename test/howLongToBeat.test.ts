import { describe, it, expect} from 'vitest'
import {GetGameByID, SearchGame} from "~/server/integrations/howlongtobeat/howLongToBeat";

describe('Fortnite', () => {

        it('Gooby', async () => {
            const result = await SearchGame("Fortnite")
            console.log(result)
            expect(result.at(0)?.title).toBe("Fortnite")
        })

        it('Für', async () => {
            const result = await GetGameByID(2224)
            console.log(result)
            expect(result.hltbId).toBe(2224)
        })

    })