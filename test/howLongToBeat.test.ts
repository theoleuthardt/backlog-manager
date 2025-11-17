import { describe, it, expect} from 'vitest'
import { SearchGame} from "~/server/api/HowLongToBeat/howLongToBeat";

describe('Fortnite', () => {

        it('Gooby', async () => {
            const result = await SearchGame("For")
            console.log(result)
            expect(result).toBe("100% Complete!")
        })

    })