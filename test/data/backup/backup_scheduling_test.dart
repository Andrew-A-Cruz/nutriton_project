import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backups and the planned foods, slot and servings added in M17. The backup
/// format version stays at 1: `food_item_id` and `meal_slot` are nullable, and
/// a missing `servings` reads as 1.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase source;
  late AppDatabase target;
  late BackupRepository sourceRepo;
  late BackupRepository targetRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = UserPreferences(await SharedPreferences.getInstance());
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
    sourceRepo = BackupRepository(source, prefs);
    targetRepo = BackupRepository(target, prefs);
    await source.foodDao.insertFood(
      FoodItemsCompanion.insert(
        id: 'f1',
        name: 'Rice',
        calories: 130,
        protein: 3,
        carbs: 28,
        fat: 0.3,
        servingWeightG: 100,
      ),
    );
    await source.mealDao.insertMeal(
      MealsCompanion.insert(id: 'm1', name: 'Lunch'),
    );
    await source.scheduledMealDao.insertSchedule(
      ScheduledMealsCompanion.insert(
        id: 'sFood',
        foodItemId: const Value('f1'),
        mealSlot: const Value('dinner'),
        servings: const Value(2.5),
        startDate: '2026-10-21',
        weekdays: const Value(31),
        createdAt: DateTime(2026, 10, 20),
      ),
    );
    await source.scheduledMealDao.insertSchedule(
      ScheduledMealsCompanion.insert(
        id: 'sMeal',
        mealId: const Value('m1'),
        startDate: '2026-10-22',
        createdAt: DateTime(2026, 10, 20),
      ),
    );
    await source.scheduledMealDao.insertOutcome(
      ScheduledMealOutcomesCompanion.insert(
        id: 'o1',
        scheduledMealId: 'sFood',
        date: '2026-10-21',
        status: 'dismissed',
      ),
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, ScheduledMeal>> plans(AppDatabase db) async => {
    for (final p in await db.select(db.scheduledMeals).get()) p.id: p,
  };

  test('the file carries the new columns; version stays 1', () async {
    final json =
        jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;
    expect(json['version'], 1);
    final rows = {
      for (final r in json['scheduled_meals'] as List) r['id']: r as Map,
    };
    expect(rows['sFood']!['foodItemId'], 'f1');
    expect(rows['sFood']!['mealSlot'], 'dinner');
    expect(rows['sFood']!['servings'], 2.5);
    expect(rows['sMeal']!['foodItemId'], isNull);
  });

  test(
    'round trip restores food and meal plans with slot and servings',
    () async {
      await targetRepo.importJson(await sourceRepo.exportJson());

      final restored = await plans(target);
      expect(restored.keys, unorderedEquals(['sFood', 'sMeal']));
      final food = restored['sFood']!;
      expect(food.foodItemId, 'f1');
      expect(food.mealId, isNull);
      expect(food.mealSlot, 'dinner');
      expect(food.servings, 2.5);
      expect(food.weekdays, 31);
      final meal = restored['sMeal']!;
      expect(meal.mealId, 'm1');
      expect(meal.foodItemId, isNull);
      expect(meal.mealSlot, isNull);
      expect(meal.servings, 1);
      expect(
        await target.select(target.scheduledMealOutcomes).get(),
        hasLength(1),
      );
    },
  );

  test('a file from before M17 imports with null slot and 1 serving', () async {
    final json =
        jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;
    final old = (json['scheduled_meals'] as List)
        .where((r) => r['id'] == 'sMeal')
        .map((r) {
          final row = Map<String, dynamic>.from(r as Map);
          row
            ..remove('foodItemId')
            ..remove('mealSlot')
            ..remove('servings');
          return row;
        })
        .toList();
    json['scheduled_meals'] = old;
    json['scheduled_meal_outcomes'] = [];

    await targetRepo.importJson(jsonEncode(json));

    final plan = (await plans(target))['sMeal']!;
    expect((plan.mealId, plan.foodItemId), ('m1', null));
    expect((plan.mealSlot, plan.servings), (null, 1));
  });

  test('the real pre-M17 version 1 fixture still imports its plans', () async {
    final text = File(
      'test/data/backup/fixtures/backup_v1.json',
    ).readAsStringSync();

    await targetRepo.importJson(text);

    final restored = (await plans(target)).values.toList();
    expect(restored, hasLength(2));
    for (final p in restored) {
      expect(p.mealId, isNotNull);
      expect(p.foodItemId, isNull);
      expect(p.mealSlot, isNull);
      expect(p.servings, 1);
    }
    expect(
      await target.select(target.scheduledMealOutcomes).get(),
      hasLength(1),
    );
  });

  test('a plan with both or neither source is refused on import', () async {
    final json =
        jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;
    for (final r in json['scheduled_meals'] as List) {
      (r as Map)['foodItemId'] = 'f1';
      r['mealId'] = 'm1';
    }
    await expectLater(
      targetRepo.importJson(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
    expect(await plans(target), isEmpty);
  });
}
