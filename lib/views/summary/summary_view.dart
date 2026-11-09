import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/body_weight.dart';
import '../../core/date_key.dart';
import '../../core/macro_split.dart';
import '../../core/metrics.dart';
import '../../core/report.dart';
import '../../core/summary_math.dart';
import '../../data/preferences/user_preferences.dart';
import '../../data/report/report_pdf.dart';
import '../../providers/body_weight_providers.dart';
import '../../providers/preferences_providers.dart';
import '../../providers/report_providers.dart';
import '../../providers/summary_providers.dart';
import '../../providers/today_providers.dart';
import '../common/error_feedback.dart';
import '../common/macro_split_bar.dart';
import '../home/macro_summary.dart' show showMacroSplit;
import '../common/pro_gate.dart';
import 'summary_chart.dart';
import 'weight_chart.dart';

/// The Summary tab: a range picker, averages per logged day for each tracked
/// metric, and a bar chart of the primary metric.
class SummaryView extends ConsumerWidget {
  const SummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(summaryRangeProvider);
    final settings = ref.watch(preferencesProvider);
    final endDate = ref.watch(summaryEndProvider);
    final reportAsync = ref.watch(
      summaryReportProvider((endDate: endDate, range: range)),
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Summary'),
        trailing: ProGate(
          child: _ShareReportButton(endDate: endDate, range: range),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            CupertinoSlidingSegmentedControl<SummaryRange>(
              key: const Key('summary-range'),
              groupValue: range,
              children: {for (final r in SummaryRange.values) r: Text(r.label)},
              onValueChanged: (r) {
                if (r != null) {
                  ref.read(summaryRangeProvider.notifier).select(r);
                }
              },
            ),
            const SizedBox(height: 8),
            _PeriodRow(range: range, endDate: endDate),
            const SizedBox(height: 8),
            reportAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CupertinoActivityIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.only(top: 48),
                child: LoadErrorText(
                  failed: 'Could not load the summary',
                  error: error,
                  stack: stack,
                ),
              ),
              data: (report) => _ReportBody(report: report, settings: settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report, required this.settings});

  final SummaryReport report;
  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = settings.primaryMetric;
    final metrics = [primary, ...settings.secondaryMetrics];
    final averages = report.averages;
    final goal = settings.goalFor(primary);
    // Dynamic colors must be resolved, or dark mode gets the light variant.
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          children: [
            const _SectionLabel('AVERAGE PER LOGGED DAY'),
            const SizedBox(height: 8),
            if (averages == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nothing logged in this period.',
                  key: const Key('summary-empty'),
                  style: TextStyle(color: secondary),
                ),
              )
            else
              for (final m in metrics)
                _AverageRow(
                  metric: m,
                  amount: m.amountIn(averages),
                  coverageHint: report.coverage[m] == null
                      ? null
                      : coverageText(m, report.coverage[m]!),
                ),
            if (averages != null && showMacroSplit(settings))
              if (macroSplit(averages) case final split?) ...[
                const SizedBox(height: 8),
                MacroSplitBar(split: split),
              ],
            const SizedBox(height: 8),
            Text(
              'Days logged: ${report.daysLogged} of ${report.totalDays}',
              key: const Key('days-logged'),
              style: TextStyle(fontSize: 13, color: secondary),
            ),
            if (goal != null && goal > 0 && report.daysLogged > 0)
              Text(
                'On target (within ${(goalTolerance * 100).round()}% of the '
                'goal): ${daysOnTarget(report.dailyTotals.values, primary, goal)} '
                'of ${report.daysLogged} logged days',
                key: const Key('days-on-target'),
                style: TextStyle(fontSize: 13, color: secondary),
              ),
          ],
        ),
        if (report.range != SummaryRange.day) ...[
          const SizedBox(height: 16),
          _WeightCard(
            range: report.range,
            startKey: report.startKey,
            endKey: report.endKey,
            unit: settings.bodyWeightUnit,
          ),
        ],
        if (report.buckets.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Card(
            children: [
              _SectionLabel(_chartHeading(report.range, primary)),
              const SizedBox(height: 12),
              SummaryChart(
                buckets: report.buckets,
                metric: primary,
                goal: goal,
                bucketSize: report.range.bucketSize,
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _chartHeading(SummaryRange range, Metric metric) {
    final per = switch (range.bucketSize) {
      BucketSize.day => 'per day',
      BucketSize.week => 'weekly averages',
      BucketSize.month => 'monthly averages',
    };
    return '${metric.label.toUpperCase()} $per';
  }
}

/// Body weight over the range with its moving average. Shows a short note
/// instead of a chart when nothing was weighed in the range.
class _WeightCard extends ConsumerWidget {
  const _WeightCard({
    required this.range,
    required this.startKey,
    required this.endKey,
    required this.unit,
  });

  final SummaryRange range;
  final String startKey;
  final String endKey;
  final BodyWeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = ref
        .watch(bodyWeightRangeProvider((endDate: endKey, range: range)))
        .value;
    final inRange = [
      for (final r in readings ?? const <WeightReading>[])
        if (r.date.compareTo(startKey) >= 0) r,
    ];
    return _Card(
      children: [
        _SectionLabel(
          'BODY WEIGHT (${unit.name}) AND $movingAverageDays-DAY AVERAGE',
        ),
        const SizedBox(height: 12),
        if (inRange.isEmpty)
          Text(
            readings == null
                ? ''
                : 'No weigh-ins in this period. Add one from the Today screen.',
            key: const Key('weight-empty'),
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          )
        else
          WeightChart(
            key: const Key('weight-chart'),
            readings: readings!,
            startKey: startKey,
            endKey: endKey,
            unit: unit,
          ),
      ],
    );
  }
}

/// Shares the range shown as a PDF report (Pro). Disabled while the range
/// is loading or has nothing logged.
class _ShareReportButton extends ConsumerStatefulWidget {
  const _ShareReportButton({required this.endDate, required this.range});

  final String endDate;
  final SummaryRange range;

  @override
  ConsumerState<_ShareReportButton> createState() => _ShareReportButtonState();
}

class _ShareReportButtonState extends ConsumerState<_ShareReportButton> {
  bool _busy = false;

  SummaryQuery get _query => (endDate: widget.endDate, range: widget.range);

  Future<void> _share() async {
    setState(() => _busy = true);
    // Where the iPad share popover points.
    final box = context.findRenderObject();
    final origin = box is RenderBox
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      final summary = await ref.read(summaryReportProvider(_query).future);
      final weights = await ref.read(bodyWeightRangeProvider(_query).future);
      final settings = ref.read(preferencesProvider);
      final report = buildReport(
        startKey: summary.startKey,
        endKey: summary.endKey,
        days: summary.dailyTotals,
        metrics: [settings.primaryMetric, ...settings.secondaryMetrics],
        goals: settings.goals,
        weights: weights,
      );
      final bytes = await renderReportPdf(
        report,
        unit: settings.bodyWeightUnit,
        generatedOn: ref.read(clockProvider)(),
      );
      await ref
          .read(reportSharerProvider)
          .share(
            fileName: reportFileName(report.startKey, report.endKey),
            bytes: bytes,
            origin: origin,
          );
    } on Exception catch (error, stack) {
      if (mounted) {
        await showErrorDialog(
          context,
          reportError(ref, error, stack, 'Could not make the report'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(summaryReportProvider(_query)).value;
    final ready = !_busy && summary != null && summary.daysLogged > 0;
    return CupertinoButton(
      key: const Key('share-report'),
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(44),
      onPressed: ready ? _share : null,
      child: _busy
          ? const CupertinoActivityIndicator()
          : const Icon(CupertinoIcons.share, semanticLabel: 'Share report'),
    );
  }
}

/// ‹ and › step the Summary back or forward by one range; the label names
/// the days shown, and "Today" returns to the current range.
class _PeriodRow extends ConsumerWidget {
  const _PeriodRow({required this.range, required this.endDate});

  final SummaryRange range;
  final String endDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final notifier = ref.read(summaryEndNotifierProvider.notifier);
    final atToday = endDate == today;
    return Row(
      children: [
        CupertinoButton(
          key: const Key('summary-previous'),
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(44),
          onPressed: () => notifier.step(range, -1),
          child: const Icon(
            CupertinoIcons.chevron_left,
            semanticLabel: 'Earlier',
          ),
        ),
        Expanded(
          child: Text(
            periodLabel(windowStart(endDate, range.days), endDate),
            key: const Key('summary-period'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (!atToday)
          CupertinoButton(
            key: const Key('summary-today'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size.square(44),
            onPressed: notifier.showToday,
            child: const Text('Today'),
          ),
        CupertinoButton(
          key: const Key('summary-next'),
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(44),
          onPressed: atToday ? null : () => notifier.step(range, 1),
          child: const Icon(
            CupertinoIcons.chevron_right,
            semanticLabel: 'Later',
          ),
        ),
      ],
    );
  }
}

/// "Oct 28 – Nov 3, 2026" for a span, or "Nov 3, 2026" for one day.
String periodLabel(String startKey, String endKey) {
  final start = dateFromKey(startKey);
  final end = dateFromKey(endKey);
  final full = DateFormat.yMMMd();
  if (startKey == endKey) return full.format(end);
  final first = start.year == end.year
      ? DateFormat.MMMd().format(start)
      : full.format(start);
  return '$first – ${full.format(end)}';
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({
    required this.metric,
    required this.amount,
    this.coverageHint,
  });

  final Metric metric;
  final double amount;
  final String? coverageHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(metric.label, style: const TextStyle(fontSize: 15)),
              ),
              Flexible(
                child: Text(
                  '${metric.format(amount)} ${metric.unit}',
                  key: Key('average-${metric.name}'),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (coverageHint != null)
            Text(
              coverageHint!,
              key: Key('coverage-${metric.name}'),
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

/// A rounded panel, matching the Home summary card.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
