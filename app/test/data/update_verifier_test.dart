import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:backlog_manager/data/update_verifier.dart';
import 'package:backlog_manager/domain/update_manifest.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

const _version = '1.2.3';
const _key = 'linux-x64-appimage';

Future<({UpdateVerifier verifier, UpdatePayload payload, File file})> signed({
  required Directory dir,
  List<int> content = const [1, 2, 3, 4, 5],
  SimpleKeyPair? signer,
  String version = _version,
  String key = _key,
}) async {
  final keyPair = await Ed25519().newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final file = File('${dir.path}/payload.bin')..writeAsBytesSync(content);
  final hash = await Sha256().hash(content);
  final sha256 = [
    for (final byte in hash.bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
  final message = utf8.encode(
    updateMessage(version: version, key: key, sha256: sha256),
  );
  final signature = await Ed25519().sign(message, keyPair: signer ?? keyPair);
  return (
    verifier: UpdateVerifier(Uint8List.fromList(publicKey.bytes)),
    file: file,
    payload: UpdatePayload(
      url: Uri.parse('https://github.com/o/r/a.AppImage'),
      sha256: sha256,
      signature: base64Encode(signature.bytes),
      size: content.length,
    ),
  );
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('blm-verify-'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<UpdateVerdict> check(
    ({UpdateVerifier verifier, UpdatePayload payload, File file}) set, {
    String version = _version,
    String key = _key,
  }) => set.verifier.verify(
    file: set.file,
    payload: set.payload,
    version: version,
    key: key,
  );

  test('accepts the file the manifest describes, signed by the key', () async {
    expect(await check(await signed(dir: dir)), UpdateVerdict.ok);
  });

  test('rejects a file that was changed after it was signed', () async {
    final set = await signed(dir: dir);
    set.file.writeAsBytesSync([1, 2, 3, 4, 9]);

    expect(await check(set), UpdateVerdict.wrongHash);
  });

  test('rejects a file of another size', () async {
    final set = await signed(dir: dir);
    set.file.writeAsBytesSync([1, 2, 3]);

    expect(await check(set), UpdateVerdict.wrongSize);
  });

  test('rejects a signature made with another key', () async {
    final stranger = await Ed25519().newKeyPair();

    expect(
      await check(await signed(dir: dir, signer: stranger)),
      UpdateVerdict.badSignature,
    );
  });

  test('rejects a payload signed for another version or platform', () async {
    final set = await signed(dir: dir);

    expect(await check(set, version: '1.2.4'), UpdateVerdict.badSignature);
    expect(
      await check(set, key: 'windows-x64-exe'),
      UpdateVerdict.badSignature,
    );
  });

  test('rejects a signature that is not base64', () async {
    final set = await signed(dir: dir);
    final broken = UpdatePayload(
      url: set.payload.url,
      sha256: set.payload.sha256,
      signature: '***',
      size: set.payload.size,
    );

    expect(
      await set.verifier.verify(
        file: set.file,
        payload: broken,
        version: _version,
        key: _key,
      ),
      UpdateVerdict.badSignature,
    );
  });

  test('rejects a signature of the wrong length without throwing', () async {
    final set = await signed(dir: dir);
    final short = UpdatePayload(
      url: set.payload.url,
      sha256: set.payload.sha256,
      signature: base64Encode([1, 2, 3]),
      size: set.payload.size,
    );

    expect(
      await set.verifier.verify(
        file: set.file,
        payload: short,
        version: _version,
        key: _key,
      ),
      UpdateVerdict.badSignature,
    );
  });
}
