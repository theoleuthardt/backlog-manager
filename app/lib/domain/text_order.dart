/// Orders two strings like a locale-aware comparison for the app's data:
/// letters compare case-insensitively first, and on a tie the lower-case
/// spelling comes first.
int compareText(String a, String b) {
  final byLetters = a.toLowerCase().compareTo(b.toLowerCase());
  return byLetters != 0 ? byLetters : b.compareTo(a);
}
