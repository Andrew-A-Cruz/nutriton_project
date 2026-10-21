import 'package:flutter/cupertino.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../data/database/app_database.dart';
import '../../data/preferences/user_preferences.dart';

/// Sum of the macros of [entries].
Macros totalsOf(Iterable<FoodLogEntry> entries) => sumMacros(
  entries.map(
    (e) => Macros(
      calories: e.calories,
      protein: e.protein,
      carbs: e.carbs,
      fat: e.fat,
    ),
  ),
);

/// Day totals: the primary metric large with progress toward its goal, and
/// each secondary metric below.
class MacroSummary extends StatelessWidget {
  const MacroSummary({
    super.key,
    required this.entries,
    required this.settings,
  });

  final List<FoodLogEntry> entries;
  final UserSettings settings;

  @override
  Widget build(BuildContext context) {
    final totals = totalsOf(entries);
    final primary = settings.primaryMetric;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DecoratedBox(
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
            children: [
              _PrimaryTotal(
                metric: primary,
                amount: primary.amountIn(totals),
                goal: settings.goalFor(primary),
              ),
              for (final m in settings.secondaryMetrics) ...[
                const SizedBox(height: 14),
                _SecondaryTotal(
                  metric: m,
                  amount: m.amountIn(totals),
                  goal: settings.goalFor(m),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryTotal extends StatelessWidget {
  const _PrimaryTotal({
    required this.metric,
    required this.amount,
    required this.goal,
  });

  final Metric metric;
  final double amount;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal != null && goal! > 0;
    final remaining = hasGoal ? goal! - amount : 0.0;
    // Dynamic colors must be resolved, or dark mode gets the light variant.
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label.toUpperCase(),
          style: TextStyle(fontSize: 12, color: secondary),
        ),
        const SizedBox(height: 2),
        // Wrap, not Row: at large text sizes the goal moves to a second line.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              metric.format(amount),
              key: const Key('primary-amount'),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Text(
                hasGoal
                    ? '/ ${metric.format(goal!)} ${metric.unit}'
                    : metric.unit,
                style: TextStyle(fontSize: 15, color: secondary),
              ),
            ),
          ],
        ),
        if (hasGoal) ...[
          const SizedBox(height: 8),
          _ProgressBar(fraction: amount / goal!, over: amount > goal!),
          const SizedBox(height: 4),
          Text(
            remaining >= 0
                ? '${metric.format(remaining)} ${metric.unit} left'
                : '${metric.format(-remaining)} ${metric.unit} over',
            key: const Key('primary-remaining'),
            style: TextStyle(fontSize: 13, color: secondary),
          ),
        ],
      ],
    );
  }
}

class _SecondaryTotal extends StatelessWidget {
  const _SecondaryTotal({
    required this.metric,
    required this.amount,
    required this.goal,
  });

  final Metric metric;
  final double amount;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal != null && goal! > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(metric.label, style: const TextStyle(fontSize: 15)),
            ),
            Flexible(
              child: Text(
                key: Key('secondary-amount-${metric.name}'),
                hasGoal
                    ? '${metric.format(amount)} / ${metric.format(goal!)} ${metric.unit}'
                    : '${metric.format(amount)} ${metric.unit}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        if (hasGoal) ...[
          const SizedBox(height: 6),
          _ProgressBar(fraction: amount / goal!, over: amount > goal!),
        ],
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.over});

  final double fraction;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final fill =
        (over ? CupertinoColors.systemOrange : CupertinoColors.activeGreen)
            .resolveFrom(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
                  child: ColoredBox(color: fill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
