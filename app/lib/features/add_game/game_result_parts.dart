import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/data/entry_image.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/spinner.dart';
import 'package:backlog_manager/design/widgets/table.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A small cover through the image proxy, or a plain block without one.
class ResultThumb extends ConsumerWidget {
  const ResultThumb({
    required this.imageUrl,
    this.width = 30,
    this.height = 45,
    super.key,
  });

  final String? imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final image = imageUrl == null || imageUrl!.isEmpty
        ? null
        : entryImage(ref.watch(serverUrlProvider).value, imageUrl!);
    final block = ColoredBox(color: tokens.surface3);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: height,
        child: image == null
            ? block
            : Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => block,
              ),
      ),
    );
  }
}

/// A centred line of muted text for the empty and loading states of a sheet.
class SheetNote extends StatelessWidget {
  const SheetNote(this.text, {this.busy = false, this.noteKey, super.key});

  final String text;
  final bool busy;
  final Key? noteKey;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        key: noteKey,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy) ...[
            const ShelfSpinner(size: 24),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: style.caption.copyWith(color: tokens.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Esc" or "Enter" key hint after a button label.
class KeyHint extends StatelessWidget {
  const KeyHint(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(label, style: style.keyHint),
      ),
    );
  }
}

/// The columns of a list of game search results, shared by the sheet that adds
/// a game and the sheet that replaces the game of an entry: the cover with the
/// title and the platforms, the genres, and the times to beat. Long texts wrap.
/// A result whose id is in [deeper] carries a "Found by deeper search" chip.
List<ShelfColumn<GameSearchResult>> gameResultColumns(
  BuildContext context, {
  Set<int> deeper = const {},
}) {
  final tokens = Theme.of(context).extension<ShelfTokens>()!;
  final style = Theme.of(context).extension<ShelfTextStyles>()!;
  return [
    ShelfColumn(
      header: 'Game',
      flex: 5,
      cell: (context, result) => Row(
        children: [
          ResultThumb(imageUrl: result.imageUrl, width: 58, height: 87),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: style.control.copyWith(fontWeight: FontWeight.w700),
                ),
                if (result.platforms.isNotEmpty)
                  Text(
                    result.platforms.join(', '),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: style.caption.copyWith(color: tokens.faint),
                  ),
                if (deeper.contains(result.id))
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: ShelfChip(
                      key: Key('deeper-marker'),
                      label: 'Found by deeper search',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    ShelfColumn(
      header: 'Genre',
      flex: 3,
      cell: (context, result) => Text(
        result.genres.join(', '),
        softWrap: true,
        overflow: TextOverflow.visible,
        style: style.caption.copyWith(color: tokens.muted),
      ),
    ),
    ShelfColumn(
      header: 'Time to beat',
      flex: 3,
      cell: (context, result) => Text(
        result.timesLabel,
        textAlign: TextAlign.right,
        style: style.caption.copyWith(color: tokens.muted),
      ),
    ),
  ];
}
