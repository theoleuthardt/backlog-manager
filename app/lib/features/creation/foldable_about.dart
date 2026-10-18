import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/material.dart';

const _foldedLines = 4;
const _unfoldedMaxHeight = 240.0;

/// The About text of a game in the side column of the creation tool: folded it
/// has the fixed height of four lines, "Show more" unfolds it up to a maximum
/// height and scrolls what is beyond that. A text that fits has no toggle.
class FoldableAbout extends StatefulWidget {
  const FoldableAbout({required this.text, super.key});

  final String text;

  @override
  State<FoldableAbout> createState() => _FoldableAboutState();
}

class _FoldableAboutState extends State<FoldableAbout> {
  bool _unfolded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context)
        .extension<ShelfTextStyles>()!
        .caption
        .copyWith(color: tokens.text2, height: 1.5);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: _foldedLines,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        final foldedHeight = painter.height;
        painter.dispose();
        final full = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final fullHeight = full.height;
        full.dispose();

        final height = !overflows
            ? fullHeight
            : _unfolded
            ? fullHeight.clamp(foldedHeight, _unfoldedMaxHeight)
            : foldedHeight;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              key: const Key('creation-about'),
              height: height,
              child: SingleChildScrollView(
                physics: _unfolded
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: Text(widget.text, style: style),
              ),
            ),
            if (overflows)
              InkWell(
                key: const Key('creation-about-toggle'),
                onTap: () => setState(() => _unfolded = !_unfolded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _unfolded ? 'Show less' : 'Show more',
                    style: style.copyWith(color: tokens.accent),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
