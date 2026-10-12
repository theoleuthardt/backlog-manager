import 'dart:convert';
import 'dart:typed_data';

import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/features/common/user_avatar.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class AvatarApi implements UserApi {
  AvatarApi(this.bytes);

  final Uint8List? bytes;
  final asked = <int>[];

  @override
  Future<Uint8List?> avatar(int userId) async {
    asked.add(userId);
    return bytes;
  }

  @override
  Future<SessionUser> update(UserUpdate update) => throw UnimplementedError();

  @override
  Future<SessionUser> setAvatar(Uint8List bytes, String contentType) =>
      throw UnimplementedError();

  @override
  Future<SessionUser> removeAvatar() => throw UnimplementedError();
}

Future<AvatarApi> pump(
  WidgetTester tester, {
  Uint8List? bytes,
  int? userId = 7,
  DateTime? version,
}) async {
  final api = AvatarApi(bytes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: UserAvatar(
          userId: userId,
          version: version,
          size: 32,
          fallback: const Text('T', key: Key('initial')),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return api;
}

void main() {
  testWidgets('shows the picture of the version', (tester) async {
    final api = await pump(
      tester,
      bytes: Uint8List.fromList(_pixel),
      version: DateTime.utc(2026, 10, 12),
    );

    expect(find.byKey(const Key('user-avatar-picture')), findsOneWidget);
    expect(find.byKey(const Key('initial')), findsNothing);
    expect(api.asked, [7]);
  });

  testWidgets('a user without a picture shows the initial and asks nothing', (
    tester,
  ) async {
    final api = await pump(tester, bytes: Uint8List.fromList(_pixel));

    expect(find.byKey(const Key('initial')), findsOneWidget);
    expect(api.asked, isEmpty);
  });

  testWidgets('a picture that cannot be read keeps the initial', (
    tester,
  ) async {
    await pump(tester, version: DateTime.utc(2026, 10, 12));

    expect(find.byKey(const Key('initial')), findsOneWidget);
    expect(find.byKey(const Key('user-avatar-picture')), findsNothing);
  });

  testWidgets('an unknown id shows the initial', (tester) async {
    final api = await pump(
      tester,
      bytes: Uint8List.fromList(_pixel),
      userId: 0,
      version: DateTime.utc(2026, 10, 12),
    );

    expect(find.byKey(const Key('initial')), findsOneWidget);
    expect(api.asked, isEmpty);
  });
}
