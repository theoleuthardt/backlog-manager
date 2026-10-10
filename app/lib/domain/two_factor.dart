/// The code of an authenticator app or a backup code without the spaces it
/// may have been typed or copied with.
String normalizeTotpCode(String code) => code.replaceAll(RegExp(r'\s'), '');
