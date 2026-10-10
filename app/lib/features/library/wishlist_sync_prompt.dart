import 'package:backlog_manager/data/wishlist_sync_api.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/wishlist_sync_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows [child] and, when the automatic Steam wishlist sync changed the
/// backlog since the user last looked, opens the information-only sheet with
/// the diff once. Closing the sheet clears the report on the server. A report
/// that cannot be loaded is ignored: it is only a notice.
class WishlistSyncPrompt extends ConsumerStatefulWidget {
  const WishlistSyncPrompt({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WishlistSyncPrompt> createState() => _WishlistSyncPromptState();
}

class _WishlistSyncPromptState extends ConsumerState<WishlistSyncPrompt> {
  WishlistSyncReport? _shown;

  void _show(WishlistSyncReport report) {
    if (identical(report, _shown) || !report.hasChanges) return;
    _shown = report;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final api = ref.read(wishlistSyncApiProvider);
      final container = ProviderScope.containerOf(context);
      await showShelfSheet<void>(
        context,
        builder: (context) => WishlistSyncSheet(report: report),
      );
      try {
        final updatedAt = report.updatedAt;
        if (updatedAt != null) await api.dismiss(updatedAt);
      } on Object {
        return;
      }
      container.invalidate(wishlistSyncReportProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wishlistSyncReportProvider, (_, next) {
      final report = next.value;
      if (report != null) _show(report);
    });
    final report = ref.read(wishlistSyncReportProvider).value;
    if (report != null) _show(report);
    return widget.child;
  }
}

/// The diff of the wishlist sync: the games removed in red with a minus, the
/// games added in green with a plus.
class WishlistSyncSheet extends StatelessWidget {
  const WishlistSyncSheet({required this.report, super.key});

  final WishlistSyncReport report;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return ShelfSheet(
      title: 'Your Steam wishlist changed',
      description: report.summary,
      width: ShelfSheetWidth.compact,
      footer: Align(
        alignment: Alignment.centerRight,
        child: ShelfButton(
          key: const Key('wishlist-sync-close'),
          label: 'Close',
          kind: ShelfButtonKind.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in report.diffRows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${row.sign} ${row.change.title}',
                    key: Key('diff-${row.sign}-${row.change.steamAppId}'),
                    overflow: TextOverflow.ellipsis,
                    style: style.control.copyWith(
                      color: row.sign == '+' ? tokens.success : tokens.danger,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
