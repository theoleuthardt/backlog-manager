import 'package:backlog_manager/data/release_source.dart';
import 'package:backlog_manager/data/update_channel.dart';
import 'package:backlog_manager/domain/app_update.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryChannelStore implements UpdateChannelStore {
  MemoryChannelStore([this.saved]);

  UpdateChannel? saved;
  var fails = false;

  @override
  Future<UpdateChannel?> read() async {
    if (fails) throw Exception('unreadable');
    return saved;
  }

  @override
  Future<void> write(UpdateChannel channel) async => saved = channel;
}

ProviderContainer containerWith(MemoryChannelStore store) {
  final container = ProviderContainer(
    overrides: [updateChannelStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('UpdateChannel', () {
    test('has a label for the settings', () {
      expect(UpdateChannel.stable.label, 'Stable');
      expect(UpdateChannel.preview.label, 'Preview');
    });

    test('is read back from its name, and unknown names are nothing', () {
      expect(UpdateChannel.fromName('stable'), UpdateChannel.stable);
      expect(UpdateChannel.fromName('preview'), UpdateChannel.preview);
      expect(UpdateChannel.fromName('nightly'), isNull);
      expect(UpdateChannel.fromName(null), isNull);
    });
  });

  group('the update channel setting', () {
    test(
      'is stable until the user chooses, now that the app has full releases',
      () {
        final container = containerWith(MemoryChannelStore());

        expect(container.read(updateChannelProvider), UpdateChannel.stable);
      },
    );

    test('loads the channel kept on the device', () async {
      final container = containerWith(
        MemoryChannelStore(UpdateChannel.preview),
      );
      container.read(updateChannelProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(updateChannelProvider), UpdateChannel.preview);
    });

    test('choosing a channel applies it at once and keeps it', () async {
      final store = MemoryChannelStore();
      final container = containerWith(store);

      container
          .read(updateChannelProvider.notifier)
          .select(UpdateChannel.stable);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(updateChannelProvider), UpdateChannel.stable);
      expect(store.saved, UpdateChannel.stable);
    });

    test(
      'a choice made before the stored value arrives is not overwritten',
      () async {
        final container = containerWith(
          MemoryChannelStore(UpdateChannel.stable),
        );

        container
            .read(updateChannelProvider.notifier)
            .select(UpdateChannel.preview);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(updateChannelProvider), UpdateChannel.preview);
      },
    );

    test('a store that cannot be read is ignored', () async {
      final store = MemoryChannelStore()..fails = true;
      final container = containerWith(store);
      container.read(updateChannelProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(updateChannelProvider), UpdateChannel.stable);
    });

    test('the release source follows the channel', () {
      final container = containerWith(MemoryChannelStore());
      expect(
        (container.read(releaseSourceProvider) as GithubReleaseSource).channel,
        UpdateChannel.stable,
      );

      container
          .read(updateChannelProvider.notifier)
          .select(UpdateChannel.preview);

      expect(
        (container.read(releaseSourceProvider) as GithubReleaseSource).channel,
        UpdateChannel.preview,
      );
    });
  });
}
