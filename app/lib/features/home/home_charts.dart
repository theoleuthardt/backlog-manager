import 'package:backlog_manager/design/color_math.dart';
import 'package:backlog_manager/design/shelf_metrics.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/domain/home_logic.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/status_style.dart';
import 'package:flutter/material.dart';

/// Below this width the charts stand below each other.
const _chartsInOneRow = 900.0;

const _monthLetters = 'JFMAMJJASOND';
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The charts of the home screen: the backlog by status, the most common
/// genres and the games completed per month. Every chart is one measure, so
/// the bars share the accent colour and carry their numbers beside them; a
/// status keeps the colour of its dot from the library.
class HomeCharts extends StatelessWidget {
  const HomeCharts({required this.entries, required this.now, super.key});

  final List<BacklogEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final genres = topGenres(entries);
    final charts = [
      _ChartCard(
        chartKey: 'home-chart-status',
        title: 'By Status',
        child: _BarList(
          rows: statusCounts(entries),
          dotColor: (label) => colorFromHex(statusColor(label)),
        ),
      ),
      if (genres.isNotEmpty)
        _ChartCard(
          chartKey: 'home-chart-genres',
          title: 'Top Genres',
          child: _BarList(rows: genres),
        ),
      _ChartCard(
        chartKey: 'home-chart-months',
        title: 'Completed per Month',
        child: _MonthBars(months: monthlyCompletions(entries, now: now)),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _chartsInOneRow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, chart) in charts.indexed) ...[
                  if (index > 0) const SizedBox(height: 14),
                  chart,
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, chart) in charts.indexed) ...[
                  if (index > 0) const SizedBox(width: 14),
                  Expanded(child: chart),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.chartKey,
    required this.title,
    required this.child,
  });

  final String chartKey;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    return DecoratedBox(
      key: Key(chartKey),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(ShelfRadius.card),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: style.label.copyWith(color: tokens.muted)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A bar per row, scaled to the largest one, with its label and number; a
/// [dotColor] puts the dot of the label in front of it.
class _BarList extends StatelessWidget {
  const _BarList({required this.rows, this.dotColor});

  final List<HomeCount> rows;
  final Color Function(String label)? dotColor;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final largest = rows.isEmpty ? 1 : rows.first.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (dotColor case final color?) ...[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: color(row.label),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(dimension: 8),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.caption.copyWith(
                            color: tokens.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${row.count}',
                        style: style.caption.copyWith(color: tokens.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: row.count / largest,
                      child: ColoredBox(
                        color: tokens.accent,
                        child: const SizedBox(height: 6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A column per month, the initial below it and the number of the best month
/// and of the current one above it; the tooltip names month and number.
class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.months});

  final List<({DateTime month, int count})> months;

  static const _height = 96.0;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final counts = months.map((month) => month.count);
    final largest = counts.reduce((a, b) => a > b ? a : b);
    final caption = style.caption.copyWith(color: tokens.muted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, month) in months.indexed)
          Expanded(
            child: Tooltip(
              message:
                  '${_monthNames[month.month.month - 1]} '
                  '${month.month.year}: ${month.count}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (month.count > 0 &&
                        (month.count == largest || index == months.length - 1))
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${month.count}', style: caption),
                      ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: _height,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: month.count == 0
                            ? ColoredBox(
                                color: tokens.borderSubtle,
                                child: const SizedBox(
                                  width: double.infinity,
                                  height: 2,
                                ),
                              )
                            : ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                                child: ColoredBox(
                                  color: tokens.accent,
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: _height * month.count / largest,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_monthLetters[month.month.month - 1], style: caption),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
