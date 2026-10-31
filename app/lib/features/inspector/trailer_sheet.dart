import 'dart:math' as math;

import 'package:backlog_manager/design/form_factor.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/domain/trailer.dart';
import 'package:backlog_manager/platform/trailer_player.dart';
import 'package:backlog_manager/platform/trailer_window.dart';
import 'package:backlog_manager/platform/url_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays the trailer of a game in a sheet over the window, in the largest
/// 16:9 area that fits (on a touch screen the whole width of a phone, most
/// of the height in landscape). Where the platform has no embedded player (Linux) the
/// trailer plays in a window of its own. [link] must be a canonical YouTube watch
/// address (`youtubeEmbedUrl`); anything else is ignored.
Future<void> showTrailer(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String? link,
}) async {
  final embed = youtubeEmbedUrl(link);
  if (embed == null || link == null) return;
  final watch = Uri.parse(link);
  final embedUrl = Uri.parse(embed);
  final player = ref.read(trailerPlayerBuilderProvider)(context, embedUrl);
  if (player == null) {
    await ref.read(trailerWindowOpenerProvider)(embedUrl, watch);
    return;
  }
  await showShelfSheet<void>(
    context,
    builder: (_) => TrailerSheet(title: title, watchUrl: watch, player: player),
  );
}

/// The trailer sheet: the title, the player and, always, the link that opens
/// the video on YouTube for the case that it does not play in the app
/// (YouTube refuses some embeds).
class TrailerSheet extends ConsumerWidget {
  const TrailerSheet({
    required this.title,
    required this.watchUrl,
    required this.player,
    super.key,
  });

  final String title;
  final Uri watchUrl;
  final Widget player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final screen = MediaQuery.of(context).size;
    final double width;
    if (ShelfFormFactor.isTouch(context)) {
      width = math.min(screen.width - 32, (screen.height - 120) * 16 / 9);
    } else {
      final fits = math.min(screen.width - 80, (screen.height - 230) * 16 / 9);
      width = fits.clamp(360.0, 1080.0);
    }

    return SizedBox(
      width: width,
      child: ShelfSheet(
        title: title,
        width: ShelfSheetWidth.wide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                key: const Key('trailer-player'),
                aspectRatio: 16 / 9,
                child: ColoredBox(color: Colors.black, child: player),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Video not playing? ',
                  style: style.caption.copyWith(color: tokens.muted),
                ),
                ShelfPressable(
                  key: const Key('trailer-watch-on-youtube'),
                  semanticLabel: 'Watch it on YouTube',
                  onPressed: () => ref.read(urlOpenerProvider)(watchUrl),
                  builder: (context, state) => Text(
                    'Watch it on YouTube',
                    style: style.caption.copyWith(
                      color: tokens.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
