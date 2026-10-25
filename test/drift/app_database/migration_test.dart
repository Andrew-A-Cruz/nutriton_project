import 'dart:io';

import 'package:drift/drift.dart' show Migrator, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/body_weight.dart';
import 'package:nutriton_project/data/database/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;

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

  /// The plans' id and weekdays by raw SQL: the Dart row class has columns that
  /// only exist from v7 on, so a database migrated to an older version cannot
  /// read it.
  Future<Map<String, int?>> planWeekdays(AppDatabase db) async => {
    for (final r
        in await db
            .customSelect('SELECT id, weekdays FROM scheduled_meals')
            .get())
      r.read<String>('id'): r.read<int?>('weekdays'),
  };

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

    test(
      'every row and value survives, and the schedule tables work',
      () async {
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
            mealId: const Value('m1'),
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
        expect(await planWeekdays(db), {'s1': 5});
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
      },
    );

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

    test('a real v1 file on disk reopens as v8 with its data', () async {
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
      expect(await userVersion(db), 8);
      expect(await hasStartDateIndex(db), isTrue);
      expect(await db.scheduledMealDao.findSchedulesForMeal('m1'), isEmpty);
    });
  });

  group('v2 to v3 adds meal_slot', () {
    final seconds = DateTime(2026, 10, 20, 9).millisecondsSinceEpoch ~/ 1000;

    /// A realistic v2 database: foods, a meal with a breakdown, entries of all
    /// three types, and a repeating plan with an outcome.
    Future<void> seedV2(v2.DatabaseAtV2 old) async {
      Future<void> sql(String s, [List<Object?> args = const []]) =>
          old.customStatement(s, args);
      await sql(
        'INSERT INTO food_items (id, name, calories, protein, carbs, fat, '
        'serving_weight_g) VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['f1', 'Rice', 130, 3, 28, 0.3, 100],
      );
      await sql(
        'INSERT INTO food_items (id, name, calories, protein, carbs, fat, '
        'serving_weight_g) VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['f2', 'Chicken', 165, 31, 0, 3.6, 100],
      );
      await sql("INSERT INTO meals (id, name) VALUES ('m1', 'Lunch bowl')");
      await sql(
        'INSERT INTO meal_food_items (id, meal_id, food_item_id, weight_g) '
        "VALUES ('mfi1', 'm1', 'f1', 200), ('mfi2', 'm1', 'f2', 150)",
      );
      const cols =
          'id, log_date, created_at, entry_type, name, calories, protein, '
          'carbs, fat, food_item_id, meal_id, servings';
      await sql(
        'INSERT INTO food_log_entries ($cols) VALUES '
        "('e1', '2026-10-20', $seconds, 'food', 'Rice', 195, 4.5, 42, 0.45, "
        "'f1', NULL, 1.5), "
        "('e2', '2026-10-20', $seconds, 'adhoc', 'Cookie', 90, 1, 15, 3, "
        "NULL, NULL, NULL), "
        "('e3', '2026-10-21', $seconds, 'meal', 'Lunch bowl', 507, 37, 56, "
        "6, NULL, 'm1', NULL)",
      );
      await sql(
        'INSERT INTO food_log_entry_items (id, entry_id, food_item_id, name, '
        'weight_g, calories, protein, carbs, fat) VALUES '
        "('i1', 'e3', 'f1', 'Rice', 200, 260, 6, 56, 0.6), "
        "('i2', 'e3', 'f2', 'Chicken', 150, 247, 31, 0, 6)",
      );
      await sql(
        'INSERT INTO scheduled_meals (id, meal_id, start_date, weekdays, '
        "created_at) VALUES ('s1', 'm1', '2026-10-19', 5, $seconds)",
      );
      await sql(
        'INSERT INTO scheduled_meal_outcomes (id, scheduled_meal_id, date, '
        "status, entry_id) VALUES ('o1', 's1', '2026-10-21', 'logged', 'e3')",
      );
    }

    Future<void> expectSurvived(AppDatabase db) async {
      expect(
        (await db.select(db.foodItems).get()).map((f) => f.name),
        unorderedEquals(['Rice', 'Chicken']),
      );
      expect((await db.select(db.meals).get()).single.name, 'Lunch bowl');
      expect(await db.select(db.mealFoodItems).get(), hasLength(2));
      final entries = {
        for (final e in await db.select(db.foodLogEntries).get()) e.id: e,
      };
      expect(entries.keys, unorderedEquals(['e1', 'e2', 'e3']));
      expect(entries['e1']!.servings, 1.5);
      expect(entries['e1']!.calories, 195);
      expect(entries['e2']!.name, 'Cookie');
      expect(entries['e3']!.mealId, 'm1');
      expect(entries['e3']!.calories, 507);
      expect(entries['e3']!.createdAt, DateTime(2026, 10, 20, 9));
      for (final e in entries.values) {
        expect(e.mealSlot, isNull, reason: 'entry ${e.id}');
      }
      final items = await db.select(db.foodLogEntryItems).get();
      expect(items.map((i) => i.id), unorderedEquals(['i1', 'i2']));
      expect(items.every((i) => i.entryId == 'e3'), isTrue);
      expect(await planWeekdays(db), {'s1': 5});
      expect(
        (await db.scheduledMealDao.findOutcomes('s1')).single.entryId,
        'e3',
      );
    }

    test('every row survives with a null meal_slot', () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await seedV2(old);
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);

      await expectSurvived(db);
      expect(await userVersion(db), 3);
    });

    test('the new column accepts slots and rejects other text', () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await seedV2(old);
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);

      await db.logDao.updateEntry(
        'e1',
        const FoodLogEntriesCompanion(mealSlot: Value('dinner')),
      );
      expect((await db.logDao.findEntry('e1'))!.mealSlot, 'dinner');
      await expectLater(
        db.logDao.updateEntry(
          'e1',
          const FoodLogEntriesCompanion(mealSlot: Value('brunch')),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a v1 database runs through to v3', () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);
      expect(await userVersion(db), 3);
    });

    test('a real v2 file on disk reopens as v8 with its data', () async {
      final dir = Directory.systemTemp.createTempSync('food_log_v2');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/food_log.sqlite');
      final old = v2.DatabaseAtV2(NativeDatabase(file));
      try {
        final migrator = Migrator(old);
        for (final table in old.allTables) {
          await migrator.createTable(table);
        }
        await seedV2(old);
        await old.customStatement('PRAGMA user_version = 2');
      } finally {
        await old.close();
      }
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await expectSurvived(db);
      expect(await userVersion(db), 8);
    });
  });

  group('v3 to v4 adds fiber, sugar and sodium', () {
    final seconds = DateTime(2026, 10, 22, 9).millisecondsSinceEpoch ~/ 1000;

    /// A realistic v3 database: foods, a meal with a breakdown, and entries of
    /// all three types, some with a meal slot.
    Future<void> seedV3(v3.DatabaseAtV3 old) async {
      Future<void> sql(String s, [List<Object?> args = const []]) =>
          old.customStatement(s, args);
      await sql(
        'INSERT INTO food_items (id, name, calories, protein, carbs, fat, '
        'serving_weight_g) VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['f1', 'Rice', 130, 3, 28, 0.3, 100],
      );
      await sql(
        'INSERT INTO food_items (id, name, calories, protein, carbs, fat, '
        'serving_weight_g) VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['f2', 'Chicken', 165, 31, 0, 3.6, 100],
      );
      await sql("INSERT INTO meals (id, name) VALUES ('m1', 'Lunch bowl')");
      await sql(
        'INSERT INTO meal_food_items (id, meal_id, food_item_id, weight_g) '
        "VALUES ('mfi1', 'm1', 'f1', 200), ('mfi2', 'm1', 'f2', 150)",
      );
      const cols =
          'id, log_date, created_at, entry_type, name, calories, protein, '
          'carbs, fat, food_item_id, meal_id, servings, meal_slot';
      await sql(
        'INSERT INTO food_log_entries ($cols) VALUES '
        "('e1', '2026-10-22', $seconds, 'food', 'Rice', 195, 4.5, 42, 0.45, "
        "'f1', NULL, 1.5, 'lunch'), "
        "('e2', '2026-10-22', $seconds, 'adhoc', 'Cookie', 90, 1, 15, 3, "
        "NULL, NULL, NULL, 'snack'), "
        "('e3', '2026-10-23', $seconds, 'meal', 'Lunch bowl', 507, 37, 56, "
        "6, NULL, 'm1', NULL, NULL)",
      );
      await sql(
        'INSERT INTO food_log_entry_items (id, entry_id, food_item_id, name, '
        'weight_g, calories, protein, carbs, fat) VALUES '
        "('i1', 'e3', 'f1', 'Rice', 200, 260, 6, 56, 0.6), "
        "('i2', 'e3', 'f2', 'Chicken', 150, 247, 31, 0, 6)",
      );
    }

    Future<void> expectSurvived(AppDatabase db) async {
      final foods = {
        for (final f in await db.select(db.foodItems).get()) f.id: f,
      };
      expect(foods.keys, unorderedEquals(['f1', 'f2']));
      expect(foods['f1']!.calories, 130);
      expect(foods['f2']!.protein, 31);
      expect(await db.select(db.meals).get(), hasLength(1));
      expect(await db.select(db.mealFoodItems).get(), hasLength(2));
      final entries = {
        for (final e in await db.select(db.foodLogEntries).get()) e.id: e,
      };
      expect(entries.keys, unorderedEquals(['e1', 'e2', 'e3']));
      expect(entries['e1']!.servings, 1.5);
      expect(entries['e1']!.mealSlot, 'lunch');
      expect(entries['e2']!.mealSlot, 'snack');
      expect(entries['e3']!.mealSlot, isNull);
      expect(entries['e3']!.calories, 507);
      expect(entries['e3']!.createdAt, DateTime(2026, 10, 22, 9));
      final items = await db.select(db.foodLogEntryItems).get();
      expect(items.map((i) => i.id), unorderedEquals(['i1', 'i2']));
      // Not recorded: null, not 0.
      for (final row in [...foods.values, ...entries.values, ...items]) {
        final r = row as dynamic;
        expect(r.fiber, isNull, reason: '${r.id} fiber');
        expect(r.sugar, isNull, reason: '${r.id} sugar');
        expect(r.sodium, isNull, reason: '${r.id} sodium');
      }
    }

    test('every row survives with null fiber, sugar and sodium', () async {
      final schema = await verifier.schemaAt(3);
      final old = v3.DatabaseAtV3(schema.newConnection());
      await seedV3(old);
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);

      await expectSurvived(db);
      expect(await userVersion(db), 4);
    });

    test('the new columns store values and reject negatives', () async {
      final schema = await verifier.schemaAt(3);
      final old = v3.DatabaseAtV3(schema.newConnection());
      await seedV3(old);
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);

      await db.logDao.updateEntry(
        'e2',
        const FoodLogEntriesCompanion(
          fiber: Value(0.5),
          sugar: Value(9),
          sodium: Value(0),
        ),
      );
      final e2 = (await db.logDao.findEntry('e2'))!;
      expect((e2.fiber, e2.sugar, e2.sodium), (0.5, 9.0, 0.0));
      await expectLater(
        db.logDao.updateEntry(
          'e2',
          const FoodLogEntriesCompanion(sodium: Value(-1)),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a v1 and a v2 database run through to v4', () async {
      for (final from in [1, 2]) {
        final schema = await verifier.schemaAt(from);
        final db = AppDatabase(schema.newConnection());
        addTearDown(db.close);
        await verifier.migrateAndValidate(db, 4);
        expect(await userVersion(db), 4, reason: 'from v$from');
      }
    });

    test('a real v3 file on disk reopens as v8 with its data', () async {
      final dir = Directory.systemTemp.createTempSync('food_log_v3');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/food_log.sqlite');
      final old = v3.DatabaseAtV3(NativeDatabase(file));
      try {
        final migrator = Migrator(old);
        for (final table in old.allTables) {
          await migrator.createTable(table);
        }
        await seedV3(old);
        await old.customStatement('PRAGMA user_version = 3');
      } finally {
        await old.close();
      }
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await expectSurvived(db);
      expect(await userVersion(db), 8);
    });
  });

  group('v4 to v5 adds body_weights', () {
    final seconds = DateTime(2026, 10, 23, 9).millisecondsSinceEpoch ~/ 1000;

    /// A realistic v4 database: a food, an entry with nutrients, a schedule.
    Future<void> seedV4(v4.DatabaseAtV4 old) async {
      Future<void> sql(String s, [List<Object?> args = const []]) =>
          old.customStatement(s, args);
      await sql(
        'INSERT INTO food_items (id, name, calories, protein, carbs, fat, '
        'serving_weight_g, fiber, sodium) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        ['f1', 'Rice', 130, 3, 28, 0.3, 100, 0.4, 1],
      );
      await sql("INSERT INTO meals (id, name) VALUES ('m1', 'Lunch bowl')");
      await sql(
        'INSERT INTO food_log_entries (id, log_date, created_at, entry_type, '
        'name, calories, protein, carbs, fat, food_item_id, servings, '
        'meal_slot, fiber) VALUES '
        "('e1', '2026-10-23', $seconds, 'food', 'Rice', 195, 4.5, 42, 0.45, "
        "'f1', 1.5, 'lunch', 0.6)",
      );
      await sql(
        'INSERT INTO scheduled_meals (id, meal_id, start_date, created_at) '
        "VALUES ('s1', 'm1', '2026-10-24', $seconds)",
      );
    }

    Future<void> expectSurvived(AppDatabase db) async {
      final foods = await db.select(db.foodItems).get();
      expect(foods.single.calories, 130);
      expect(foods.single.fiber, 0.4);
      expect(foods.single.sugar, isNull);
      final entry = (await db.select(db.foodLogEntries).get()).single;
      expect(entry.servings, 1.5);
      expect(entry.mealSlot, 'lunch');
      expect(entry.fiber, 0.6);
      expect(await db.select(db.meals).get(), hasLength(1));
      expect(await planWeekdays(db), hasLength(1));
    }

    test('every row survives and the new table starts empty', () async {
      final schema = await verifier.schemaAt(4);
      final old = v4.DatabaseAtV4(schema.newConnection());
      await seedV4(old);
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 5);

      await expectSurvived(db);
      expect(await db.select(db.bodyWeights).get(), isEmpty);
      expect(await userVersion(db), 5);
    });

    test('the new table stores one reading per day and rejects <= 0', () async {
      final schema = await verifier.schemaAt(4);
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      // To the current version: the DAO writes columns added after v5.
      await verifier.migrateAndValidate(db, 8);

      final at = DateTime(2026, 10, 24, 7);
      await db.bodyWeightDao.upsertForDate('2026-10-24', 80.5, at);
      await db.bodyWeightDao.upsertForDate('2026-10-24', 80.1, at);
      final rows = await db.select(db.bodyWeights).get();
      expect(rows, hasLength(1));
      expect(rows.single.weightKg, 80.1);
      await expectLater(
        db.bodyWeightDao.upsertForDate('2026-10-25', 0, at),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a v1, v2 and v3 database run through to v5', () async {
      for (final from in [1, 2, 3]) {
        final schema = await verifier.schemaAt(from);
        final db = AppDatabase(schema.newConnection());
        addTearDown(db.close);
        await verifier.migrateAndValidate(db, 5);
        expect(await userVersion(db), 5, reason: 'from v$from');
        expect(await db.select(db.bodyWeights).get(), isEmpty);
      }
    });

    test('a real v4 file on disk reopens as v8 with its data', () async {
      final dir = Directory.systemTemp.createTempSync('food_log_v4');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/food_log.sqlite');
      final old = v4.DatabaseAtV4(NativeDatabase(file));
      try {
        final migrator = Migrator(old);
        for (final table in old.allTables) {
          await migrator.createTable(table);
        }
        await seedV4(old);
        await old.customStatement('PRAGMA user_version = 4');
      } finally {
        await old.close();
      }
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await expectSurvived(db);
      expect(await userVersion(db), 8);
      expect(await db.select(db.bodyWeights).get(), isEmpty);
    });
  });

  group('v5 to v6 adds food_items.barcode', () {
    final seconds = DateTime(2026, 10, 24, 9).millisecondsSinceEpoch ~/ 1000;

    /// A realistic v5 database: a food, an entry and a body weight.
    Future<void> seedV5(v5.DatabaseAtV5 old) async {
      Future<void> sql(String s, [List<Object?> args = const []]) =>
          old.customStatement(s, args);
      await sql(
        'INSERT INTO food_items (id, name, calories, protein, carbs, fat, '
        'serving_weight_g, fiber) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        ['f1', 'Rice', 130, 3, 28, 0.3, 100, 0.4],
      );
      await sql(
        'INSERT INTO food_log_entries (id, log_date, created_at, entry_type, '
        'name, calories, protein, carbs, fat, food_item_id, servings, '
        'meal_slot) VALUES '
        "('e1', '2026-10-24', $seconds, 'food', 'Rice', 195, 4.5, 42, 0.45, "
        "'f1', 1.5, 'lunch')",
      );
    }

    Future<void> expectSurvived(AppDatabase db) async {
      final food = (await db.select(db.foodItems).get()).single;
      expect(food.calories, 130);
      expect(food.fiber, 0.4);
      expect(food.barcode, isNull);
      final entry = (await db.select(db.foodLogEntries).get()).single;
      expect(entry.servings, 1.5);
      expect(entry.mealSlot, 'lunch');
    }

    Future<bool> hasBarcodeIndex(AppDatabase db) async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'food_items_barcode'",
          )
          .get();
      return rows.isNotEmpty;
    }

    test(
      'every row survives with a null barcode and the index exists',
      () async {
        final schema = await verifier.schemaAt(5);
        final old = v5.DatabaseAtV5(schema.newConnection());
        await seedV5(old);
        await old.close();

        final db = AppDatabase(schema.newConnection());
        addTearDown(db.close);
        await verifier.migrateAndValidate(db, 6);

        await expectSurvived(db);
        expect(await hasBarcodeIndex(db), isTrue);
        expect(await userVersion(db), 6);
      },
    );

    test('a barcode can be stored and found after the migration', () async {
      final schema = await verifier.schemaAt(5);
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 6);

      await db.foodDao.insertFood(
        FoodItemsCompanion.insert(
          id: 'f2',
          name: 'Soda',
          calories: 42,
          protein: 0,
          carbs: 10,
          fat: 0,
          servingWeightG: 330,
          barcode: const Value('4006381333931'),
        ),
      );
      final found = await db.foodDao.findActiveByBarcode('4006381333931');
      expect(found?.id, 'f2');
    });

    test('a v1 to v4 database runs through to v6', () async {
      for (final from in [1, 2, 3, 4]) {
        final schema = await verifier.schemaAt(from);
        final db = AppDatabase(schema.newConnection());
        addTearDown(db.close);
        await verifier.migrateAndValidate(db, 6);
        expect(await userVersion(db), 6, reason: 'from v$from');
        expect(await hasBarcodeIndex(db), isTrue, reason: 'from v$from');
      }
    });

    test('a real v5 file on disk reopens as v8 with its data', () async {
      final dir = Directory.systemTemp.createTempSync('food_log_v5');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/food_log.sqlite');
      final old = v5.DatabaseAtV5(NativeDatabase(file));
      try {
        final migrator = Migrator(old);
        for (final table in old.allTables) {
          await migrator.createTable(table);
        }
        await seedV5(old);
        await old.customStatement('PRAGMA user_version = 5');
      } finally {
        await old.close();
      }
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await expectSurvived(db);
      expect(await userVersion(db), 8);
    });
  });

  group('v6 to v7 lets a plan be a food, with a slot and servings', () {
    final seconds = DateTime(2026, 10, 24, 9).millisecondsSinceEpoch ~/ 1000;

    /// A realistic v6 database: a meal with two plans (repeating and one-off),
    /// a logged and a dismissed outcome, and the entry the first one made.
    Future<void> seedV6(v6.DatabaseAtV6 old) async {
      Future<void> sql(String s, [List<Object?> args = const []]) =>
          old.customStatement(s, args);
      await sql(
        'INSERT INTO food_items (id, name, calories, protein, carbs, fat, '
        'serving_weight_g) VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['f1', 'Rice', 130, 3, 28, 0.3, 100],
      );
      await sql("INSERT INTO meals (id, name) VALUES ('m1', 'Lunch')");
      await sql(
        'INSERT INTO food_log_entries (id, log_date, created_at, entry_type, '
        'name, calories, protein, carbs, fat, meal_id) VALUES '
        "('e1', '2026-10-21', $seconds, 'meal', 'Lunch', 260, 6, 56, 0.6, 'm1')",
      );
      await sql(
        'INSERT INTO scheduled_meals (id, meal_id, start_date, weekdays, '
        'created_at) VALUES '
        "('s1', 'm1', '2026-10-19', 31, $seconds), "
        "('s2', 'm1', '2026-10-25', NULL, $seconds)",
      );
      await sql(
        'INSERT INTO scheduled_meal_outcomes (id, scheduled_meal_id, date, '
        'status, entry_id) VALUES '
        "('o1', 's1', '2026-10-21', 'logged', 'e1'), "
        "('o2', 's1', '2026-10-22', 'dismissed', NULL)",
      );
    }

    Future<void> expectSurvived(AppDatabase db) async {
      final plans = {
        for (final p in await db.select(db.scheduledMeals).get()) p.id: p,
      };
      expect(plans.keys, unorderedEquals(['s1', 's2']));
      final repeating = plans['s1']!;
      expect(repeating.mealId, 'm1');
      expect(repeating.foodItemId, isNull);
      expect(repeating.startDate, '2026-10-19');
      expect(repeating.weekdays, 31);
      expect(repeating.mealSlot, isNull);
      expect(repeating.servings, 1);
      expect(
        repeating.createdAt,
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      );
      final oneOff = plans['s2']!;
      expect(oneOff.weekdays, isNull);
      expect(oneOff.servings, 1);

      final outcomes = {
        for (final o in await db.select(db.scheduledMealOutcomes).get())
          o.id: o,
      };
      expect(outcomes.keys, unorderedEquals(['o1', 'o2']));
      expect(outcomes['o1']!.status, 'logged');
      expect(outcomes['o1']!.entryId, 'e1');
      expect(outcomes['o2']!.status, 'dismissed');
      expect(await db.select(db.foodLogEntries).get(), hasLength(1));
    }

    Future<AppDatabase> migrated() async {
      final schema = await verifier.schemaAt(6);
      final old = v6.DatabaseAtV6(schema.newConnection());
      await seedV6(old);
      await old.close();
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 7);
      return db;
    }

    test('plans and outcomes survive with a null slot and 1 serving', () async {
      final db = await migrated();

      await expectSurvived(db);
      expect(await hasStartDateIndex(db), isTrue);
      expect(await userVersion(db), 7);
    });

    test('a food-only plan can be added; bad plans are rejected', () async {
      final db = await migrated();

      Future<void> insert(
        String id, {
        String? meal,
        String? food,
        String? slot,
        double? servings,
      }) => db.scheduledMealDao.insertSchedule(
        ScheduledMealsCompanion.insert(
          id: id,
          mealId: Value(meal),
          foodItemId: Value(food),
          mealSlot: Value(slot),
          servings: servings == null ? const Value.absent() : Value(servings),
          startDate: '2026-10-26',
          createdAt: DateTime(2026, 10, 25),
        ),
      );

      await insert('s3', food: 'f1', slot: 'snack', servings: 0.5);
      final food = (await db.scheduledMealDao.findSchedule('s3'))!;
      expect(food.mealId, isNull);
      expect(food.foodItemId, 'f1');
      expect(food.mealSlot, 'snack');
      expect(food.servings, 0.5);

      // Both sources, neither, a bad slot, zero servings, an unknown food.
      for (final bad in [
        insert('x1', meal: 'm1', food: 'f1'),
        insert('x2'),
        insert('x3', food: 'f1', slot: 'brunch'),
        insert('x4', food: 'f1', servings: 0),
        insert('x5', food: 'no-such-food'),
      ]) {
        await expectLater(bad, throwsA(isA<SqliteException>()));
      }

      // Deleting the food cascades to the plan and its outcomes.
      await db.scheduledMealDao.insertOutcome(
        ScheduledMealOutcomesCompanion.insert(
          id: 'o3',
          scheduledMealId: 's3',
          date: '2026-10-26',
          status: 'dismissed',
        ),
      );
      await (db.delete(db.foodItems)..where((t) => t.id.equals('f1'))).go();
      expect(await db.scheduledMealDao.findSchedule('s3'), isNull);
      expect(await db.scheduledMealDao.findOutcomes('s3'), isEmpty);
    });

    test('foreign keys are on and deleting a plan still cascades', () async {
      final db = await migrated();

      final fkOn = await db
          .customSelect('PRAGMA foreign_keys')
          .map((r) => r.read<int>('foreign_keys'))
          .getSingle();
      expect(fkOn, 1);
      await db.scheduledMealDao.deleteSchedule('s1');
      expect(await db.select(db.scheduledMealOutcomes).get(), isEmpty);
      expect(await db.select(db.scheduledMeals).get(), hasLength(1));
    });

    test('a v1 to v5 database runs through to v7', () async {
      for (final from in [1, 2, 3, 4, 5]) {
        final schema = await verifier.schemaAt(from);
        final db = AppDatabase(schema.newConnection());
        addTearDown(db.close);
        await verifier.migrateAndValidate(db, 7);
        expect(await userVersion(db), 7, reason: 'from v$from');
      }
    });

    test('a real v6 file on disk reopens as v8 with its data', () async {
      final dir = Directory.systemTemp.createTempSync('food_log_v6');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/food_log.sqlite');
      final old = v6.DatabaseAtV6(NativeDatabase(file));
      try {
        final migrator = Migrator(old);
        for (final table in old.allTables) {
          await migrator.createTable(table);
        }
        await seedV6(old);
        await old.customStatement('PRAGMA user_version = 6');
      } finally {
        await old.close();
      }
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await expectSurvived(db);
      expect(await userVersion(db), 8);
    });
  });

  group('v7 to v8 adds body_weights.source', () {
    final seconds = DateTime(2026, 10, 24, 7).millisecondsSinceEpoch ~/ 1000;

    Future<void> seedV7(v7.DatabaseAtV7 old) => old.customStatement(
      'INSERT INTO body_weights (log_date, weight_kg, created_at) VALUES '
      "('2026-10-20', 80.5, $seconds), ('2026-10-21', 80.1, $seconds)",
    );

    Future<void> expectSurvived(AppDatabase db) async {
      final rows = await db.select(db.bodyWeights).get();
      expect(rows.map((r) => r.logDate), ['2026-10-20', '2026-10-21']);
      expect(rows.map((r) => r.weightKg), [80.5, 80.1]);
      // Existing readings were typed in, so they stay manual.
      expect(rows.map((r) => r.source), ['manual', 'manual']);
      expect(
        rows.map((r) => WeightSource.fromDb(r.source)),
        everyElement(WeightSource.manual),
      );
    }

    test('readings survive and become manual', () async {
      final schema = await verifier.schemaAt(7);
      final old = v7.DatabaseAtV7(schema.newConnection());
      await seedV7(old);
      await old.close();
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 8);

      await expectSurvived(db);
      expect(await userVersion(db), 8);
    });

    test(
      'a health reading can be stored and a manual one replaces it',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final now = DateTime(2026, 10, 25);

        await db.bodyWeightDao.upsertForDate(
          '2026-10-22',
          79.9,
          now,
          source: WeightSource.health,
        );
        expect((await db.select(db.bodyWeights).getSingle()).source, 'health');
        await db.bodyWeightDao.upsertForDate('2026-10-22', 80, now);
        expect((await db.select(db.bodyWeights).getSingle()).source, 'manual');
      },
    );

    test('a real v7 file on disk reopens as v8 with its data', () async {
      final dir = Directory.systemTemp.createTempSync('food_log_v7');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/food_log.sqlite');
      final old = v7.DatabaseAtV7(NativeDatabase(file));
      try {
        final migrator = Migrator(old);
        for (final table in old.allTables) {
          await migrator.createTable(table);
        }
        await seedV7(old);
        await old.customStatement('PRAGMA user_version = 7');
      } finally {
        await old.close();
      }
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await expectSurvived(db);
      expect(await userVersion(db), 8);
    });
  });

  group('fresh database', () {
    test('starts at v8 with empty scheduling tables', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await userVersion(db), 8);
      expect(await db.scheduledMealDao.findSchedulesForMeal('x'), isEmpty);
      expect(await hasStartDateIndex(db), isTrue);
      await db.validateDatabaseSchema();
    });

    test('rejects a second outcome for the same plan and day', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.mealDao.insertMeal(
        MealsCompanion.insert(id: 'm1', name: 'Lunch'),
      );
      await db.scheduledMealDao.insertSchedule(
        ScheduledMealsCompanion.insert(
          id: 's1',
          mealId: const Value('m1'),
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
