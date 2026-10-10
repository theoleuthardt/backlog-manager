import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

const fakePassword = 'correct-horse-battery';
const fakeTwoFactorCode = '123456';
const fakeAccessToken = 'integration-token';

/// A backend in memory that answers the HTTP requests of the app, so the
/// flows run through the real client, the real providers and the real
/// screens without a server. The state is what the requests changed.
class FakeBackend implements HttpClientAdapter {
  FakeBackend({List<Map<String, Object?>>? entries, this.twoFactor = true}) {
    for (final entry in entries ?? const <Map<String, Object?>>[]) {
      _entries[entry['id']! as int] = entry;
    }
    _nextId = (_entries.keys.fold<int>(0, (a, b) => a > b ? a : b)) + 1;
  }

  final bool twoFactor;
  final _entries = <int, Map<String, Object?>>{};
  late int _nextId;

  /// Every request as "METHOD path", in order.
  final requests = <String>[];

  /// The bodies of the writes, in order.
  final bodies = <Map<String, Object?>>[];

  List<Map<String, Object?>> get entries => _entries.values.toList();

  Map<String, Object?>? entry(int id) => _entries[id];

  static Map<String, Object?> entryJson({
    required int id,
    required String title,
    String status = 'Not Started',
    List<String> platform = const ['PC'],
    List<String> genre = const [],
    String? playtime,
    String? mainTime,
    String? note,
    int? steamAppId,
  }) => {
    'id': id,
    'title': title,
    'genre': genre,
    'platform': platform,
    'status': status,
    'owned': true,
    'interest': 5,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
    'image_link': null,
    'playtime': playtime,
    'main_time': mainTime,
    'note': note,
    'steam_app_id': steamAppId,
    'in_shared_space': false,
  };

  Map<String, Object?> _user() => {
    'id': 1,
    'name': 'Theo',
    'email': 'theo@example.com',
    'is_admin': false,
    'is_two_factor_enabled': twoFactor,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
    'setup_completed': true,
    'default_sort': 'status',
    'theme': 'shelfOled',
    'custom_themes': <Object?>[],
  };

  ResponseBody _json(Object? body, [int status = 200]) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  ResponseBody _error(int status, String detail) =>
      _json({'detail': detail}, status);

  Future<Map<String, Object?>> _body(Stream<Uint8List>? stream) async {
    if (stream == null) return {};
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    if (bytes.isEmpty) return {};
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map<String, Object?> ? decoded : {};
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method;
    requests.add('$method $path');
    final body = await _body(requestStream);
    if (method != 'GET') bodies.add(body);

    switch ((method, path)) {
      case ('GET', '/health'):
        return _json({'status': 'ok'});
      case ('POST', '/api/auth/login'):
        if (body['password'] != fakePassword) {
          return _error(401, 'Incorrect email or password');
        }
        return twoFactor
            ? _json({'requires_2fa': true, 'challenge_token': 'challenge'})
            : _json({'access_token': fakeAccessToken});
      case ('POST', '/api/auth/2fa/login-verify'):
        if (body['code'] != fakeTwoFactorCode) {
          return _error(401, 'Invalid code');
        }
        return _json({'access_token': fakeAccessToken, 'token_type': 'bearer'});
      case ('GET', '/api/user/me'):
        return _json(_user());
      case ('GET', '/api/backlog/entries'):
        return _json(entries);
      case ('POST', '/api/backlog/entries'):
        final created = {
          ...entryJson(
            id: _nextId,
            title: body['title']! as String,
            status: body['status']! as String,
            platform: (body['platform']! as List<Object?>).cast<String>(),
            genre: (body['genre']! as List<Object?>).cast<String>(),
          ),
          'steam_app_id': body['steam_app_id'],
        };
        _entries[_nextId++] = created;
        return _json(created, 201);
      case ('GET', '/api/backlog/entries/duplicates'):
        return _json(<Object?>[]);
      case ('GET', '/api/backlog/categories'):
      case ('GET', '/api/backlog/statuses'):
        return _json(<Object?>[]);
      case ('GET', '/api/user/steam/wishlist/sync-report'):
        return _json({'added': <Object?>[], 'removed': <Object?>[]});
      case ('GET', '/api/space'):
        return _json({
          'space_id': null,
          'my_status': null,
          'members': <Object?>[],
        });
    }

    final entryPath = RegExp(r'^/api/backlog/entries/(\d+)$').firstMatch(path);
    if (entryPath != null) {
      final id = int.parse(entryPath.group(1)!);
      final existing = _entries[id];
      if (existing == null) return _error(404, 'Not found');
      if (method == 'PUT') {
        final updated = {...existing};
        for (final field in body.entries) {
          updated[field.key] = field.value;
        }
        _entries[id] = updated;
        return _json(updated);
      }
      if (method == 'GET') return _json(existing);
      if (method == 'DELETE') {
        _entries.remove(id);
        return _json(null, 204);
      }
    }
    if (RegExp(r'^/api/backlog/entries/\d+/categories$').hasMatch(path)) {
      return _json(<Object?>[]);
    }
    return _error(404, 'No fake for $method $path');
  }

  @override
  void close({bool force = false}) {}
}
