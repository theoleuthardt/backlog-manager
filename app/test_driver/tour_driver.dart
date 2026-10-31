import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// The driver of the mobile tour (`integration_test/mobile_tour_test.dart`):
/// writes the screenshots it reports to `tour/<device>/` as PNG files, the
/// steps with their errors to `tour/<device>/report.json` and a Markdown
/// summary of the errors and failed steps to `tour/<device>/summary.md`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final directory = Directory('tour/${data['device']}')
      ..createSync(recursive: true);
    final shots = (data['screenshots'] as Map<String, dynamic>?) ?? const {};
    for (final MapEntry(key: name, value: png) in shots.entries) {
      File('${directory.path}/$name.png')
          .writeAsBytesSync(base64Decode(png as String));
    }
    File('${directory.path}/report.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ')
          .convert({'device': data['device'], 'steps': data['steps']}),
    );
    final steps = ((data['steps'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
    final errors = steps.where((s) => s['error'] != null).toList();
    final rings = steps.where((s) => s['ring'] != null).toList();
    final failed = steps
        .where((s) => s['failed'] != null || s['uncaught'] != null)
        .map((s) => {...s, 'failed': s['failed'] ?? s['uncaught']})
        .toList();
    final summary = StringBuffer()
      ..writeln('## Mobile tour on a ${data['device']}')
      ..writeln()
      ..writeln(
        '${shots.length} screenshots, ${errors.length} errors of the app, '
        '${failed.length} failed steps, ${rings.length} notes on the focus.',
      );
    for (final (title, list, field) in [
      ('Failed steps', failed, 'failed'),
      ('Errors of the app', errors, 'error'),
      ('Notes on the focus', rings, 'ring'),
    ]) {
      if (list.isEmpty) continue;
      summary
        ..writeln()
        ..writeln('### $title')
        ..writeln();
      for (final item in list) {
        final text = '${item[field]}'.split('\n').first;
        summary.writeln('- **${item['step']}**: $text');
      }
    }
    File('${directory.path}/summary.md').writeAsStringSync('$summary');
  },
);
