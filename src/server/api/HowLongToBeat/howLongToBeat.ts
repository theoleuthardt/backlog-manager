
export async function SearchGame(input: string) {
    const result = await fetch('https://hltbapi1.azurewebsites.net/hltb/search', {
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
    return result.json()
}
