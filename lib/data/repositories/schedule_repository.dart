import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/date_key.dart';
import '../../core/meal_slot.dart';
import '../../core/weekdays.dart';
import '../database/app_database.dart';
import '../database/daos/scheduled_meal_dao.dart';
import 'catalog_repository.dart';
import 'log_repository.dart';

export '../database/daos/scheduled_meal_dao.dart' show PendingScheduledMeal;

const _uuid = Uuid();

/// Planned meals and foods. A plan is only a suggestion on Home: confirming it
/// logs the meal through [LogRepository.logMeal] (or the food through
/// [LogRepository.logFood]) so the entry is a normal snapshot; dismissing it
/// just hides it for that day.
///
/// A plan names exactly one of `mealId` and `foodItemId`, an optional
/// [MealSlot] (null: picked from the time of day, see [slotOf]) and servings
/// (a food's servings, or the multiplier on a meal's item weights).
class ScheduleRepository {
  ScheduleRepository(this._db);

  final AppDatabase _db;

  /// The section a plan belongs in at [now]: its own slot, or the one for the
  /// time of day. Used both to place the suggestion and to log it.
  static MealSlot slotOf(ScheduledMeal plan, DateTime now) =>
      MealSlot.fromName(plan.mealSlot) ?? MealSlot.forTime(now);

  /// Plans a meal or food (give exactly one of [mealId] and [foodItemId]) once,
  /// on [date] ('yyyy-MM-dd').
  Future<String> scheduleOnce({
    String? mealId,
    String? foodItemId,
    required String date,
    MealSlot? mealSlot,
    double servings = 1,
  }) => _create(
    mealId: mealId,
    foodItemId: foodItemId,
    startDate: date,
    weekdays: null,
    mealSlot: mealSlot,
    servings: servings,
  );

  /// Plans a meal or food on every weekday in [weekdays] ([DateTime.weekday]
  /// values, 1 = Monday), starting on [startDate].
  Future<String> scheduleWeekdays({
    String? mealId,
    String? foodItemId,
    required String startDate,
    required Set<int> weekdays,
    MealSlot? mealSlot,
    double servings = 1,
  }) async {
    if (weekdays.isEmpty) {
      throw ArgumentError.value(weekdays, 'weekdays', 'pick at least one day');
    }
    return _create(
      mealId: mealId,
      foodItemId: foodItemId,
      startDate: startDate,
      weekdays: weekdayMask(weekdays),
      mealSlot: mealSlot,
      servings: servings,
    );
  }

  Future<String> _create({
    required String? mealId,
    required String? foodItemId,
    required String startDate,
    required int? weekdays,
    required MealSlot? mealSlot,
    required double servings,
  }) async {
    if ((mealId == null) == (foodItemId == null)) {
      throw ArgumentError('give exactly one of mealId and foodItemId');
    }
    if (!servings.isFinite || servings <= 0) {
      throw ArgumentError.value(servings, 'servings', 'must be > 0');
    }
    dateFromKey(startDate); // throws FormatException when malformed
    if (mealId != null && await _db.mealDao.findById(mealId) == null) {
      throw StateError('Unknown meal $mealId');
    }
    if (foodItemId != null && await _db.foodDao.findById(foodItemId) == null) {
      throw StateError('Unknown food item $foodItemId');
    }
    final id = _uuid.v4();
    await _db.scheduledMealDao.insertSchedule(
      ScheduledMealsCompanion.insert(
        id: id,
        mealId: Value(mealId),
        foodItemId: Value(foodItemId),
        startDate: startDate,
        weekdays: Value(weekdays),
        mealSlot: Value(mealSlot?.name),
        servings: Value(servings),
        createdAt: DateTime.now(),
      ),
    );
    return id;
  }

  /// Scheduled meals still waiting for the user on [date], oldest plan first.
  /// Re-emits when plans, outcomes or the log change.
  Stream<List<PendingScheduledMeal>> watchPendingForDate(String date) => _db
      .scheduledMealDao
      .watchPendingForDate(date, weekdayBit(dateFromKey(date).weekday));

  /// Logs the plan's meal (from its current template, item weights times the
  /// plan's servings) or food on [date], into the plan's slot, and marks the
  /// plan done for that day. One transaction. Returns the new entry id.
  Future<String> confirm(String scheduledMealId, {required String date}) async {
    dateFromKey(date);
    return _db.transaction(() async {
      final schedule = await _requireSchedule(scheduledMealId);
      await _requirePending(schedule, date);
      final slot = slotOf(schedule, DateTime.now());
      final log = LogRepository(_db);
      final String entryId;
      final mealId = schedule.mealId;
      if (mealId != null) {
        final meal = await _db.mealDao.findById(mealId);
        if (meal == null) throw StateError('Unknown meal $mealId');
        final rows = await _db.mealDao.findItems(meal.id);
        entryId = await log.logMeal(
          logDate: date,
          meal: meal,
          mealSlot: slot,
          items: [
            for (final r in rows)
              MealItemInput(
                foodItemId: r.food.id,
                weightG: r.link.weightG * schedule.servings,
              ),
          ],
        );
      } else {
        final foodId = schedule.foodItemId!;
        final food = await _db.foodDao.findById(foodId);
        if (food == null) throw StateError('Unknown food item $foodId');
        entryId = await log.logFood(
          logDate: date,
          food: food,
          servings: schedule.servings,
          mealSlot: slot,
        );
      }
      await _db.scheduledMealDao.insertOutcome(
        ScheduledMealOutcomesCompanion.insert(
          id: _uuid.v4(),
          scheduledMealId: scheduledMealId,
          date: date,
          status: 'logged',
          entryId: Value(entryId),
        ),
      );
      return entryId;
    });
  }

  /// Hides the plan for [date] only; a repeating plan comes back next time.
  Future<void> dismiss(String scheduledMealId, {required String date}) async {
    dateFromKey(date);
    return _db.transaction(() async {
      final schedule = await _requireSchedule(scheduledMealId);
      await _requirePending(schedule, date);
      await _db.scheduledMealDao.insertOutcome(
        ScheduledMealOutcomesCompanion.insert(
          id: _uuid.v4(),
          scheduledMealId: scheduledMealId,
          date: date,
          status: 'dismissed',
        ),
      );
    });
  }

  /// Removes the plan and its history of outcomes.
  Future<void> removeSchedule(String scheduledMealId) =>
      _db.scheduledMealDao.deleteSchedule(scheduledMealId);

  Future<ScheduledMeal> _requireSchedule(String id) async {
    final schedule = await _db.scheduledMealDao.findSchedule(id);
    if (schedule == null) throw StateError('No scheduled meal $id');
    return schedule;
  }

  /// Throws unless [schedule] is due on [date] and not yet confirmed/dismissed.
  Future<void> _requirePending(ScheduledMeal schedule, String date) async {
    final mask = schedule.weekdays;
    final due = mask == null
        ? schedule.startDate == date
        : schedule.startDate.compareTo(date) <= 0 &&
              maskHasWeekday(mask, dateFromKey(date).weekday);
    if (!due) {
      throw StateError('Scheduled meal ${schedule.id} is not due on $date');
    }
    final outcomes = await _db.scheduledMealDao.findOutcomes(schedule.id);
    if (outcomes.any((o) => o.date == date)) {
      throw StateError(
        'Scheduled meal ${schedule.id} is already done on $date',
      );
    }
  }
}
