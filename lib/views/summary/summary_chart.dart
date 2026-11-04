import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../core/date_key.dart';
import '../../core/metrics.dart';
import '../../core/summary_math.dart';

/// Bar chart of one metric's per-day average for each bucket, with the goal as
/// a dashed reference line. Buckets with no logged days draw no bar. With a
/// goal, each bar is colored by whether it is under, on (within
/// [goalTolerance]) or over the goal, with a legend below. VoiceOver reads a
/// text summary instead of the bars.
class SummaryChart extends StatelessWidget {
  const SummaryChart({
    super.key,
    required this.buckets,
    required this.metric,
    required this.goal,
    required this.bucketSize,
  });

  final List<Bucket> buckets;
  final Metric metric;
  final double? goal;
  final BucketSize bucketSize;

  /// At most this many x-axis labels, so they never overlap.
  static const _maxLabels = 6;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final b in buckets)
        b.averages == null ? 0.0 : metric.amountIn(b.averages!),
    ];
    final hasGoal = goal != null && goal! > 0;
    var highest = hasGoal ? goal! : 0.0;
    for (final v in values) {
      if (v > highest) highest = v;
    }
    final labelEvery = (buckets.length / _maxLabels).ceil();
    final underColor = CupertinoColors.activeBlue.resolveFrom(context);
    final onTargetColor = CupertinoColors.systemGreen.resolveFrom(context);
    final overColor = CupertinoColors.systemRed.resolveFrom(context);
    Color colorFor(double value) => !hasGoal
        ? underColor
        : switch (goalStatus(value, goal!)) {
            GoalStatus.under => underColor,
            GoalStatus.onTarget => onTargetColor,
            GoalStatus.over => overColor,
          };
    final goalColor = CupertinoColors.systemOrange.resolveFrom(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    final chart = SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: highest <= 0 ? 1 : highest * 1.15,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: colorFor(values[i]),
                    width: buckets.length > 12 ? 6 : 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (hasGoal)
                HorizontalLine(
                  y: goal!,
                  color: goalColor,
                  strokeWidth: 1.5,
                  dashArray: const [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: TextStyle(fontSize: 11, color: goalColor),
                    labelResolver: (_) =>
                        'Goal ${metric.format(goal!)} ${metric.unit}',
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= buckets.length || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      _axisLabel(buckets[i]),
                      style: TextStyle(fontSize: 11, color: labelColor),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final bucket = buckets[group.x];
                final value = bucket.daysLogged == 0
                    ? 'Nothing logged'
                    : '${metric.format(rod.toY)} ${metric.unit}';
                return BarTooltipItem(
                  '${_axisLabel(bucket)}\n$value',
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
        ),
      ),
    );

    return Semantics(
      key: const Key('summary-chart-semantics'),
      container: true,
      label: _describe(values),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            chart,
            if (hasGoal) ...[
              const SizedBox(height: 8),
              Wrap(
                key: const Key('summary-legend'),
                spacing: 16,
                runSpacing: 4,
                children: [
                  _LegendItem(color: underColor, label: 'Under goal'),
                  _LegendItem(
                    color: onTargetColor,
                    label:
                        'Within ${(goalTolerance * 100).round()}% of the goal',
                  ),
                  _LegendItem(color: overColor, label: 'Over goal'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// What VoiceOver reads for the chart: the average, the highest bar, and how
  /// many bars are on target when there is a goal.
  String _describe(List<double> values) {
    final logged = [
      for (var i = 0; i < buckets.length; i++)
        if (buckets[i].daysLogged > 0) (bucket: buckets[i], value: values[i]),
    ];
    if (logged.isEmpty) return '${metric.label} chart. Nothing logged.';
    String amount(double v) => '${metric.format(v)} ${metric.unit}';
    final top = logged.reduce((a, b) => b.value > a.value ? b : a);
    final mean =
        logged.map((l) => l.value).reduce((a, b) => a + b) / logged.length;
    final parts = [
      '${metric.label} chart, ${logged.length} of ${buckets.length} bars '
          'with data',
      'average ${amount(mean)}',
      'highest ${amount(top.value)} on ${_axisLabel(top.bucket)}',
      if (goal != null && goal! > 0)
        '${logged.where((l) => goalStatus(l.value, goal!) == GoalStatus.onTarget).length} '
            'on target for the goal of ${amount(goal!)}',
    ];
    return '${parts.join(', ')}.';
  }

  String _axisLabel(Bucket bucket) {
    final start = dateFromKey(bucket.startKey);
    return switch (bucketSize) {
      BucketSize.day when buckets.length <= 7 => DateFormat(
        'EEE',
      ).format(start),
      BucketSize.day => DateFormat('d').format(start),
      BucketSize.week => DateFormat('MMM d').format(start),
      BucketSize.month => DateFormat('MMM').format(start),
    };
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: const SizedBox(width: 10, height: 10),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}
