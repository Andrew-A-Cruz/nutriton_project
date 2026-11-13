import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/meal_slot.dart';
import '../../core/metrics.dart';
import '../../core/weekdays.dart';
import '../../providers/schedule_providers.dart';
import '../../providers/today_providers.dart';
import '../common/error_feedback.dart';
import '../home/date_header.dart';
import '../meals/schedule_meal_view.dart';

/// Settings row that opens [PlannedMealsView].
class PlannedMealsSection extends ConsumerWidget {
  const PlannedMealsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(allPlansProvider).value?.length;
    return CupertinoFormSection.insetGrouped(
      header: const Text('PLANNED MEALS'),
      children: [
        CupertinoListTile(
          key: const Key('planned-meals'),
          title: const Text('Planned Meals'),
          additionalInfo: count == null ? null : Text('$count'),
          trailing: const CupertinoListTileChevron(),
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(builder: (_) => const PlannedMealsView()),
          ),
        ),
      ],
    );
  }
}

/// One line about a plan: its days, end and section, e.g.
/// 'Mon-Fri · until Fri, Dec 4 · Lunch · 1.5 servings'.
String describePlan(PendingScheduledMeal plan, {required String today}) {
  final s = plan.schedule;
  final parts = <String>[
    if (s.weekdays case final mask?) ...[
      describeWeekdays(mask),
      if (s.startDate.compareTo(today) > 0)
        'from ${dayLabel(s.startDate, today: today)}',
      if (s.endDate case final end?) 'until ${dayLabel(end, today: today)}',
    ] else
      dayLabel(s.startDate, today: today),
    MealSlot.fromName(s.mealSlot)?.label ?? 'By time of day',
    if (s.servings != 1) '${plainNumber(s.servings)} servings',
  ];
  return parts.join(' · ');
}

/// Every plan, to review, edit or remove: repeating plans, upcoming one-day
/// plans, and plans that have ended. Past one-day plans are left out.
class PlannedMealsView extends ConsumerWidget {
  const PlannedMealsView({super.key});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PendingScheduledMeal plan,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('Remove ${plan.name}?'),
        content: const Text(
          'It stops showing on Today. Anything already logged stays.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            key: const Key('plan-remove-confirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .removeSchedule(plan.schedule.id);
    } catch (e, stack) {
      if (context.mounted) {
        await showErrorDialog(
          context,
          reportError(ref, e, stack, 'Could not remove the plan'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final plans = ref.watch(allPlansProvider);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Planned Meals'),
      ),
      child: SafeArea(
        child: plans.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stack) => LoadErrorText(
            failed: 'Could not load the plans',
            error: error,
            stack: stack,
          ),
          data: (all) {
            bool ended(PendingScheduledMeal p) => switch (p.schedule) {
              final s when s.weekdays == null => false,
              final s => s.endDate != null && s.endDate!.compareTo(today) < 0,
            };
            final repeating = [
              for (final p in all)
                if (p.schedule.weekdays != null && !ended(p)) p,
            ];
            final once =
                [
                  for (final p in all)
                    if (p.schedule.weekdays == null &&
                        p.schedule.startDate.compareTo(today) >= 0)
                      p,
                ]..sort(
                  (a, b) =>
                      a.schedule.startDate.compareTo(b.schedule.startDate),
                );
            final past = [
              for (final p in all)
                if (ended(p)) p,
            ];
            if (repeating.isEmpty && once.isEmpty && past.isEmpty) {
              return Center(
                key: const Key('plans-empty'),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No planned meals. Plan a meal or food from the Catalog.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              );
            }
            Widget section(String header, List<PendingScheduledMeal> items) =>
                CupertinoFormSection.insetGrouped(
                  header: Text(header),
                  children: [
                    for (final p in items)
                      CupertinoListTile(
                        key: Key('plan-${p.schedule.id}'),
                        title: Text(p.name),
                        subtitle: Text(describePlan(p, today: today)),
                        trailing: CupertinoButton(
                          key: Key('plan-remove-${p.schedule.id}'),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(44),
                          onPressed: () => _remove(context, ref, p),
                          child: Icon(
                            CupertinoIcons.trash,
                            semanticLabel: 'Remove ${p.name}',
                            color: CupertinoColors.systemRed.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => ScheduleMealView(
                              meal: p.meal,
                              food: p.food,
                              initialDate: p.schedule.startDate,
                              existing: p.schedule,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
            return ListView(
              children: [
                if (repeating.isNotEmpty) section('REPEATING', repeating),
                if (once.isNotEmpty) section('ONE DAY', once),
                if (past.isNotEmpty) section('ENDED', past),
              ],
            );
          },
        ),
      ),
    );
  }
}
