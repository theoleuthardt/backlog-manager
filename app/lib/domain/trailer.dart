final _watchUrl = RegExp(
  r'^https://www\.youtube\.com/watch\?v=([A-Za-z0-9_-]{11})$',
);

/// Maps a stored trailer link (the backend only accepts canonical YouTube
/// watch URLs) to the embed url of the privacy-enhanced player. Anything else
/// resolves to null so an arbitrary string never ends up as a web view source.
String? youtubeEmbedUrl(String? link) {
  if (link == null) return null;
  final videoId = _watchUrl.firstMatch(link)?.group(1);
  return videoId == null
      ? null
      : 'https://www.youtube-nocookie.com/embed/$videoId';
}
