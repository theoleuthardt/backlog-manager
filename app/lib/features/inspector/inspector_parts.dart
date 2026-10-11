import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/pressable.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/domain/inspector_logic.dart';
import 'package:backlog_manager/features/inspector/entry_autosave.dart';
import 'package:flutter/material.dart';

/// A labelled block of the stat area: a small upper-case label over [child].
class StatTile extends StatelessWidget {
  const StatTile({
    required this.icon,
    required this.label,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(ShelfRadius.control),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: tokens.muted),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: style.keyHint.copyWith(color: tokens.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// "Main story  22 h" over a bar that fills with the hours played.
class TimeBar extends StatelessWidget {
  const TimeBar({
    required this.label,
    required this.hours,
    required this.playtime,
    super.key,
  });

  final String label;
  final double? hours;
  final double? playtime;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: style.caption.copyWith(color: tokens.muted)),
            const Spacer(),
            Text(beatHoursLabel(hours), style: style.label),
          ],
        ),
        const SizedBox(height: 6),
        ShelfProgressBar(value: beatFraction(hours, playtime)),
      ],
    );
  }
}

/// A multi-line text input in the style of the form fields.
class ShelfTextArea extends StatelessWidget {
  const ShelfTextArea({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.enabled = true,
    this.minLines = 4,
    this.fieldKey,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final bool enabled;
  final int minLines;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: style.label.copyWith(color: tokens.muted)),
        const SizedBox(height: 6),
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: TextField(
            key: fieldKey,
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: null,
            style: style.fieldText,
            decoration: InputDecoration(hintText: hintText),
          ),
        ),
      ],
    );
  }
}

/// The card of the trailer tab: a large play button that opens the video.
class TrailerCard extends StatelessWidget {
  const TrailerCard({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return ShelfPressable(
      borderRadius: ShelfRadius.card,
      semanticLabel: 'Watch Trailer',
      onPressed: onPressed,
      builder: (context, state) => DecoratedBox(
        key: const Key('trailer-card'),
        decoration: BoxDecoration(
          color: state.hovered ? tokens.glowSoft : tokens.surface,
          borderRadius: BorderRadius.circular(ShelfRadius.card),
          border: Border.all(
            color: state.hovered ? tokens.borderStrong : tokens.borderSubtle,
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(
                      Icons.play_arrow,
                      size: 26,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Watch Trailer', style: style.section),
                const SizedBox(height: 2),
                Text(
                  'Plays in a window',
                  style: style.caption.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The save state in the header: "Changes save automatically", "Saving...",
/// "All changes saved" or "Not saved".
class SaveStatus extends StatelessWidget {
  const SaveStatus({required this.state, required this.dirty, super.key});

  final SaveState state;

  /// Whether the form differs from the stored entry.
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final muted = style.caption.copyWith(color: tokens.muted);

    final Widget content;
    if (state == SaveState.error) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.close, size: 13, color: tokens.danger),
          const SizedBox(width: 6),
          Text('Not saved', style: muted.copyWith(color: tokens.danger)),
        ],
      );
    } else if (state == SaveState.saving || dirty) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 6),
          Text('Saving...', style: muted),
        ],
      );
    } else if (state == SaveState.saved) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.success,
              shape: BoxShape.circle,
            ),
            child: const SizedBox(width: 6, height: 6),
          ),
          const SizedBox(width: 6),
          Text('All changes saved', style: muted),
        ],
      );
    } else {
      content = Text('Changes save automatically', style: muted);
    }
    return Semantics(
      key: const Key('save-status'),
      liveRegion: true,
      container: true,
      child: content,
    );
  }
}

/// A small label over a wrapping row of chips: the genres or the platforms of
/// a game beside its cover. With [maxLines] the chips fill at most that many
/// lines and the rest is a "+N" chip that opens a popover with all of them, so
/// the block keeps a height that fits beside the cover; without it they all
/// wrap.
class FactChips extends StatelessWidget {
  const FactChips({
    required this.label,
    required this.values,
    this.maxLines,
    super.key,
  });

  final String label;
  final List<String> values;
  final int? maxLines;

  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final direction = Directionality.of(context);

    double chipWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style.label),
        textDirection: direction,
        maxLines: 1,
      )..layout();
      return painter.width + 22;
    }

    Widget chips(List<String> shown, {Widget? more}) => Wrap(
      spacing: _gap,
      runSpacing: _gap,
      children: [
        for (final value in shown) ShelfChip(label: value),
        ?more,
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: style.eyebrow.copyWith(color: tokens.faint),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final lines = maxLines;
            if (lines == null) return chips(values);

            final available = constraints.maxWidth;
            final widths = [for (final value in values) chipWidth(value)];
            var fitting = _fit(widths, available, lines, reserve: 0);
            if (fitting == values.length) return chips(values);

            var hidden = values.length - fitting;
            final more = chipWidth('+$hidden') + 4;
            fitting = _fit(widths, available, lines, reserve: more + _gap);
            hidden = values.length - fitting;
            return chips(
              values.sublist(0, fitting),
              more: ShelfPopover(
                content: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(width: 280, child: chips(values)),
                ),
                builder: (context, menu) => ShelfChip(
                  key: Key('${label.toLowerCase()}-more'),
                  label: '+$hidden',
                  kind: ShelfChipKind.accent,
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// How many chips of [widths] fit on [lines] lines of [available] width,
  /// keeping [reserve] free at the end of the last line.
  static int _fit(
    List<double> widths,
    double available,
    int lines, {
    required double reserve,
  }) {
    var line = 1;
    var used = 0.0;
    var count = 0;
    for (final width in widths) {
      final needed = (used == 0 ? 0 : _gap) + width;
      if (used + needed > available) {
        if (line == lines) break;
        line++;
        used = width;
      } else {
        used += needed;
      }
      count++;
    }
    if (reserve > 0) {
      while (count > 0) {
        final lastLineUsed = _lastLineUse(widths, available, count);
        if (lastLineUsed + reserve <= available) break;
        count--;
      }
    }
    return count;
  }

  static double _lastLineUse(List<double> widths, double available, int count) {
    var used = 0.0;
    for (var i = 0; i < count; i++) {
      final needed = (used == 0 ? 0 : _gap) + widths[i];
      used = used + needed > available ? widths[i] : used + needed;
    }
    return used;
  }
}
