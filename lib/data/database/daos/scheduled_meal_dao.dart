import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/meals.dart';
import '../tables/scheduled_meals.dart';

part 'scheduled_meal_dao.g.dart';

/// A scheduled meal that is still waiting for the user on one day.
class PendingScheduledMeal {
  const PendingScheduledMeal({required this.schedule, required this.meal});

  final ScheduledMeal schedule;
  final Meal meal;
}

@DriftAccessor(tables: [ScheduledMeals, ScheduledMealOutcomes, Meals])
class ScheduledMealDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledMealDaoMixin {
  ScheduledMealDao(super.attachedDatabase);

  Future<void> insertSchedule(ScheduledMealsCompanion schedule) =>
      into(scheduledMeals).insert(schedule);

  Future<ScheduledMeal?> findSchedule(String id) =>
      (select(scheduledMeals)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Deletes the plan; its outcomes cascade.
  Future<int> deleteSchedule(String id) =>
      (delete(scheduledMeals)..where((t) => t.id.equals(id))).go();

  Future<List<ScheduledMeal>> findSchedulesForMeal(String mealId) =>
      (select(scheduledMeals)..where((t) => t.mealId.equals(mealId))).get();

  Future<void> insertOutcome(ScheduledMealOutcomesCompanion outcome) =>
      into(scheduledMealOutcomes).insert(outcome);

  Future<List<ScheduledMealOutcome>> findOutcomes(String scheduledMealId) =>
      (select(
        scheduledMealOutcomes,
      )..where((t) => t.scheduledMealId.equals(scheduledMealId))).get();

  /// Outcomes whose provenance link points at the log entry [entryId].
  Future<List<ScheduledMealOutcome>> findOutcomesForEntry(String entryId) =>
      (select(
        scheduledMealOutcomes,
      )..where((t) => t.entryId.equals(entryId))).get();

  Future<int> setOutcomeEntry(String outcomeId, String? entryId) =>
      (update(scheduledMealOutcomes)..where((t) => t.id.equals(outcomeId)))
          .write(ScheduledMealOutcomesCompanion(entryId: Value(entryId)));

  /// Plans due on [date] ('yyyy-MM-dd') that have no outcome for that day yet,
  /// oldest plan first. [weekdayBit] is the bit of [date]'s weekday (see
  /// `weekdayBit`). A one-off is due on its start date; a repeating plan on
  /// matching weekdays from its start date on.
  Stream<List<PendingScheduledMeal>> watchPendingForDate(
    String date,
    int weekdayBit,
  ) {
    final query =
        select(scheduledMeals).join([
            innerJoin(meals, meals.id.equalsExp(scheduledMeals.mealId)),
            leftOuterJoin(
              scheduledMealOutcomes,
              scheduledMealOutcomes.scheduledMealId.equalsExp(
                    scheduledMeals.id,
                  ) &
                  scheduledMealOutcomes.date.equals(date),
            ),
          ])
          ..where(
            scheduledMealOutcomes.id.isNull() &
                ((scheduledMeals.weekdays.isNull() &
                        scheduledMeals.startDate.equals(date)) |
                    (scheduledMeals.weekdays.isNotNull() &
                        scheduledMeals.startDate.isSmallerOrEqualValue(date) &
                        scheduledMeals.weekdays
                            .bitwiseAnd(Constant(weekdayBit))
                            .isBiggerThanValue(0))),
          )
          ..orderBy([
            OrderingTerm.asc(scheduledMeals.createdAt),
            OrderingTerm.asc(scheduledMeals.rowId),
          ]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          PendingScheduledMeal(
            schedule: r.readTable(scheduledMeals),
            meal: r.readTable(meals),
          ),
      ],
    );
  }
}
