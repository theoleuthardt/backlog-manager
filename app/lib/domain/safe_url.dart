/// Whether [value] is an absolute http or https URL, the only kinds that are
/// safe to open from a link the backend or a third party supplied.
bool isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) return false;
  return uri.scheme == 'https' || uri.scheme == 'http';
}
