import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
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
      semanticLabel: 'Watch trailer',
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.accent,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.play_arrow, size: 26, color: Colors.black),
                ),
              ),
              const SizedBox(height: 12),
              Text('Watch trailer', style: style.section),
              const SizedBox(height: 2),
              Text(
                'Opens on YouTube',
                style: style.caption.copyWith(color: tokens.muted),
              ),
            ],
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
