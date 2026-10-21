import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fills [db] with one of everything: foods, a meal, food / adhoc / meal log
/// entries (the meal one with a breakdown), a repeating and a one-off plan,
/// and one confirmed outcome.
Future<void> seedData(AppDatabase db) async {
  final catalog = CatalogRepository(db);
  final log = LogRepository(db);
  final foodId = await catalog.createFood(
    name: 'Rice',
    perServing: const Macros(calories: 130, protein: 3, carbs: 28, fat: 0.3),
    servingWeightG: 100,
  );
  final mealId = await catalog.createMeal(
    name: 'Lunch',
    items: [MealItemInput(foodItemId: foodId, weightG: 200)],
  );
  final food = (await db.foodDao.findById(foodId))!;
  await log.logFood(logDate: '2026-10-20', food: food, servings: 1.5);
  await log.logAdhoc(
    logDate: '2026-10-20',
    name: 'Snack',
    macros: const Macros(calories: 90, protein: 1, carbs: 15, fat: 3),
  );
  final meal = (await db.mealDao.findById(mealId))!;
  await log.logMeal(
    logDate: '2026-10-20',
    meal: meal,
    items: [MealItemInput(foodItemId: foodId, weightG: 150)],
  );
  final schedule = ScheduleRepository(db);
  final planId = await schedule.scheduleWeekdays(
    mealId: mealId,
    startDate: '2026-10-19',
    weekdays: {1, 3},
  );
  await schedule.confirm(planId, date: '2026-10-21'); // a Wednesday
  await schedule.scheduleOnce(mealId: mealId, date: '2026-10-25');
}

final sourceSettings = UserSettings(
  onboardingComplete: true,
  primaryMetric: Metric.protein,
  trackedMetrics: {Metric.protein, Metric.carbs},
  goals: {Metric.protein: 140, Metric.carbs: 250},
  displayUnit: WeightUnit.oz,
);

final targetSettings = UserSettings(
  onboardingComplete: true,
  primaryMetric: Metric.calories,
  goals: {Metric.calories: 2000},
);

/// The export with the timestamp removed, so two exports can be compared.
Map<String, dynamic> content(String json) =>
    (jsonDecode(json) as Map<String, dynamic>)..remove('exportedAt');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase source;
  late AppDatabase target;
  late SharedPreferences prefs;
  late UserPreferences userPrefs;
  late BackupRepository sourceRepo;
  late BackupRepository targetRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    userPrefs = UserPreferences(prefs);
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
    sourceRepo = BackupRepository(source, userPrefs);
    targetRepo = BackupRepository(target, userPrefs);
    await seedData(source);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  /// Exports the source with [sourceSettings], then switches the (shared, in
  /// tests) preferences to [targetSettings] as the importing device's state.
  Future<String> exportSource() async {
    await userPrefs.write(sourceSettings);
    final json = await sourceRepo.exportJson();
    await userPrefs.write(targetSettings);
    return json;
  }

  test(
    'export then import into an empty database reproduces everything',
    () async {
      final json = await exportSource();

      final restored = await targetRepo.importJson(json);

      expect(restored.primaryMetric, Metric.protein);
      expect(userPrefs.read().goals, {Metric.protein: 140, Metric.carbs: 250});
      expect(userPrefs.read().displayUnit, WeightUnit.oz);
      expect(content(await targetRepo.exportJson()), content(json));
      expect(await target.select(target.foodLogEntries).get(), hasLength(4));
      expect(await target.select(target.foodLogEntryItems).get(), hasLength(2));
      expect(
        await target.select(target.scheduledMealOutcomes).get(),
        hasLength(1),
      );
    },
  );

  test('import replaces existing data instead of merging', () async {
    await seedData(target);
    await CatalogRepository(target).createFood(
      name: 'Only here',
      perServing: const Macros(calories: 1, protein: 0, carbs: 0, fat: 0),
      servingWeightG: 10,
    );

    await targetRepo.importJson(await exportSource());

    final foods = await target.select(target.foodItems).get();
    expect(foods.map((f) => f.name), ['Rice']);
    expect(await target.select(target.foodLogEntries).get(), hasLength(4));
    expect(await target.select(target.scheduledMeals).get(), hasLength(2));
  });

  test('an empty backup clears the data', () async {
    final emptyDb = AppDatabase(NativeDatabase.memory());
    addTearDown(emptyDb.close);
    final json = await BackupRepository(emptyDb, userPrefs).exportJson();
    await seedData(target);

    await targetRepo.importJson(json);

    expect(await target.select(target.foodItems).get(), isEmpty);
    expect(await target.select(target.foodLogEntries).get(), isEmpty);
    expect(await target.select(target.scheduledMeals).get(), isEmpty);
  });

  test('names the file after the date', () {
    expect(
      BackupRepository.fileNameFor(DateTime(2026, 10, 21, 8)),
      'nutriton-backup-2026-10-21.json',
    );
  });

  group('failures leave existing data untouched', () {
    late String before;
    late Map<String, dynamic> good;

    setUp(() async {
      good = content(await exportSource());
      await seedData(target);
      before = await targetRepo.exportJson();
    });

    Future<void> expectRejected(Object json, [String? message]) async {
      await expectLater(
        targetRepo.importJson(json is String ? json : jsonEncode(json)),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            message == null ? isNotEmpty : contains(message),
          ),
        ),
      );
      expect(content(await targetRepo.exportJson()), content(before));
      expect(userPrefs.read().primaryMetric, Metric.calories);
      expect(userPrefs.read().goals, {Metric.calories: 2000});
    }

    test('not JSON', () => expectRejected('oops', 'not valid JSON'));

    test(
      'newer version',
      () => expectRejected(good..['version'] = 99, 'newer'),
    );

    test(
      'missing table',
      () => expectRejected(good..remove('meals'), '"meals"'),
    );

    test('rolls back when a row breaks a foreign key', () async {
      (good['meal_food_items'] as List).first['foodItemId'] = 'missing';
      await expectRejected(good, 'nothing was changed');
    });

    test('rolls back when a row breaks a CHECK rule', () async {
      (good['food_log_entries'] as List).last['calories'] = -1;
      await expectRejected(good, 'nothing was changed');
    });

    test(
      'rolls back a duplicate id found after earlier tables were written',
      () async {
        final entries = good['food_log_entries'] as List;
        entries.add(entries.first);
        await expectRejected(good, 'nothing was changed');
      },
    );
  });
}
