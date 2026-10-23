import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../core/summary_math.dart';
import '../../data/preferences/user_preferences.dart';
import '../../providers/preferences_providers.dart';
import '../../providers/summary_providers.dart';
import '../../providers/today_providers.dart';
import 'summary_chart.dart';

/// The Summary tab: a range picker, averages per logged day for each tracked
/// metric, and a bar chart of the primary metric.
class SummaryView extends ConsumerWidget {
  const SummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(summaryRangeProvider);
    final settings = ref.watch(preferencesProvider);
    final reportAsync = ref.watch(
      summaryReportProvider((endDate: ref.watch(todayProvider), range: range)),
    );

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Summary')),
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
            const SizedBox(height: 16),
            reportAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CupertinoActivityIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(child: Text('Could not load: $error')),
              ),
              data: (report) => _ReportBody(report: report, settings: settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.settings});

  final SummaryReport report;
  final UserSettings settings;

  @override
  Widget build(BuildContext context) {
    final primary = settings.primaryMetric;
    final metrics = [primary, ...settings.secondaryMetrics];
    final averages = report.averages;
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
                _AverageRow(metric: m, amount: m.amountIn(averages)),
            const SizedBox(height: 8),
            Text(
              'Days logged: ${report.daysLogged} of ${report.totalDays}',
              key: const Key('days-logged'),
              style: TextStyle(fontSize: 13, color: secondary),
            ),
          ],
        ),
        if (report.buckets.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Card(
            children: [
              _SectionLabel(_chartHeading(report.range, primary)),
              const SizedBox(height: 12),
              SummaryChart(
                buckets: report.buckets,
                metric: primary,
                goal: settings.goalFor(primary),
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

class _AverageRow extends StatelessWidget {
  const _AverageRow({required this.metric, required this.amount});

  final Metric metric;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(metric.label, style: const TextStyle(fontSize: 15)),
          ),
          Flexible(
            child: Text(
              '${metric.format(amount)} ${metric.unit}',
              key: Key('average-${metric.name}'),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
