import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The numbers shown next to sidebar items, by item id (`library`, `space`).
class NavigationCountsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void set(Map<String, int> counts) => state = Map.unmodifiable(counts);
}

final navigationCountsProvider =
    NotifierProvider<NavigationCountsNotifier, Map<String, int>>(
      NavigationCountsNotifier.new,
    );
