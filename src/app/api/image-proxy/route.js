/**
 * @param {{ url: string | URL; }} request
 */
export async function GET(request) {
  const { searchParams } = new URL(request.url)
  const imageUrl = searchParams.get('url')

  if (!imageUrl || !imageUrl.startsWith('https://howlongtobeat.com/')) {
    return new Response('Invalid URL', { status: 400 })
  }

  try {
    const response = await fetch(imageUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://howlongtobeat.com/',
        'Accept': 'image/*,*/*;q=0.8',
      }
    })

    if (!response.ok) {
      return new Response('Image not found', { status: 404 })
    }

    return new Response(response.body, {
      headers: {
        'Content-Type': response.headers.get('Content-Type') || 'image/jpeg',
        'Cache-Control': 'public, max-age=3600',
        'Access-Control-Allow-Origin': '*',
      }
    })
  } catch (error) {
    return new Response('Failed to fetch image', { status: 500 })
  }
}