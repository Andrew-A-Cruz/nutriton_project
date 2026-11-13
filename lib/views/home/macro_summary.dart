import 'package:flutter/cupertino.dart';

import '../../core/macro_split.dart';
import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../data/database/app_database.dart';
import '../../data/preferences/user_preferences.dart';
import '../common/macro_split_bar.dart';

/// The macros stored on a log entry.
Macros macrosOfEntry(FoodLogEntry e) => Macros(
  calories: e.calories,
  protein: e.protein,
  carbs: e.carbs,
  fat: e.fat,
  fiber: e.fiber,
  sugar: e.sugar,
  sodium: e.sodium,
);

/// Sum of the macros of [entries].
Macros totalsOf(Iterable<FoodLogEntry> entries) =>
    sumMacros(entries.map(macrosOfEntry));

/// Whether to show the macro split: only to people who track at least one
/// of protein, carbs and fat.
bool showMacroSplit(UserSettings settings) => const [
  Metric.protein,
  Metric.carbs,
  Metric.fat,
].any(settings.trackedMetrics.contains);

/// Day totals: the primary metric large with progress toward its goal, and
/// each secondary metric below.
class MacroSummary extends StatelessWidget {
  const MacroSummary({
    super.key,
    required this.entries,
    required this.settings,
    this.mindful = false,
    this.date,
  });

  final List<FoodLogEntry> entries;
  final UserSettings settings;

  /// Mindful mode: goal progress as bars only, no numbers.
  final bool mindful;

  /// The day shown ('yyyy-MM-dd'), so its weekday goals apply.
  final String? date;

  @override
  Widget build(BuildContext context) {
    final totals = totalsOf(entries);
    if (mindful) {
      return _MindfulTotals(totals: totals, settings: settings, date: date);
    }
    final primary = settings.primaryMetric;
    final macros = entries.map(macrosOfEntry).toList();
    // Only the optional nutrients can be missing from an entry.
    String? hintFor(Metric m) =>
        coverageText(m, coverageOf(macros, m.recordedAmountIn));

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
                goal: settings.goalFor(primary, date: date),
                coverageHint: hintFor(primary),
              ),
              for (final m in settings.secondaryMetrics) ...[
                const SizedBox(height: 14),
                _SecondaryTotal(
                  metric: m,
                  amount: m.amountIn(totals),
                  goal: settings.goalFor(m, date: date),
                  coverageHint: hintFor(m),
                ),
              ],
              if (showMacroSplit(settings) ? macroSplit(totals) : null
                  case final split?) ...[
                const SizedBox(height: 14),
                MacroSplitBar(split: split),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mindful mode's card: each tracked metric with a goal as a label and a
/// bar, in one calm color that does not change when over. Nothing when no
/// metric has a goal.
class _MindfulTotals extends StatelessWidget {
  const _MindfulTotals({
    required this.totals,
    required this.settings,
    this.date,
  });

  final Macros totals;
  final UserSettings settings;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final withGoals = [
      for (final m in [settings.primaryMetric, ...settings.secondaryMetrics])
        if (settings.goalFor(m, date: date) case final goal? when goal > 0)
          (m, goal),
    ];
    if (withGoals.isEmpty) return const SizedBox.shrink();
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      key: const Key('mindful-totals'),
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
              for (final (i, (m, goal)) in withGoals.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Semantics(
                  label:
                      '${m.label}: ${(m.amountIn(totals) / goal * 100).clamp(0, 999).round()}% of goal',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          m.label,
                          style: TextStyle(fontSize: 13, color: secondary),
                        ),
                        const SizedBox(height: 4),
                        _ProgressBar(
                          fraction: m.amountIn(totals) / goal,
                          over: false,
                          neutral: true,
                        ),
                      ],
                    ),
                  ),
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
    this.coverageHint,
  });

  final Metric metric;
  final double amount;
  final double? goal;
  final String? coverageHint;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal != null && goal! > 0;
    final remaining = hasGoal ? goal! - amount : 0.0;
    // Dynamic colors must be resolved, or dark mode gets the light variant.
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final column = Column(
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
        if (coverageHint != null) ...[
          const SizedBox(height: 4),
          Text(
            coverageHint!,
            key: Key('coverage-${metric.name}'),
            style: TextStyle(fontSize: 13, color: secondary),
          ),
        ],
      ],
    );
    return _TotalSemantics(
      metric: metric,
      amount: amount,
      goal: goal,
      coverageHint: coverageHint,
      child: column,
    );
  }
}

class _SecondaryTotal extends StatelessWidget {
  const _SecondaryTotal({
    required this.metric,
    required this.amount,
    required this.goal,
    this.coverageHint,
  });

  final Metric metric;
  final double amount;
  final double? goal;
  final String? coverageHint;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal != null && goal! > 0;
    final column = Column(
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
        if (coverageHint != null) ...[
          const SizedBox(height: 4),
          Text(
            coverageHint!,
            key: Key('coverage-${metric.name}'),
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ],
    );
    return _TotalSemantics(
      metric: metric,
      amount: amount,
      goal: goal,
      coverageHint: coverageHint,
      child: column,
    );
  }
}

/// Reads a total as one sentence ([totalSemanticsLabel], plus any coverage
/// hint) instead of its separate number, goal and bar.
class _TotalSemantics extends StatelessWidget {
  const _TotalSemantics({
    required this.metric,
    required this.amount,
    required this.goal,
    required this.coverageHint,
    required this.child,
  });

  final Metric metric;
  final double amount;
  final double? goal;
  final String? coverageHint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('total-semantics-${metric.name}'),
      container: true,
      label: [
        totalSemanticsLabel(metric, amount, goal),
        ?coverageHint,
      ].join('. '),
      child: ExcludeSemantics(child: child),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.fraction,
    required this.over,
    this.neutral = false,
  });

  final double fraction;
  final bool over;

  /// One calm color whatever the progress (mindful mode).
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final fill =
        (neutral
                ? CupertinoColors.systemTeal
                : over
                ? CupertinoColors.systemOrange
                : CupertinoColors.activeGreen)
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
