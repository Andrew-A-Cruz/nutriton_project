import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/weekdays.dart';
import 'package:nutriton_project/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.mealDao.insertMeal(MealsCompanion.insert(id: 'm1', name: 'Lunch'));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> plan(String id, String start, int? mask) =>
      db.scheduledMealDao.insertSchedule(
        ScheduledMealsCompanion.insert(
          id: id,
          mealId: Value('m1'),
          startDate: start,
          weekdays: Value(mask),
          createdAt: DateTime(2026, 10, 1),
        ),
      );

  Future<List<String>> pending(String date, int weekday) async {
    final rows = await db.scheduledMealDao
        .watchPendingForDate(date, weekdayBit(weekday))
        .first;
    return [for (final r in rows) r.schedule.id];
  }

  // 2026-10-21 is a Wednesday.
  test('a one-off is pending only on its date', () async {
    await plan('once', '2026-10-21', null);
    expect(await pending('2026-10-21', DateTime.wednesday), ['once']);
    expect(await pending('2026-10-22', DateTime.thursday), isEmpty);
    expect(await pending('2026-10-20', DateTime.tuesday), isEmpty);
  });

  test(
    'a repeating plan matches its weekdays from the start date on',
    () async {
      await plan('mf', '2026-10-21', workweekMask);
      expect(await pending('2026-10-21', DateTime.wednesday), ['mf']);
      expect(await pending('2026-10-23', DateTime.friday), ['mf']);
      expect(await pending('2026-10-24', DateTime.saturday), isEmpty);
      expect(await pending('2026-10-26', DateTime.monday), ['mf']);
      // Before the start date.
      expect(await pending('2026-10-19', DateTime.monday), isEmpty);
    },
  );

  test('an outcome hides the plan for that day only', () async {
    await plan('mf', '2026-10-19', workweekMask);
    await db.scheduledMealDao.insertOutcome(
      ScheduledMealOutcomesCompanion.insert(
        id: 'o1',
        scheduledMealId: 'mf',
        date: '2026-10-21',
        status: 'dismissed',
      ),
    );
    expect(await pending('2026-10-21', DateTime.wednesday), isEmpty);
    expect(await pending('2026-10-22', DateTime.thursday), ['mf']);
  });

  test('deleting a plan cascades to outcomes, a meal to its plans', () async {
    await plan('a', '2026-10-21', null);
    await db.scheduledMealDao.insertOutcome(
      ScheduledMealOutcomesCompanion.insert(
        id: 'o1',
        scheduledMealId: 'a',
        date: '2026-10-21',
        status: 'logged',
      ),
    );
    await db.scheduledMealDao.deleteSchedule('a');
    expect(await db.scheduledMealDao.findOutcomes('a'), isEmpty);

    await plan('b', '2026-10-21', null);
    await db.mealDao.deleteMeal('m1');
    expect(await db.scheduledMealDao.findSchedule('b'), isNull);
  });

  test('rejects an out-of-range weekday mask', () async {
    await expectLater(plan('bad', '2026-10-21', 0), throwsA(isA<Object>()));
    await expectLater(plan('bad', '2026-10-21', 128), throwsA(isA<Object>()));
  });
}
