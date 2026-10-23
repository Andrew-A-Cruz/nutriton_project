import 'dart:io';

import 'package:drift/drift.dart' show Migrator, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<int> userVersion(AppDatabase db) => db
      .customSelect('PRAGMA user_version')
      .map((r) => r.read<int>('user_version'))
      .getSingle();

  Future<bool> hasStartDateIndex(AppDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'scheduled_meals_start_date'",
        )
        .get();
    return rows.isNotEmpty;
  }

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            addTearDown(db.close);
            await verifier.migrateAndValidate(db, toVersion);
          });
        }
      });
    }
  });

  group('v1 to v2 keeps existing data', () {
    final createdAt = DateTime(2026, 10, 20, 9);
    // Drift stores DateTime columns as Unix seconds.
    final createdAtSeconds = createdAt.millisecondsSinceEpoch ~/ 1000;

    /// Writes one of every kind of row into a v1 database, with breakdowns.
    Future<void> seedV1(v1.DatabaseAtV1 old) async {
      await old
          .into(old.foodItems)
          .insert(
            v1.FoodItemsCompanion.insert(
              id: 'f1',
              name: 'Rice',
              calories: 130,
              protein: 3,
              carbs: 28,
              fat: 0.3,
              servingWeightG: 100,
            ),
          );
      await old
          .into(old.meals)
          .insert(v1.MealsCompanion.insert(id: 'm1', name: 'Lunch'));
      await old
          .into(old.mealFoodItems)
          .insert(
            v1.MealFoodItemsCompanion.insert(
              id: 'mfi1',
              mealId: 'm1',
              foodItemId: 'f1',
              weightG: 200,
            ),
          );
      // A food entry, an adhoc entry and two meal entries.
      await old
          .into(old.foodLogEntries)
          .insert(
            v1.FoodLogEntriesCompanion.insert(
              id: 'e1',
              logDate: '2026-10-20',
              createdAt: createdAtSeconds,
              entryType: 'food',
              name: 'Rice',
              calories: 195,
              protein: 4.5,
              carbs: 42,
              fat: 0.45,
              foodItemId: const Value('f1'),
              servings: const Value(1.5),
            ),
          );
      await old
          .into(old.foodLogEntries)
          .insert(
            v1.FoodLogEntriesCompanion.insert(
              id: 'e2',
              logDate: '2026-10-20',
              createdAt: createdAtSeconds,
              entryType: 'adhoc',
              name: 'Snack',
              calories: 90,
              protein: 1,
              carbs: 15,
              fat: 3,
            ),
          );
      await old
          .into(old.foodLogEntries)
          .insert(
            v1.FoodLogEntriesCompanion.insert(
              id: 'e3',
              logDate: '2026-10-20',
              createdAt: createdAtSeconds,
              entryType: 'meal',
              name: 'Lunch',
              calories: 195,
              protein: 4.5,
              carbs: 42,
              fat: 0.45,
              mealId: const Value('m1'),
            ),
          );
      await old
          .into(old.foodLogEntries)
          .insert(
            v1.FoodLogEntriesCompanion.insert(
              id: 'e4',
              logDate: '2026-10-21',
              createdAt: createdAtSeconds,
              entryType: 'meal',
              name: 'Lunch',
              calories: 260,
              protein: 6,
              carbs: 56,
              fat: 0.6,
              mealId: const Value('m1'),
            ),
          );
      // Breakdown of the 2026-10-20 meal as eaten.
      await old
          .into(old.foodLogEntryItems)
          .insert(
            v1.FoodLogEntryItemsCompanion.insert(
              id: 'i1',
              entryId: 'e3',
              name: 'Rice',
              weightG: 150,
              calories: 195,
              protein: 4.5,
              carbs: 42,
              fat: 0.45,
              foodItemId: const Value('f1'),
            ),
          );
    }

    /// Checks everything [seedV1] wrote, after the migration to v2.
    Future<void> expectV1DataSurvived(AppDatabase db) async {
      final foods = await db.select(db.foodItems).get();
      expect(foods, hasLength(1));
      expect(foods.single.name, 'Rice');
      expect(foods.single.calories, 130);
      expect(foods.single.servingWeightG, 100);

      final meals = await db.select(db.meals).get();
      expect(meals.map((m) => m.name), ['Lunch']);

      final mealItem = await db.select(db.mealFoodItems).getSingle();
      expect(mealItem.mealId, 'm1');
      expect(mealItem.foodItemId, 'f1');
      expect(mealItem.weightG, 200);
      expect(mealItem.sortOrder, 0);

      final entries = {
        for (final e in await db.select(db.foodLogEntries).get()) e.id: e,
      };
      expect(entries.keys, unorderedEquals(['e1', 'e2', 'e3', 'e4']));

      final food = entries['e1']!;
      expect(food.entryType, 'food');
      expect(food.logDate, '2026-10-20');
      expect(food.calories, 195);
      expect(food.servings, 1.5);
      expect(food.foodItemId, 'f1');
      expect(food.mealId, isNull);
      expect(food.createdAt, createdAt);

      final adhoc = entries['e2']!;
      expect(adhoc.entryType, 'adhoc');
      expect(adhoc.name, 'Snack');
      expect(adhoc.calories, 90);
      expect(adhoc.servings, isNull);
      expect(adhoc.foodItemId, isNull);

      final meal20 = entries['e3']!;
      expect(meal20.entryType, 'meal');
      expect(meal20.logDate, '2026-10-20');
      expect(meal20.calories, 195);
      expect(meal20.mealId, 'm1');

      final meal21 = entries['e4']!;
      expect(meal21.logDate, '2026-10-21');
      expect(meal21.calories, 260);
      expect(meal21.protein, 6);

      final breakdown = await db.select(db.foodLogEntryItems).getSingle();
      expect(breakdown.entryId, 'e3');
      expect(breakdown.name, 'Rice');
      expect(breakdown.weightG, 150);
      expect(breakdown.calories, 195);
      expect(breakdown.foodItemId, 'f1');
    }

    test('every row and value survives, and the schedule tables work', () async {
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      await seedV1(old);
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 2);

      await expectV1DataSurvived(db);
      expect(await userVersion(db), 2);

      // The scheduling tables are created empty, with their start-date index.
      expect(await db.select(db.scheduledMeals).get(), isEmpty);
      expect(await db.select(db.scheduledMealOutcomes).get(), isEmpty);
      expect(await hasStartDateIndex(db), isTrue);

      // And usable: a repeating plan with a confirmed outcome.
      await db.scheduledMealDao.insertSchedule(
        ScheduledMealsCompanion.insert(
          id: 's1',
          mealId: 'm1',
          startDate: '2026-10-19',
          weekdays: const Value(5),
          createdAt: createdAt,
        ),
      );
      await db.scheduledMealDao.insertOutcome(
        ScheduledMealOutcomesCompanion.insert(
          id: 'o1',
          scheduledMealId: 's1',
          date: '2026-10-21',
          status: 'logged',
          entryId: const Value('e4'),
        ),
      );
      final plan = await db.scheduledMealDao.findSchedule('s1');
      expect(plan!.weekdays, 5);
      final outcomes = await db.scheduledMealDao.findOutcomes('s1');
      expect(outcomes.single.entryId, 'e4');

      // A second outcome for the same plan and day is rejected.
      await expectLater(
        db.scheduledMealDao.insertOutcome(
          ScheduledMealOutcomesCompanion.insert(
            id: 'o2',
            scheduledMealId: 's1',
            date: '2026-10-21',
            status: 'dismissed',
          ),
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('UNIQUE'),
          ),
        ),
      );

      // Deleting the plan cascades to its outcomes.
      await db.scheduledMealDao.deleteSchedule('s1');
      expect(await db.select(db.scheduledMealOutcomes).get(), isEmpty);
    });

    test('foreign keys are enforced after the migration', () async {
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      await seedV1(old);
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 2);

      final fkOn = await db
          .customSelect('PRAGMA foreign_keys')
          .map((r) => r.read<int>('foreign_keys'))
          .getSingle();
      expect(fkOn, 1);

      await expectLater(
        db.logDao.insertEntry(
          FoodLogEntriesCompanion.insert(
            id: 'bad',
            logDate: '2026-10-22',
            createdAt: DateTime(2026, 10, 22),
            entryType: 'meal',
            name: 'Ghost',
            calories: 1,
            protein: 0,
            carbs: 0,
            fat: 0,
            mealId: const Value('no-such-meal'),
          ),
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('FOREIGN KEY'),
          ),
        ),
      );
    });

    test('a real v1 file on disk reopens as v2 with its data', () async {
      final dir = Directory.systemTemp.createTempSync('food_log_migration');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/food_log.sqlite');

      // Write a genuine v1 database to disk: the v1 tables (their indexes come
      // with them) and user_version 1.
      final old = v1.DatabaseAtV1(NativeDatabase(file));
      try {
        final migrator = Migrator(old);
        for (final table in old.allTables) {
          await migrator.createTable(table);
        }
        await seedV1(old);
        await old.customStatement('PRAGMA user_version = 1');
      } finally {
        await old.close();
      }

      // Reopening through the app runs the migration.
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      await expectV1DataSurvived(db);
      expect(await userVersion(db), 2);
      expect(await hasStartDateIndex(db), isTrue);
      expect(await db.scheduledMealDao.findSchedulesForMeal('m1'), isEmpty);
    });
  });

  group('fresh database', () {
    test('starts at v2 with empty scheduling tables', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await userVersion(db), 2);
      expect(await db.scheduledMealDao.findSchedulesForMeal('x'), isEmpty);
      expect(await hasStartDateIndex(db), isTrue);
      await db.validateDatabaseSchema();
    });

    test('rejects a second outcome for the same plan and day', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.mealDao.insertMeal(MealsCompanion.insert(id: 'm1', name: 'Lunch'));
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
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('UNIQUE'),
          ),
        ),
      );
    });
  });
}
