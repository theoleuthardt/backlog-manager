/**
 * @param {Request} request
 */
export async function GET(request) {
  const { searchParams } = new URL(request.url)
  const imageUrl = searchParams.get('url')

  const isHltb = imageUrl?.startsWith('https://howlongtobeat.com/')
  const isIgdb = imageUrl?.startsWith('https://images.igdb.com/')

  if (!imageUrl || (!isHltb && !isIgdb)) {
    return new Response('Invalid URL', { status: 400 })
  }

  try {
    /** @type {Record<string, string>} */
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    }

    if (isHltb) {
      headers['Referer'] = 'https://howlongtobeat.com/'
      headers['Origin'] = 'https://howlongtobeat.com'
    }

    const response = await fetch(imageUrl, { headers })

    if (!response.ok) {
      console.error(`Failed to fetch image from ${imageUrl}: ${response.status} ${response.statusText}`)
      return new Response('Image not found', { status: 404 })
    }

    const imageBuffer = await response.arrayBuffer()
    const contentType = response.headers.get('Content-Type') || 'image/jpeg'

    return new Response(imageBuffer, {
      headers: {
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=86400, immutable',
        'Access-Control-Allow-Origin': '*',
      }
    })
  } catch (error) {
    console.error('Error fetching image:', error)
    return new Response('Failed to fetch image', { status: 500 })
  }
}