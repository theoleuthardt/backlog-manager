import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The path of the page the router is showing or about to show. The router
/// sets it in its redirect, before it builds the page, so a page can tell
/// where it is from the very first frame. Where Riverpod does not allow a
/// write (the first redirect runs while the app is built) it follows in a
/// microtask.
class CurrentPathNotifier extends Notifier<String> {
  @override
  String build() => '/';

  void set(String path) {
    if (state != path) state = path;
  }
}

final currentPathProvider = NotifierProvider<CurrentPathNotifier, String>(
  CurrentPathNotifier.new,
);
