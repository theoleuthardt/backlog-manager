import 'package:backlog_manager/design/brand_mark.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/theme_provider.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/link_text.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/stepper.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/domain/themes.dart';
import 'package:backlog_manager/features/setup/setup_controller.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The first-run wizard: a vertical stepper on the left, the form of the
/// current step on the right and Back and Next below it.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _steamId = TextEditingController();
  final _steamKey = TextEditingController();
  final _igdbId = TextEditingController();
  final _igdbSecret = TextEditingController();

  @override
  void dispose() {
    _steamId.dispose();
    _steamKey.dispose();
    _igdbId.dispose();
    _igdbSecret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(setupControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        showShelfToast(context, next.error!);
      }
    });
    final setup = ref.watch(setupControllerProvider);
    final controller = ref.read(setupControllerProvider.notifier);
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return Row(
      children: [
        SizedBox(
          width: 240,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(),
                const SizedBox(height: 14),
                Text('Welcome to Backlog', style: text.section),
                const SizedBox(height: 24),
                ShelfStepper(steps: setupSteps, current: setup.step),
                const Spacer(),
                if (!setup.isLastStep)
                  ShelfButton(
                    label: 'Skip setup',
                    kind: ShelfButtonKind.quiet,
                    onPressed: setup.saving ? null : controller.skip,
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: 1, child: ColoredBox(color: tokens.borderSubtle)),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._step(setup, controller),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        ShelfButton(
                          key: const Key('setup-back'),
                          label: 'Back',
                          onPressed: setup.step == 0 || setup.saving
                              ? null
                              : controller.back,
                        ),
                        const Spacer(),
                        ShelfButton(
                          key: const Key('setup-next'),
                          label: setup.isLastStep ? 'Go to Home' : 'Next',
                          kind: ShelfButtonKind.primary,
                          busy: setup.saving,
                          onPressed: setup.isLastStep
                              ? controller.finish
                              : controller.next,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _step(SetupState setup, SetupController controller) {
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final open = ref.read(urlOpenerProvider);

    Widget heading(String title, String description, {bool optional = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (optional) ...[
            Text('OPTIONAL', style: text.eyebrow),
            const SizedBox(height: 6),
          ],
          Text(title, style: text.page),
          const SizedBox(height: 6),
          Text(description, style: text.caption.copyWith(color: tokens.muted)),
          const SizedBox(height: 22),
        ],
      );
    }

    switch (setup.step) {
      case 0:
        return [
          heading(
            'Choose a look',
            'Pick how Backlog looks. You can change it any time in Appearance.',
          ),
          ShelfSelect<String>(
            label: 'Theme',
            value: ref.watch(themeIdProvider),
            onChanged: ref.read(themeIdProvider.notifier).select,
            options: [
              for (final theme in builtinThemes)
                ShelfOption(value: theme.id, label: theme.name),
            ],
          ),
        ];
      case 1:
        return [
          heading(
            'How should your library be sorted?',
            'This is the sorting the library opens with.',
          ),
          ShelfSelect<String>(
            label: 'Default sort',
            value: setup.defaultSort,
            onChanged: controller.setDefaultSort,
            options: [
              for (final option in SortOption.values)
                ShelfOption(value: option.value, label: option.label),
            ],
          ),
        ];
      case 2:
        return [
          heading(
            'Connect Steam',
            'Link Steam to import your library and wishlist and to sync playtimes. You can do this later in the settings.',
            optional: true,
          ),
          ShelfField(
            label: 'Steam ID',
            hintText: '17 digits',
            controller: _steamId,
            onChanged: controller.setSteamId,
          ),
          const SizedBox(height: 14),
          ShelfField(
            label: 'Web API key',
            controller: _steamKey,
            obscure: true,
            onChanged: controller.setSteamApiKey,
          ),
          const SizedBox(height: 14),
          LinkText(
            onOpen: open,
            parts: const [
              LinkPart("Don't know your ID? Use "),
              LinkPart(
                "SteamDB's SteamID finder",
                url: 'https://steamdb.com/en/tools/steam-id-finder',
              ),
              LinkPart('. Create a key on '),
              LinkPart(
                "Steam's API key page",
                url: 'https://steamcommunity.com/dev/apikey',
              ),
              LinkPart('.'),
            ],
          ),
        ];
      case 3:
        return [
          heading(
            'Connect IGDB',
            "IGDB powers game search and metadata. Without your own credentials the server's are used. Both fields are needed together.",
            optional: true,
          ),
          ShelfField(
            label: 'IGDB Client ID',
            controller: _igdbId,
            onChanged: controller.setIgdbClientId,
          ),
          const SizedBox(height: 14),
          ShelfField(
            label: 'IGDB Client Secret',
            controller: _igdbSecret,
            obscure: true,
            onChanged: controller.setIgdbClientSecret,
          ),
          const SizedBox(height: 14),
          LinkText(
            onOpen: open,
            parts: const [
              LinkPart('Create a Twitch application at '),
              LinkPart(
                'dev.twitch.tv/console/apps',
                url: 'https://dev.twitch.tv/console/apps',
              ),
              LinkPart(' to get an IGDB Client ID and Client Secret.'),
            ],
          ),
        ];
      default:
        return [
          heading(
            'All set',
            "You're ready to go. Everything here can be changed any time in the settings, where you can also enable two-factor authentication and set up Discord price alerts.",
          ),
        ];
    }
  }
}
