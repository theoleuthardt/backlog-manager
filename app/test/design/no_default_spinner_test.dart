import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every indeterminate spinner of the app is the Saturn spinner', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/generated/')) continue;
      final text = entity.readAsStringSync();
      final plain = RegExp(r'CircularProgressIndicator\((?![^)]*value:)')
          .hasMatch(text);
      if (plain) offenders.add(entity.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use ShelfSpinner (design/widgets/spinner.dart); a '
          'CircularProgressIndicator with a value (a progress) is fine.',
    );
  });
}
