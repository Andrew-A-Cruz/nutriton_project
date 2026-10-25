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

/// Planned meals. A plan is only a suggestion on Home: confirming it logs the
/// meal through [LogRepository.logMeal] (so the entry is a normal snapshot),
/// dismissing it just hides it for that day.
class ScheduleRepository {
  ScheduleRepository(this._db);

  final AppDatabase _db;

  /// Plans [mealId] once, on [date] ('yyyy-MM-dd').
  Future<String> scheduleOnce({required String mealId, required String date}) =>
      _create(mealId: mealId, startDate: date, weekdays: null);

  /// Plans [mealId] on every weekday in [weekdays] ([DateTime.weekday] values,
  /// 1 = Monday), starting on [startDate].
  Future<String> scheduleWeekdays({
    required String mealId,
    required String startDate,
    required Set<int> weekdays,
  }) async {
    if (weekdays.isEmpty) {
      throw ArgumentError.value(weekdays, 'weekdays', 'pick at least one day');
    }
    return _create(
      mealId: mealId,
      startDate: startDate,
      weekdays: weekdayMask(weekdays),
    );
  }

  Future<String> _create({
    required String mealId,
    required String startDate,
    required int? weekdays,
  }) async {
    dateFromKey(startDate); // throws FormatException when malformed
    if (await _db.mealDao.findById(mealId) == null) {
      throw StateError('Unknown meal $mealId');
    }
    final id = _uuid.v4();
    await _db.scheduledMealDao.insertSchedule(
      ScheduledMealsCompanion.insert(
        id: id,
        mealId: mealId,
        startDate: startDate,
        weekdays: Value(weekdays),
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

  /// Logs the plan's meal on [date] from the meal's current template, and marks
  /// the plan done for that day. One transaction. Returns the new entry id.
  Future<String> confirm(String scheduledMealId, {required String date}) async {
    dateFromKey(date);
    return _db.transaction(() async {
      final schedule = await _requireSchedule(scheduledMealId);
      await _requirePending(schedule, date);
      final meal = await _db.mealDao.findById(schedule.mealId);
      if (meal == null) throw StateError('Unknown meal ${schedule.mealId}');
      final rows = await _db.mealDao.findItems(meal.id);
      final entryId = await LogRepository(_db).logMeal(
        logDate: date,
        meal: meal,
        mealSlot: MealSlot.forTime(DateTime.now()),
        items: [
          for (final r in rows)
            MealItemInput(foodItemId: r.food.id, weightG: r.link.weightG),
        ],
      );
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
