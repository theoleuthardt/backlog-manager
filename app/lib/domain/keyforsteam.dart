/// The catalog of Keyforsteam searched for [title], the address its own
/// search form sends (`/katalog/?search_name=<term>`). The address of its
/// `SearchAction` (`/katalog/search-<term>`) only shows the empty catalog.
String keyforsteamSearchUrl(String title) =>
    'https://www.keyforsteam.de/katalog/'
    '?search_name=${Uri.encodeQueryComponent(title)}';

/// Whether the window that shows Keyforsteam may load [url] itself: an https
/// page of keyforsteam.de or one of its subdomains. Everything else, the shops
/// its offers lead to included, opens in the system browser.
bool staysOnKeyforsteam(Uri url) {
  if (url.scheme != 'https') return false;
  final host = url.host.toLowerCase();
  return host == 'keyforsteam.de' || host.endsWith('.keyforsteam.de');
}
