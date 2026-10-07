import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an address in the browser of the system; tests replace it.
final urlOpenerProvider = Provider<void Function(Uri uri)>(
  (ref) =>
      (uri) => unawaited(launchUrl(uri, mode: LaunchMode.externalApplication)),
);
