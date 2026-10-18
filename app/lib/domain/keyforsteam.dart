/// The search of Keyforsteam for [title], the address its own site search
/// uses (`/katalog/search-<term>`).
String keyforsteamSearchUrl(String title) =>
    'https://www.keyforsteam.de/katalog/search-${Uri.encodeComponent(title)}';

/// Whether the window that shows Keyforsteam may load [url] itself: an https
/// page of keyforsteam.de or one of its subdomains. Everything else, the shops
/// its offers lead to included, opens in the system browser.
bool staysOnKeyforsteam(Uri url) {
  if (url.scheme != 'https') return false;
  final host = url.host.toLowerCase();
  return host == 'keyforsteam.de' || host.endsWith('.keyforsteam.de');
}
