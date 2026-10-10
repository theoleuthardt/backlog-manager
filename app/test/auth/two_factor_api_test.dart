import 'package:backlog_manager/api/api_client.dart';
import 'package:backlog_manager/auth/two_factor_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_auth_api_test.dart' show FakeServer;

ApiTwoFactorApi apiFor(FakeServer server) {
  final dio = createApiDio(
    baseUrl: 'https://api.test',
    readToken: () async => 'jwt',
    onUnauthorized: () {},
    adapter: server,
  );
  return ApiTwoFactorApi(() async => dio);
}

void main() {
  test('enrolling returns the secret and the otpauth address', () async {
    final server = FakeServer(
      (_) => (
        status: 200,
        body: {
          'secret': 'ABCDEF',
          'otpauth_url': 'otpauth://totp/x?secret=ABCDEF',
        },
      ),
    );

    final enrollment = await apiFor(server).enroll();

    expect(enrollment.secret, 'ABCDEF');
    expect(enrollment.otpauthUrl, 'otpauth://totp/x?secret=ABCDEF');
    expect(server.requests.single.method, 'POST');
    expect(server.requests.single.path, '/api/auth/2fa/enroll');
  });

  test(
    'verifying sends the code without spaces and returns the codes',
    () async {
      final server = FakeServer(
        (_) => (
          status: 200,
          body: {
            'backup_codes': ['aaaa-1111', 'bbbb-2222'],
          },
        ),
      );

      final codes = await apiFor(server).verify('123 456');

      expect(codes, ['aaaa-1111', 'bbbb-2222']);
      expect(server.requests.single.path, '/api/auth/2fa/verify');
      expect(server.requests.single.data, {'code': '123456'});
    },
  );

  test('disabling sends the password', () async {
    final server = FakeServer((_) => (status: 204, body: null));

    await apiFor(server).disable('hunter2hunter2');

    expect(server.requests.single.path, '/api/auth/2fa/disable');
    expect(server.requests.single.data, {'password': 'hunter2hunter2'});
  });
}
