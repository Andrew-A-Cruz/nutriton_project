import 'package:flutter/cupertino.dart';
// For the walking figure, which Cupertino icons lack.
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/health.dart';
import '../../providers/health_providers.dart';

/// The day's steps from Apple Health, under the water row: the total, against
/// the goal when there is one. Shown only while "Show Steps" is on, with Pro.
///
/// With no steps for the day it says how to allow access instead of showing
/// 0: HealthKit does not say whether reading was refused, so "no steps" and
/// "no access" look the same.
class StepsRow extends ConsumerWidget {
  const StepsRow({super.key, required this.date});

  /// 'yyyy-MM-dd'
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(stepsEnabledProvider)) return const SizedBox.shrink();
    final read = ref.watch(dailyStepsProvider((start: date, end: date)));
    final goal = ref.watch(stepsGoalProvider);
    final steps = read.value?[date] ?? 0;
    final loading = read.isLoading && !read.hasValue;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final reached = goal != null && steps >= goal;
    final format = NumberFormat.decimalPattern();
    final text = loading
        ? '…'
        : steps > 0
        ? stepsProgressText(steps, goal, format: format.format)
        : 'None';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        key: const Key('steps-row'),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
            context,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_walk, size: 20, color: secondary),
                  const SizedBox(width: 8),
                  const Text('Steps', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      label: 'Steps: $text',
                      excludeSemantics: true,
                      child: Text(
                        text,
                        key: const Key('steps-value'),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: reached
                              ? CupertinoColors.systemGreen.resolveFrom(context)
                              : steps > 0
                              ? CupertinoColors.label.resolveFrom(context)
                              : secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!loading && steps == 0) ...[
                const SizedBox(height: 4),
                Text(
                  read.hasError
                      ? 'Could not read steps from Apple Health.'
                      : 'Apple Health has no steps for this day. If it '
                            'should, allow Logbite to read Steps in the '
                            'Health app, under Sharing > Apps.',
                  key: const Key('steps-hint'),
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
