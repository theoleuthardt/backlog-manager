import 'dart:async';

import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/link_text.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/domain/sort_entries.dart';
import 'package:backlog_manager/features/common/debouncer.dart';
import 'package:backlog_manager/features/settings/security_tab.dart';
import 'package:backlog_manager/features/settings/settings_controller.dart';
import 'package:backlog_manager/features/settings/settings_widgets.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:backlog_manager/shell/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The tabs of the settings window. Backups and App updates join them with
/// their own features.
enum SettingsTab {
  general('general', 'General', Icons.tune),
  security('security', 'Security', Icons.shield_outlined),
  integrations('integrations', 'Integrations', Icons.link),
  about('about', 'About', Icons.info_outline);

  const SettingsTab(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

const _autosaveDelay = Duration(milliseconds: 800);

/// The settings window: a list of tabs with the account at its foot, and the
/// settings of the tab in groups of rows. Settings save themselves.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({this.initialTab, super.key});

  /// The id of the tab to open, from the address.
  final String? initialTab;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late SettingsTab _tab =
      SettingsTab.values.where((t) => t.id == widget.initialTab).firstOrNull ??
      SettingsTab.general;

  SessionUser? get _user {
    final session = ref.watch(sessionProvider);
    return session is SessionSignedIn ? session.user : null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final user = _user;
    return Row(
      key: const Key('page-settings'),
      children: [
        SizedBox(
          width: 232,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border(right: BorderSide(color: tokens.borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                for (final tab in SettingsTab.values)
                  _TabItem(
                    tab: tab,
                    active: tab == _tab,
                    onPressed: () => setState(() => _tab = tab),
                  ),
                const Spacer(),
                if (user != null) _AccountRow(user: user),
              ],
            ),
          ),
        ),
        Expanded(
          child: user == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: switch (_tab) {
                            SettingsTab.general => _GeneralTab(user: user),
                            SettingsTab.security => SecurityTab(user: user),
                            SettingsTab.integrations => _IntegrationsTab(
                              user: user,
                            ),
                            SettingsTab.about => const _AboutTab(),
                          },
                        ),
                      ),
                    ),
                    const _StatusLine(),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.active,
    required this.onPressed,
  });

  final SettingsTab tab;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: ShelfPressable(
        key: Key('settings-tab-${tab.id}'),
        onPressed: onPressed,
        semanticLabel: tab.label,
        borderRadius: ShelfRadius.control,
        builder: (context, state) => DecoratedBox(
          decoration: BoxDecoration(
            color: active
                ? tokens.accentSoft
                : state.hovered
                ? tokens.glowSoft
                : null,
            borderRadius: BorderRadius.circular(ShelfRadius.control),
          ),
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    tab.icon,
                    size: 16,
                    color: active ? tokens.accent : tokens.muted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tab.label,
                    style: style.control.copyWith(
                      color: active ? tokens.foreground : tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final initials = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().substring(0, user.name.trim().length.clamp(1, 2));
    return DecoratedBox(
      key: const Key('settings-account'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Text(
                    initials.toUpperCase(),
                    style: style.label.copyWith(color: tokens.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    overflow: TextOverflow.ellipsis,
                    style: style.control,
                  ),
                  Text(
                    user.email,
                    overflow: TextOverflow.ellipsis,
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends ConsumerWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final save = ref.watch(settingsControllerProvider);
    final (label, dot) = switch (save) {
      SettingsSave.saving => ('Saving...', tokens.accent),
      SettingsSave.saved => ('Saved', tokens.success),
      SettingsSave.failed => ('Not saved', tokens.danger),
      SettingsSave.idle => ('', null),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 6),
        child: Row(
          key: const Key('settings-status'),
          children: [
            Text(
              'Changes in settings save automatically',
              style: style.caption.copyWith(color: tokens.faint),
            ),
            const Spacer(),
            if (dot != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                child: const SizedBox(width: 6, height: 6),
              ),
              const SizedBox(width: 6),
              Text(label, style: style.caption.copyWith(color: tokens.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabTitle extends StatelessWidget {
  const _TabTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: style.page.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(subtitle, style: style.caption.copyWith(color: tokens.muted)),
        ],
      ),
    );
  }
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final current = parseSortOption(user.defaultSort) ?? defaultSort;

    Future<void> chooseSort(SortOption option) async {
      final error = await ref
          .read(settingsControllerProvider.notifier)
          .save(UserUpdate(defaultSort: option.value));
      if (context.mounted) {
        showShelfToast(context, error ?? 'Default sort saved');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TabTitle(
          title: 'General',
          subtitle: 'Your account and how the library starts.',
        ),
        ShelfFormGroup(
          title: 'Account',
          rows: [
            ShelfFormRow(
              label: 'Signed in as',
              control: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    user.name,
                    key: const Key('settings-name'),
                    style: style.control,
                  ),
                  Text(
                    user.email,
                    key: const Key('settings-email'),
                    style: style.caption.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ShelfFormGroup(
          title: 'Library',
          rows: [
            ShelfFormRow(
              label: 'Default sort',
              description:
                  'The library opens sorted by this option; you can still '
                  'change it there at any time.',
              control: SizedBox(
                width: 200,
                child: ShelfMenuAnchor(
                  entries: [
                    for (final option in SortOption.values)
                      ShelfMenuItem(
                        label: option.label,
                        checked: option == current,
                        onSelected: () => unawaited(chooseSort(option)),
                      ),
                  ],
                  builder: (context, controller) => ShelfSelectTrigger(
                    key: const Key('settings-default-sort'),
                    text: current.label,
                    semanticLabel: 'Default sort',
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                ),
              ),
            ),
            ShelfFormRow(
              label: 'Appearance',
              description: 'Themes and your own colours.',
              control: ShelfButton(
                key: const Key('settings-appearance'),
                label: 'Open appearance',
                onPressed: () => context.go(AppRoutes.appearance),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntegrationsTab extends ConsumerStatefulWidget {
  const _IntegrationsTab({required this.user});

  final SessionUser user;

  @override
  ConsumerState<_IntegrationsTab> createState() => _IntegrationsTabState();
}

class _IntegrationsTabState extends ConsumerState<_IntegrationsTab> {
  late final _steamId = TextEditingController(text: widget.user.steamId);
  late final _family = TextEditingController(text: widget.user.steamFamilyIds);
  final _steamKey = TextEditingController();
  final _igdbId = TextEditingController();
  final _igdbSecret = TextEditingController();
  final _gridKey = TextEditingController();
  final _discord = TextEditingController();
  final _steamIdDebounce = Debouncer(_autosaveDelay);
  final _familyDebounce = Debouncer(_autosaveDelay);
  late final SettingsController _controller;

  SessionUser get _user => widget.user;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(settingsControllerProvider.notifier);
  }

  @override
  void didUpdateWidget(_IntegrationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_steamIdDebounce.isPending && widget.user.steamId != _steamId.text) {
      _steamId.text = widget.user.steamId;
    }
    if (!_familyDebounce.isPending &&
        widget.user.steamFamilyIds != _family.text) {
      _family.text = widget.user.steamFamilyIds;
    }
  }

  @override
  void dispose() {
    final steamId = _steamIdDebounce;
    final family = _familyDebounce;
    scheduleMicrotask(() {
      steamId.flush();
      family.flush();
    });
    for (final controller in [
      _steamId,
      _family,
      _steamKey,
      _igdbId,
      _igdbSecret,
      _gridKey,
      _discord,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(UserUpdate update, String success) async {
    final error = await ref
        .read(settingsControllerProvider.notifier)
        .save(update);
    if (mounted) showShelfToast(context, error ?? success);
  }

  Future<void> _saveQuietly(UserUpdate update) async {
    final error = await _controller.save(update);
    if (error != null && mounted) showShelfToast(context, error);
  }

  void _autosaveSteamId(String text) {
    _steamIdDebounce.run(() {
      final id = text.trim();
      if (id != _user.steamId) {
        unawaited(_saveQuietly(UserUpdate(steamId: id)));
      }
    });
  }

  void _autosaveFamily(String text) {
    _familyDebounce.run(() {
      final ids = text.trim();
      if (ids != _user.steamFamilyIds) {
        unawaited(_saveQuietly(UserUpdate(steamFamilyIds: ids)));
      }
    });
  }

  void _commitSecret(
    TextEditingController controller,
    String text,
    UserUpdate Function(String value) update,
    String success,
  ) {
    final value = text.trim();
    if (value.isEmpty) return;
    controller.clear();
    unawaited(_save(update(value), success));
  }

  void _commitIgdb(String _) {
    final id = _igdbId.text.trim();
    final secret = _igdbSecret.text.trim();
    if (id.isEmpty || secret.isEmpty) return;
    _igdbId.clear();
    _igdbSecret.clear();
    unawaited(
      _save(
        UserUpdate(igdbClientId: id, igdbClientSecret: secret),
        'IGDB credentials saved',
      ),
    );
  }

  Future<void> _toggleWishlist(bool enabled) {
    return _save(
      UserUpdate(steamWishlistAutoSync: enabled),
      enabled
          ? 'Your wishlist is now synced every hour'
          : 'Automatic wishlist sync turned off',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final open = ref.read(urlOpenerProvider);
    final imported = user.steamWishlistImportedAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TabTitle(
          title: 'Integrations',
          subtitle:
              'Connect the services that provide your library, game data and '
              'covers.',
        ),
        ShelfFormGroup(
          title: 'Steam',
          rows: [
            ShelfFormRow(
              label: 'Steam ID',
              description: 'SteamID64, 17 digits',
              control: SettingsTextField(
                fieldKey: const Key('settings-steam-id'),
                controller: _steamId,
                hintText: '76561197960287930',
                onChanged: _autosaveSteamId,
              ),
            ),
            ShelfFormRow(
              label: 'Web API key',
              description: user.hasSteamApiKey
                  ? 'Your own key is set and used for syncing playtimes.'
                  : "Optional. Falls back to the server's key.",
              control: SecretControl(
                fieldKey: const Key('settings-steam-key'),
                removeKey: const Key('settings-steam-key-remove'),
                controller: _steamKey,
                placeholder: user.hasSteamApiKey
                    ? 'Enter a new key to replace it'
                    : 'Steam Web API key',
                isSet: user.hasSteamApiKey,
                onCommit: (text) => _commitSecret(
                  _steamKey,
                  text,
                  (value) => UserUpdate(steamApiKey: value),
                  'Steam API key saved',
                ),
                onRemove: () => unawaited(
                  _save(
                    const UserUpdate(steamApiKey: ''),
                    'Steam API key removed',
                  ),
                ),
              ),
            ),
            ShelfFormRow(
              label: 'Family members',
              description: 'Comma-separated SteamID64s',
              control: SettingsTextField(
                fieldKey: const Key('settings-family-ids'),
                controller: _family,
                hintText: '76561197960287930, 76561198000000001',
                onChanged: _autosaveFamily,
              ),
            ),
            ShelfFormRow(
              label: 'Sync wishlist hourly',
              description: imported
                  ? 'New wishlist games are added and games that left the '
                        'wishlist are removed - only entries created by the '
                        'wishlist import are touched. After your next '
                        'sign-in you see what changed.'
                  : 'Available after the first wishlist import on the Steam '
                        'page.',
              control: ShelfSwitch(
                key: const Key('settings-wishlist-sync'),
                value: user.steamWishlistAutoSync,
                label: 'Sync my Steam wishlist automatically every hour',
                onChanged: imported
                    ? (v) => unawaited(_toggleWishlist(v))
                    : null,
              ),
            ),
          ],
        ),
        SettingsNote(
          'Games only a family member owns are imported without playtime - '
          'Steam only reports playtime for the account being queried.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: LinkText(
            parts: const [
              LinkPart(
                'Not sure what the Steam ID is? Open your Steam profile page: '
                'if its URL ends in a long number, that is your SteamID64; if '
                'it ends in a custom name, look it up with ',
              ),
              LinkPart(
                "SteamDB's SteamID finder",
                url: 'https://steamdb.com/en/tools/steam-id-finder',
              ),
              LinkPart('. Create or look up an API key on '),
              LinkPart(
                "Steam's API key page",
                url: 'https://steamcommunity.com/dev/apikey',
              ),
              LinkPart('.'),
            ],
            onOpen: open,
          ),
        ),
        const SizedBox(height: 18),
        ShelfFormGroup(
          title: 'IGDB and SteamGridDB',
          description: "Without your own credentials the server's are used.",
          rows: [
            ShelfFormRow(
              label: 'IGDB Client ID',
              description: user.hasIgdbCredentials
                  ? 'Your own credentials are set and used for game search.'
                  : 'Needs the Client Secret as well.',
              control: SettingsTextField(
                fieldKey: const Key('settings-igdb-id'),
                controller: _igdbId,
                hintText: user.hasIgdbCredentials
                    ? 'Enter a new Client ID to replace it'
                    : 'IGDB Client ID',
                onCommit: _commitIgdb,
              ),
            ),
            ShelfFormRow(
              label: 'IGDB Client Secret',
              control: SecretControl(
                fieldKey: const Key('settings-igdb-secret'),
                removeKey: const Key('settings-igdb-remove'),
                controller: _igdbSecret,
                placeholder: user.hasIgdbCredentials
                    ? 'Enter a new Client Secret to replace it'
                    : 'IGDB Client Secret',
                isSet: user.hasIgdbCredentials,
                onCommit: _commitIgdb,
                onRemove: () => unawaited(
                  _save(
                    const UserUpdate(igdbClientId: '', igdbClientSecret: ''),
                    'IGDB credentials removed',
                  ),
                ),
              ),
            ),
            ShelfFormRow(
              label: 'SteamGridDB key',
              description: user.hasSteamgriddbApiKey
                  ? 'Your own key is set and used for cover art.'
                  : 'Cover art',
              control: SecretControl(
                fieldKey: const Key('settings-grid-key'),
                removeKey: const Key('settings-grid-remove'),
                controller: _gridKey,
                placeholder: user.hasSteamgriddbApiKey
                    ? 'Enter a new key to replace it'
                    : 'SteamGridDB API key',
                isSet: user.hasSteamgriddbApiKey,
                onCommit: (text) => _commitSecret(
                  _gridKey,
                  text,
                  (value) => UserUpdate(steamgriddbApiKey: value),
                  'SteamGridDB API key saved',
                ),
                onRemove: () => unawaited(
                  _save(
                    const UserUpdate(steamgriddbApiKey: ''),
                    'SteamGridDB API key removed',
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: LinkText(
            parts: const [
              LinkPart('Create a Twitch application at '),
              LinkPart(
                'dev.twitch.tv/console/apps',
                url: 'https://dev.twitch.tv/console/apps',
              ),
              LinkPart(' to get an IGDB Client ID and Client Secret.'),
            ],
            onOpen: open,
          ),
        ),
        const SizedBox(height: 18),
        ShelfFormGroup(
          title: 'Discord price alerts',
          rows: [
            ShelfFormRow(
              label: 'Webhook URL',
              description: user.hasDiscordWebhookUrl
                  ? 'Your own webhook is set and used for price alerts.'
                  : 'Message when a game you want goes on sale. Falls back to '
                        "the server's webhook.",
              control: SecretControl(
                fieldKey: const Key('settings-discord'),
                removeKey: const Key('settings-discord-remove'),
                controller: _discord,
                placeholder: user.hasDiscordWebhookUrl
                    ? 'Enter a new webhook URL to replace it'
                    : 'https://discord.com/api/webhooks/...',
                isSet: user.hasDiscordWebhookUrl,
                onCommit: (text) => _commitSecret(
                  _discord,
                  text,
                  (value) => UserUpdate(discordWebhookUrl: value),
                  'Discord webhook URL saved',
                ),
                onRemove: () => unawaited(
                  _save(
                    const UserUpdate(discordWebhookUrl: ''),
                    'Discord webhook URL removed',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AboutTab extends ConsumerWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final version = ref.watch(appVersionProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TabTitle(
          title: 'About',
          subtitle: 'The app and where its code lives.',
        ),
        ShelfFormGroup(
          title: 'Backlog Manager',
          rows: [
            ShelfFormRow(
              label: 'Version',
              control: Text(
                version ?? '-',
                key: const Key('settings-version'),
                style: style.control.copyWith(color: tokens.muted),
              ),
            ),
            ShelfFormRow(
              label: 'Source code',
              control: ShelfButton(
                key: const Key('settings-source'),
                label: 'Open on GitHub',
                onPressed: () => ref.read(urlOpenerProvider)(
                  Uri.parse('https://github.com/theoleuthardt/backlog-manager'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
