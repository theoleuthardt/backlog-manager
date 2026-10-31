import 'package:backlog_manager/data/cover_size.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryCoverSizeStore implements CoverSizeStore {
  MemoryCoverSizeStore([this.stored]);

  String? stored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async => stored = value;
}

void main() {
  test('starts with the medium covers', () {
    final container = ProviderContainer(
      overrides: [
        coverSizeStoreProvider.overrideWithValue(MemoryCoverSizeStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(coverSizeProvider), CoverSize.medium);
  });

  test('loads the size kept on the device', () async {
    final container = ProviderContainer(
      overrides: [
        coverSizeStoreProvider.overrideWithValue(MemoryCoverSizeStore('small')),
      ],
    );
    addTearDown(container.dispose);
    container.read(coverSizeProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(coverSizeProvider), CoverSize.small);
  });

  test('keeps a chosen size on the device', () {
    final store = MemoryCoverSizeStore();
    final container = ProviderContainer(
      overrides: [coverSizeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(coverSizeProvider.notifier).select(CoverSize.large);

    expect(container.read(coverSizeProvider), CoverSize.large);
    expect(store.stored, 'large');
  });

  test('an unknown stored size is medium', () async {
    final container = ProviderContainer(
      overrides: [
        coverSizeStoreProvider.overrideWithValue(MemoryCoverSizeStore('huge')),
      ],
    );
    addTearDown(container.dispose);
    container.read(coverSizeProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(coverSizeProvider), CoverSize.medium);
  });
}
