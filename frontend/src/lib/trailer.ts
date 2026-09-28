const WATCH_URL = /^https:\/\/www\.youtube\.com\/watch\?v=([A-Za-z0-9_-]{11})$/;

/**
 * Maps a stored trailer link (the backend only accepts canonical YouTube
 * watch URLs) to the embed url of the privacy-enhanced player. Anything
 * else resolves to null so an arbitrary string never ends up as an iframe
 * source.
 */
export function youtubeEmbedUrl(link: string | null | undefined): string | null {
  const videoId = link ? WATCH_URL.exec(link)?.[1] : undefined;
  return videoId ? `https://www.youtube-nocookie.com/embed/${videoId}` : null;
}
