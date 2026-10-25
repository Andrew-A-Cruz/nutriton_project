import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../core/body_weight.dart';
import '../../core/date_key.dart';

/// Line chart of body weight over a range: the readings as dots joined by a
/// faint line, and the [movingAverageDays]-day moving average as a solid line.
/// [readings] may start before [startKey] so the first averages are complete;
/// only days from [startKey] to [endKey] are drawn.
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.readings,
    required this.startKey,
    required this.endKey,
    required this.unit,
  });

  final List<WeightReading> readings;
  final String startKey;
  final String endKey;
  final BodyWeightUnit unit;

  /// At most this many x-axis labels, so they never overlap.
  static const _maxLabels = 5;

  static DateTime _utc(String key) {
    final d = dateFromKey(key);
    return DateTime.utc(d.year, d.month, d.day);
  }

  DateTime get _start => _utc(startKey);

  /// Days from [startKey] to [date].
  double _x(String date) => _utc(date).difference(_start).inDays.toDouble();

  @override
  Widget build(BuildContext context) {
    final average = movingAverage(readings);
    bool inRange(String d) =>
        d.compareTo(startKey) >= 0 && d.compareTo(endKey) <= 0;
    final raw = [
      for (final r in readings)
        if (inRange(r.date)) FlSpot(_x(r.date), unit.fromKg(r.kg)),
    ];
    final smooth = [
      for (final r in average)
        if (inRange(r.date)) FlSpot(_x(r.date), unit.fromKg(r.kg)),
    ];
    final days = _x(endKey).toInt();

    var low = raw.first.y;
    var high = raw.first.y;
    for (final p in raw) {
      if (p.y < low) low = p.y;
      if (p.y > high) high = p.y;
    }
    final pad = (high - low) < 1 ? 1.0 : (high - low) * 0.15;

    final lineColor = CupertinoColors.activeBlue.resolveFrom(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final labelEvery = ((days + 1) / _maxLabels).ceil();
    final dots = raw.length <= 31;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: days.toDouble(),
          minY: low - pad,
          maxY: high + pad,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      plainWeight(value),
                      style: TextStyle(fontSize: 11, color: labelColor),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i > days || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      DateFormat('MMM d').format(addDaysTo(_start, i)),
                      style: TextStyle(fontSize: 11, color: labelColor),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${DateFormat('MMM d').format(addDaysTo(_start, s.x.toInt()))}'
                    '\n${plainWeight(s.y)} ${unit.name}',
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: raw,
              color: lineColor.withValues(alpha: 0.35),
              barWidth: 1,
              dotData: FlDotData(show: dots),
            ),
            LineChartBarData(
              spots: smooth,
              color: lineColor,
              barWidth: 2.5,
              isCurved: false,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  /// One decimal place without a trailing zero.
  static String plainWeight(double value) =>
      NumberFormat('#,##0.#').format(value);

  /// [start] moved forward [days] calendar days (UTC, so no DST shifts).
  static DateTime addDaysTo(DateTime start, int days) =>
      DateTime.utc(start.year, start.month, start.day + days);
}
