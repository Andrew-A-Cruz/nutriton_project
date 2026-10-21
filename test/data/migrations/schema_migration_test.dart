import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('food_log_migration');
    file = File('${dir.path}/food_log.sqlite');
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  Future<int> userVersion(AppDatabase db) => db
      .customSelect('PRAGMA user_version')
      .map((r) => r.read<int>('user_version'))
      .getSingle();

  test('v1 database upgrades to v2 and keeps its data', () async {
    // Build a database, then turn it back into a v1 file: no scheduling
    // tables, user_version 1.
    var db = AppDatabase(NativeDatabase(file));
    await db.mealDao.insertMeal(MealsCompanion.insert(id: 'm1', name: 'Lunch'));
    await db.logDao.insertEntry(
      FoodLogEntriesCompanion.insert(
        id: 'e1',
        logDate: '2026-10-20',
        createdAt: DateTime(2026, 10, 20),
        entryType: 'adhoc',
        name: 'Snack',
        calories: 100,
        protein: 1,
        carbs: 2,
        fat: 3,
      ),
    );
    await db.customStatement('DROP TABLE scheduled_meal_outcomes');
    await db.customStatement('DROP TABLE scheduled_meals');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    // Reopening runs the migration.
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    expect(await userVersion(db), 2);

    // Old data survived.
    expect((await db.mealDao.findById('m1'))!.name, 'Lunch');
    expect(
      (await db.logDao.findEntriesForDate('2026-10-20')).single.name,
      'Snack',
    );

    // New tables work, including the index and the unique outcome key.
    await db.scheduledMealDao.insertSchedule(
      ScheduledMealsCompanion.insert(
        id: 's1',
        mealId: 'm1',
        startDate: '2026-10-21',
        createdAt: DateTime(2026, 10, 20),
      ),
    );
    await db.scheduledMealDao.insertOutcome(
      ScheduledMealOutcomesCompanion.insert(
        id: 'o1',
        scheduledMealId: 's1',
        date: '2026-10-21',
        status: 'dismissed',
      ),
    );
    await expectLater(
      db.scheduledMealDao.insertOutcome(
        ScheduledMealOutcomesCompanion.insert(
          id: 'o2',
          scheduledMealId: 's1',
          date: '2026-10-21',
          status: 'logged',
        ),
      ),
      throwsA(isA<Object>()),
    );
    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'scheduled_meals_start_date'",
        )
        .get();
    expect(indexes, hasLength(1));
  });

  test('a fresh database starts at v2', () async {
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.scheduledMealDao.findSchedulesForMeal('x'), isEmpty);
    expect(await userVersion(db), 2);
  });
}
