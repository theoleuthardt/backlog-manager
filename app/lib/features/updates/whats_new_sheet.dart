import 'package:backlog_manager/data/whats_new.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the changes of a new version may show; tests switch it off so that
/// no sheet waits on the home page of theirs.
bool whatsNewEnabled = true;

/// Shows [child] and, the first time the home page opens after an update, a
/// sheet with what is new in the installed version ([whatsNewProvider]); once
/// it is closed it does not come again for that version.
class WhatsNewPrompt extends ConsumerStatefulWidget {
  const WhatsNewPrompt({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WhatsNewPrompt> createState() => _WhatsNewPromptState();
}

class _WhatsNewPromptState extends ConsumerState<WhatsNewPrompt> {
  var _shown = false;

  void _maybeShow(WhatsNew? news) {
    if (news == null || _shown) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showShelfSheet<void>(
        context,
        builder: (_) => WhatsNewSheet(news: news),
      );
      if (mounted) await ref.read(whatsNewProvider.notifier).seen();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (whatsNewEnabled) {
      ref.listen(whatsNewProvider, (_, next) => _maybeShow(next.value));
      _maybeShow(ref.read(whatsNewProvider).value);
    }
    return widget.child;
  }
}

/// The changes of [news], one line each, with the release page of the
/// version behind "Release Notes".
class WhatsNewSheet extends ConsumerWidget {
  const WhatsNewSheet({required this.news, super.key});

  final WhatsNew news;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return ShelfSheet(
      key: const Key('whats-new'),
      title: "What's New in ${news.version}",
      description: 'This update of Backlog Manager brings these changes.',
      width: ShelfSheetWidth.compact,
      onClose: () => Navigator.of(context).pop(),
      footer: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          ShelfButton(
            key: const Key('whats-new-release'),
            label: 'Release Notes',
            icon: Icons.open_in_new,
            kind: ShelfButtonKind.quiet,
            onPressed: () => ref.read(urlOpenerProvider)(news.pageUrl),
          ),
          ShelfButton(
            key: const Key('whats-new-done'),
            label: 'Got It',
            kind: ShelfButtonKind.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final change in news.changes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 6, height: 6),
                    ),
                  ),
                  Expanded(child: Text(change, style: style.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
