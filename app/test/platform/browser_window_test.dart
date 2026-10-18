import 'package:backlog_manager/platform/browser_window.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('windowsWebviewProfileFolder', () {
    test('is a folder of the app in the local application data', () {
      expect(
        windowsWebviewProfileFolder({
          'LOCALAPPDATA': r'C:\Users\a\AppData\Local',
        }),
        r'C:\Users\a\AppData\Local\Backlog Manager\WebView2',
      );
    });

    test('is null without it, which leaves the default of the plugin', () {
      expect(windowsWebviewProfileFolder({}), isNull);
      expect(windowsWebviewProfileFolder({'LOCALAPPDATA': ''}), isNull);
    });
  });

  test('opens the address in the system browser without a web view', () async {
    final opened = <Uri>[];
    final container = ProviderContainer(
      overrides: [urlOpenerProvider.overrideWithValue(opened.add)],
    );
    addTearDown(container.dispose);

    await container.read(browserWindowOpenerProvider)(
      Uri.parse('https://www.keyforsteam.de/katalog/search-Hades'),
      stays: (_) => true,
    );

    expect(opened, [
      Uri.parse('https://www.keyforsteam.de/katalog/search-Hades'),
    ]);
  });
}
