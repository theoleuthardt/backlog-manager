import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows [builder] once the personal entries are loaded. Until then it shows
/// "Loading your backlog...", and when loading failed the message of the
/// error with a button to try again. A reload that fails later keeps the list
/// on screen.
class EntriesGate extends ConsumerWidget {
  const EntriesGate({required this.builder, super.key});

  final Widget Function(BuildContext context, List<BacklogEntry> entries)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider(null));
    return entries.when(
      skipLoadingOnRefresh: true,
      loading: () => const CenteredMessage(text: 'Loading your backlog...'),
      error: (error, _) => CenteredMessage(
        text: ApiException.from(error, 'Could not load your backlog').message,
        action: ShelfButton(
          label: 'Try again',
          onPressed: () => ref.invalidate(entriesProvider(null)),
        ),
      ),
      data: (list) => builder(context, list),
    );
  }
}

/// A line of text in the middle of a page with an optional action below.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({required this.text, this.action, super.key});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: style.body.copyWith(color: tokens.text2)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
