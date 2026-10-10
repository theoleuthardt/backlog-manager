import 'dart:math' as math;

import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/glow.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _minCoverWidth = 150.0;
const _coverGapColumn = 16.0;
const _coverGapRow = 22.0;

/// The address of [original] through the image proxy of the server at
/// [baseUrl] (`GET /api/images/proxy`), or null when there is no image.
String? proxiedImageUrl(String baseUrl, String? original) {
  if (original == null || original.isEmpty) return null;
  return '$baseUrl/api/images/proxy?url=${Uri.encodeQueryComponent(original)}';
}

/// A 2:3 cover. Without art it shows its title bottom-left on a colour that
/// depends on the title; [selected] adds the accent outline, [selectionMode]
/// the check circle, [progress] and [meta] go below the cover.
class ShelfCover extends StatelessWidget {
  const ShelfCover({
    required this.title,
    this.image,
    this.progress,
    this.meta,
    this.overlay,
    this.footer,
    this.selected = false,
    this.selectionMode = false,
    this.onTap,
    this.onSecondaryTap,
    super.key,
  });

  final String title;
  final ImageProvider? image;
  final double? progress;
  final String? meta;

  /// Drawn over the art, for example badges in the corners; it should lay
  /// itself out with [Positioned].
  final Widget? overlay;

  /// Replaces [progress] and [meta] below the cover, for example one bar per
  /// member of a shared space.
  final Widget? footer;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTap == null
          ? null
          : (details) => onSecondaryTap!(details.globalPosition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            key: const Key('cover-art'),
            aspectRatio: 2 / 3,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    key: const Key('cover-shadow'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ShelfRadius.card),
                      boxShadow: ShelfGlow.coverShadow(tokens),
                    ),
                    child: ClipRRect(
                      key: const Key('cover-clip'),
                      borderRadius: BorderRadius.circular(ShelfRadius.card),
                      child: _art(text),
                    ),
                  ),
                ),
                if (overlay != null) Positioned.fill(child: overlay!),
                if (selected)
                  Positioned(
                    left: -6,
                    top: -6,
                    right: -6,
                    bottom: -6,
                    child: IgnorePointer(
                      child: ClipPath(
                        key: const Key('cover-ring-clip'),
                        clipper: const _OutsideOfRing(
                          width: 3,
                          radius: ShelfRadius.card + 6,
                        ),
                        child: DecoratedBox(
                          key: const Key('cover-ring'),
                          decoration: ShelfGlow.selectedRing(
                            tokens,
                            radius: ShelfRadius.card + 6,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (selectionMode)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _CheckCircle(checked: selected),
                  ),
              ],
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer!,
          ] else ...[
            if (progress != null) ...[
              const SizedBox(height: 8),
              ShelfProgressBar(value: progress!, height: 3),
            ],
            if (meta != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.caption.copyWith(color: tokens.muted),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _art(ShelfTextStyles text) {
    final fallback = _Fallback(title: title);
    if (image == null) return fallback;
    return Image(
      image: image!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

/// Keeps only what lies outside the inner edge of the ring, so the glow of
/// the ring does not tint the cover below it.
class _OutsideOfRing extends CustomClipper<Path> {
  const _OutsideOfRing({required this.width, required this.radius});

  final double width;
  final double radius;

  @override
  Path getClip(Size size) {
    final inner = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width),
      Radius.circular(radius - width),
    );
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(-100, -100, size.width + 200, size.height + 200))
      ..addRRect(inner);
  }

  @override
  bool shouldReclip(_OutsideOfRing oldClipper) {
    return oldClipper.width != width || oldClipper.radius != radius;
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    final hue = title.codeUnits.fold<int>(
      0,
      (sum, unit) => (sum * 31 + unit) % 360,
    );
    final start = HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.34).toColor();

    return DecoratedBox(
      key: const Key('cover-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            start,
            HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.12).toColor(),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: text.coverTitle.copyWith(color: onColorFor(start)),
          ),
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    return DecoratedBox(
      key: const Key('cover-check'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? tokens.accent : tokens.scrim,
        border: Border.all(
          color: checked ? tokens.accent : tokens.foreground,
          width: 1.5,
        ),
      ),
      child: SizedBox(
        width: 22,
        height: 22,
        child: checked
            ? Icon(Icons.check, size: 14, color: tokens.onAccent)
            : null,
      ),
    );
  }
}

/// How many covers of at least 150 px fit into a row of [width].
int coverGridColumns(double width, {double gap = _coverGapColumn}) {
  return math.max(1, ((width + gap) / (_minCoverWidth + gap)).floor());
}

/// The width of one cover when [columns] of them fill a row of [width].
double coverWidthFor(
  double width, {
  required int columns,
  double gap = _coverGapColumn,
}) {
  return (width - (columns - 1) * gap) / columns;
}

class _CoverGridDelegate extends SliverGridDelegate {
  const _CoverGridDelegate(this.extraHeight);

  final double extraHeight;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final columns = coverGridColumns(width);
    final cover = coverWidthFor(width, columns: columns);
    final extent = cover * 1.5 + extraHeight;
    return SliverGridRegularTileLayout(
      crossAxisCount: columns,
      mainAxisStride: extent + _coverGapRow,
      crossAxisStride: cover + _coverGapColumn,
      childMainAxisExtent: extent,
      childCrossAxisExtent: cover,
      reverseCrossAxis: false,
    );
  }

  @override
  bool shouldRelayout(_CoverGridDelegate oldDelegate) {
    return oldDelegate.extraHeight != extraHeight;
  }
}

/// An auto-fill grid of covers (at least 150 px wide, 16 px between columns
/// and 22 px between rows). [extraHeight] is the room below each cover for
/// its progress bar and meta line.
class ShelfCoverGrid extends StatelessWidget {
  const ShelfCoverGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.extraHeight = 0,
    this.controller,
    this.padding,
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final double extraHeight;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      gridDelegate: _CoverGridDelegate(extraHeight),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// The grid of [ShelfCoverGrid] as a sliver, for screens that put several
/// grids and headers into one scroll view.
class ShelfCoverSliverGrid extends StatelessWidget {
  const ShelfCoverSliverGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.extraHeight = 0,
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final double extraHeight;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: _CoverGridDelegate(extraHeight),
      delegate: SliverChildBuilderDelegate(
        (context, index) => itemBuilder(context, index),
        childCount: itemCount,
      ),
    );
  }
}

/// A horizontal, non-wrapping row of 150 px wide covers.
class ShelfRow extends StatelessWidget {
  const ShelfRow({
    required this.itemCount,
    required this.itemBuilder,
    this.extraHeight = 0,
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final double extraHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _minCoverWidth * 1.5 + extraHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            const SizedBox(width: _coverGapColumn),
        itemBuilder: (context, index) =>
            SizedBox(width: _minCoverWidth, child: itemBuilder(context, index)),
      ),
    );
  }
}
