// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'food_items.dart';
import 'food_log_entries.dart';
import 'meals.dart';

/// A planned meal or catalog food (exactly one of [mealId] and [foodItemId]).
/// With [weekdays] null it is a one-off on [startDate]; with a weekday mask it
/// repeats on those weekdays from [startDate] on. Plans are suggestions only:
/// nothing is logged until the user confirms. A plan ends when it is deleted
/// ("Stop repeating"), so there is no separate active flag.
@TableIndex(name: 'scheduled_meals_start_date', columns: {#startDate})
class ScheduledMeals extends Table {
  TextColumn get id => text()();
  TextColumn get mealId =>
      text().nullable().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get foodItemId => text().nullable().references(
    FoodItems,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// 'yyyy-MM-dd'. The day of a one-off, or the first day of a repeating plan.
  TextColumn get startDate => text()();

  /// Bitmask of weekdays, bit 0 = Monday ... bit 6 = Sunday (1..127), or null
  /// for a one-off.
  IntColumn get weekdays => integer().nullable().check(
    weekdays.isNull() | weekdays.isBetweenValues(1, 127),
  )();

  /// 'breakfast' | 'lunch' | 'dinner' | 'snack'. Null means the slot is picked
  /// from the time of day when the suggestion is shown or confirmed.
  TextColumn get mealSlot => text().nullable().check(
    mealSlot.isIn(['breakfast', 'lunch', 'dinner', 'snack']),
  )();

  /// Servings of the food, or the multiplier on the meal's item weights.
  RealColumn get servings => real()
      .withDefault(const Constant(1))
      .check(servings.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((meal_id IS NULL) <> (food_item_id IS NULL))',
  ];
}

/// What happened to a scheduled meal on one day: confirmed (logged) or
/// dismissed. A day with no row here is still a pending suggestion.
class ScheduledMealOutcomes extends Table {
  TextColumn get id => text()();
  TextColumn get scheduledMealId =>
      text().references(ScheduledMeals, #id, onDelete: KeyAction.cascade)();

  /// The day the suggestion was for, 'yyyy-MM-dd'.
  TextColumn get date => text()();

  /// 'logged' | 'dismissed'
  TextColumn get status => text().check(status.isIn(['logged', 'dismissed']))();

  /// The log entry created when confirmed (provenance only).
  TextColumn get entryId => text().nullable().references(
    FoodLogEntries,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {scheduledMealId, date},
  ];
}
