import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_items.dart';
import '../tables/meals.dart';
import '../tables/scheduled_meals.dart';

part 'scheduled_meal_dao.g.dart';

/// A scheduled meal or food that is still waiting for the user on one day.
/// Exactly one of [meal] and [food] is set.
class PendingScheduledMeal {
  const PendingScheduledMeal({required this.schedule, this.meal, this.food})
    : assert((meal == null) != (food == null));

  final ScheduledMeal schedule;
  final Meal? meal;
  final FoodItem? food;

  /// The planned meal's or food's name.
  String get name => (meal?.name ?? food?.name)!;
}

@DriftAccessor(
  tables: [ScheduledMeals, ScheduledMealOutcomes, Meals, FoodItems],
)
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

  Future<List<ScheduledMeal>> findSchedulesForFood(String foodItemId) =>
      (select(
        scheduledMeals,
      )..where((t) => t.foodItemId.equals(foodItemId))).get();

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
  /// oldest plan first; plans whose meal or food is archived are left out. [weekdayBit] is the bit of [date]'s weekday (see
  /// `weekdayBit`). A one-off is due on its start date; a repeating plan on
  /// matching weekdays from its start date on.
  Stream<List<PendingScheduledMeal>> watchPendingForDate(
    String date,
    int weekdayBit,
  ) {
    final query =
        select(scheduledMeals).join([
            leftOuterJoin(meals, meals.id.equalsExp(scheduledMeals.mealId)),
            leftOuterJoin(
              foodItems,
              foodItems.id.equalsExp(scheduledMeals.foodItemId),
            ),
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
                ((meals.id.isNotNull() & meals.archived.equals(false)) |
                    (foodItems.id.isNotNull() &
                        foodItems.archived.equals(false))) &
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
            meal: r.readTableOrNull(meals),
            food: r.readTableOrNull(foodItems),
          ),
      ],
    );
  }
}
