/// Whether [value] is an absolute http or https URL, the only kinds that are
/// safe to open from a link the backend or a third party supplied. It is a
/// little stricter than the WHATWG parser of the web client: the host must be
/// non-empty and the scheme must be followed by `//` (`https:example.com`
/// is rejected).
bool isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
  return uri.scheme == 'https' || uri.scheme == 'http';
}
