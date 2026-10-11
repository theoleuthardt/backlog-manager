import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:backlog_manager/domain/update_manifest.dart';
import 'package:cryptography/cryptography.dart';

/// Why a downloaded payload was accepted or refused.
enum UpdateVerdict { ok, wrongSize, wrongHash, badSignature }

/// Checks a downloaded installer before anything is installed: its size and
/// SHA-256 are the ones the manifest names, and the signature of that hash is
/// good for this version and platform under the public key built into the
/// app.
class UpdateVerifier {
  UpdateVerifier(this.publicKey);

  /// The raw 32 bytes of the Ed25519 public key.
  final Uint8List publicKey;

  Future<String> sha256Of(File file) async {
    final sink = Sha256().newHashSink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    final hash = await sink.hash();
    return [
      for (final byte in hash.bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  Future<UpdateVerdict> verify({
    required File file,
    required UpdatePayload payload,
    required String version,
    required String key,
  }) async {
    if (await file.length() != payload.size) return UpdateVerdict.wrongSize;
    final hash = await sha256Of(file);
    if (hash != payload.sha256) return UpdateVerdict.wrongHash;

    final Uint8List signature;
    try {
      signature = base64Decode(payload.signature);
    } on FormatException {
      return UpdateVerdict.badSignature;
    }
    if (signature.length != 64) return UpdateVerdict.badSignature;
    final message = utf8.encode(
      updateMessage(version: version, key: key, sha256: payload.sha256),
    );
    final valid = await Ed25519().verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
    return valid ? UpdateVerdict.ok : UpdateVerdict.badSignature;
  }
}
