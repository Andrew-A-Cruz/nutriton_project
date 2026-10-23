import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late LogRepository log;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
    log = LogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  const chickenPer100 = Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6);
  const ricePer100 = Macros(calories: 130, protein: 2.7, carbs: 28, fat: 0.3);
  const day = '2026-10-20';

  Future<String> makeChicken() => catalog.createFood(
    name: 'Chicken breast',
    perServing: chickenPer100,
    servingWeightG: 100,
  );

  Future<String> makeRice() => catalog.createFood(
    name: 'White rice',
    perServing: ricePer100,
    servingWeightG: 100,
  );

  /// A meal with chicken and rice, logged once.
  Future<({String mealId, String entryId})> logChickenRiceMeal() async {
    final chickenId = await makeChicken();
    final riceId = await makeRice();
    final mealId = await catalog.createMeal(
      name: 'Chicken & rice',
      items: [
        MealItemInput(foodItemId: chickenId, weightG: 150),
        MealItemInput(foodItemId: riceId, weightG: 200),
      ],
    );
    final entryId = await log.logMeal(
      logDate: day,
      meal: (await catalog.findMeal(mealId))!,
      items: [
        MealItemInput(foodItemId: chickenId, weightG: 150),
        MealItemInput(foodItemId: riceId, weightG: 200),
      ],
    );
    return (mealId: mealId, entryId: entryId);
  }

  group('deleteEntryForUndo and restoreEntry', () {
    test('round-trips a food entry with every field unchanged', () async {
      final chickenId = await makeChicken();
      final entryId = await log.logFood(
        logDate: day,
        food: (await catalog.findFood(chickenId))!,
        servings: 1.5,
      );
      final before = (await db.logDao.findEntry(entryId))!;

      final deleted = await log.deleteEntryForUndo(entryId);
      expect(deleted, isNotNull);
      expect(await db.logDao.findEntry(entryId), isNull);

      await log.restoreEntry(deleted!);

      final after = (await db.logDao.findEntry(entryId))!;
      expect(after, equals(before));
      expect(after.foodItemId, chickenId);
      expect(after.servings, 1.5);
      expect(after.calories, closeTo(247.5, 1e-9));
    });

    test('round-trips a meal entry and restores its breakdown rows', () async {
      final made = await logChickenRiceMeal();
      final before = (await db.logDao.findEntry(made.entryId))!;
      final itemsBefore = await db.logDao.findEntryItems(made.entryId);
      expect(itemsBefore, hasLength(2));

      final deleted = await log.deleteEntryForUndo(made.entryId);
      expect(await db.logDao.findEntryItems(made.entryId), isEmpty);
      expect(deleted!.items, hasLength(2));

      await log.restoreEntry(deleted);

      expect(await db.logDao.findEntry(made.entryId), equals(before));
      final itemsAfter = await db.logDao.findEntryItems(made.entryId);
      expect(itemsAfter, unorderedEquals(itemsBefore));
    });

    test('round-trips a one-off entry', () async {
      final entryId = await log.logAdhoc(
        logDate: day,
        name: 'Birthday cake',
        macros: const Macros(calories: 350, protein: 4, carbs: 50, fat: 14),
      );
      final before = (await db.logDao.findEntry(entryId))!;

      final deleted = await log.deleteEntryForUndo(entryId);
      await log.restoreEntry(deleted!);

      expect(await db.logDao.findEntry(entryId), equals(before));
      expect(deleted.outcomeIds, isEmpty);
      expect(deleted.items, isEmpty);
    });

    test('restores the scheduled-meal outcome link', () async {
      final made = await logChickenRiceMeal();
      final schedules = ScheduleRepository(db);
      final scheduledId = await schedules.scheduleOnce(
        mealId: made.mealId,
        date: day,
      );
      // Confirming the plan creates the entry and an outcome pointing at it.
      final entryId = await schedules.confirm(scheduledId, date: day);
      final outcomeBefore = (await db.scheduledMealDao.findOutcomes(
        scheduledId,
      )).single;
      expect(outcomeBefore.entryId, entryId);

      final deleted = await log.deleteEntryForUndo(entryId);
      expect(deleted!.outcomeIds, [outcomeBefore.id]);
      // Deleting the entry clears the provenance link.
      expect(
        (await db.scheduledMealDao.findOutcomes(scheduledId)).single.entryId,
        isNull,
      );

      await log.restoreEntry(deleted);

      final outcomeAfter = (await db.scheduledMealDao.findOutcomes(
        scheduledId,
      )).single;
      expect(outcomeAfter.entryId, entryId);
      expect(outcomeAfter.status, 'logged');
    });

    test('restore after the referenced food was deleted drops the link',
        () async {
      final chickenId = await makeChicken();
      final entryId = await log.logFood(
        logDate: day,
        food: (await catalog.findFood(chickenId))!,
        servings: 2,
      );
      final before = (await db.logDao.findEntry(entryId))!;
      final deleted = await log.deleteEntryForUndo(entryId);

      // Nothing references the food any more, so it can be removed.
      await db.foodDao.deleteFood(chickenId);

      await log.restoreEntry(deleted!);

      final after = (await db.logDao.findEntry(entryId))!;
      expect(after.foodItemId, isNull);
      expect(after.name, before.name);
      expect(after.calories, before.calories);
      expect(after.servings, 2);
    });

    test('restore after the meal and its foods were deleted drops both links',
        () async {
      final made = await logChickenRiceMeal();
      final itemsBefore = await db.logDao.findEntryItems(made.entryId);
      final deleted = await log.deleteEntryForUndo(made.entryId);

      // Removing the template first lets the foods go.
      await db.mealDao.deleteMeal(made.mealId);
      for (final item in itemsBefore) {
        await db.foodDao.deleteFood(item.foodItemId!);
      }

      await log.restoreEntry(deleted!);

      final after = (await db.logDao.findEntry(made.entryId))!;
      expect(after.mealId, isNull);
      expect(after.name, 'Chicken & rice');
      final items = await db.logDao.findEntryItems(made.entryId);
      expect(items, hasLength(2));
      expect(items.map((i) => i.foodItemId), everyElement(isNull));
    });

    test('restoring keeps the list order when entries share a createdAt',
        () async {
      // Same second and same day: the list falls back to insertion order.
      final createdAt = DateTime(2026, 10, 20, 9);
      for (final id in ['first', 'second']) {
        await db.logDao.insertEntry(
          FoodLogEntriesCompanion.insert(
            id: id,
            logDate: day,
            createdAt: createdAt,
            entryType: 'adhoc',
            name: id,
            calories: 100,
            protein: 0,
            carbs: 0,
            fat: 0,
          ),
        );
      }
      expect(
        (await db.logDao.findEntriesForDate(day)).map((e) => e.id),
        ['first', 'second'],
      );

      final deleted = await log.deleteEntryForUndo('first');
      await log.restoreEntry(deleted!);

      expect(
        (await db.logDao.findEntriesForDate(day)).map((e) => e.id),
        ['first', 'second'],
      );
      expect(
        (await db.logDao.watchEntriesForDate(day).first).map((e) => e.id),
        ['first', 'second'],
      );
    });

    test('restoring twice is a no-op', () async {
      final made = await logChickenRiceMeal();
      final deleted = await log.deleteEntryForUndo(made.entryId);

      await log.restoreEntry(deleted!);
      await log.restoreEntry(deleted);

      final entries = await db.logDao.findEntriesForDate(day);
      expect(entries.where((e) => e.id == made.entryId), hasLength(1));
      expect(await db.logDao.findEntryItems(made.entryId), hasLength(2));
    });

    test('deleteEntryForUndo on a missing id returns null', () async {
      expect(await log.deleteEntryForUndo('no-such-entry'), isNull);
    });
  });

  group('updateAdhoc', () {
    late String entryId;

    setUp(() async {
      entryId = await log.logAdhoc(
        logDate: day,
        name: 'Cake',
        macros: const Macros(calories: 300, protein: 3, carbs: 40, fat: 12),
      );
    });

    test('updates the name (trimmed) and macros', () async {
      await log.updateAdhoc(
        entryId,
        name: '  Carrot cake  ',
        macros: const Macros(calories: 410, protein: 5, carbs: 52, fat: 18),
      );

      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.name, 'Carrot cake');
      expect(entry.calories, 410);
      expect(entry.protein, 5);
      expect(entry.carbs, 52);
      expect(entry.fat, 18);
      expect(entry.entryType, 'adhoc');
      expect(entry.logDate, day);
    });

    test('an empty name is rejected and nothing changes', () async {
      await expectLater(
        log.updateAdhoc(
          entryId,
          name: '   ',
          macros: const Macros(calories: 1),
        ),
        throwsArgumentError,
      );
      expect((await db.logDao.findEntry(entryId))!.name, 'Cake');
    });

    test('a negative macro is rejected and nothing changes', () async {
      await expectLater(
        log.updateAdhoc(
          entryId,
          name: 'Cake',
          macros: const Macros(calories: 100, fat: -1),
        ),
        throwsArgumentError,
      );
      expect((await db.logDao.findEntry(entryId))!.calories, 300);
    });

    test('a food entry is rejected with StateError', () async {
      final chickenId = await makeChicken();
      final foodEntryId = await log.logFood(
        logDate: day,
        food: (await catalog.findFood(chickenId))!,
        servings: 1,
      );
      await expectLater(
        log.updateAdhoc(
          foodEntryId,
          name: 'Renamed',
          macros: const Macros(calories: 1),
        ),
        throwsStateError,
      );
      expect((await db.logDao.findEntry(foodEntryId))!.name, 'Chicken breast');
    });

    test('a missing entry is rejected with StateError', () async {
      await expectLater(
        log.updateAdhoc(
          'no-such-entry',
          name: 'Cake',
          macros: const Macros(calories: 1),
        ),
        throwsStateError,
      );
    });
  });

  group('moveEntry', () {
    const target = '2026-10-21';

    test('moves a food entry', () async {
      final chickenId = await makeChicken();
      final entryId = await log.logFood(
        logDate: day,
        food: (await catalog.findFood(chickenId))!,
        servings: 1,
      );
      await log.moveEntry(entryId, target);
      expect((await db.logDao.findEntry(entryId))!.logDate, target);
    });

    test('moves a meal entry and keeps its breakdown', () async {
      final made = await logChickenRiceMeal();
      await log.moveEntry(made.entryId, target);
      final entry = (await db.logDao.findEntry(made.entryId))!;
      expect(entry.logDate, target);
      expect(entry.entryType, 'meal');
      expect(await db.logDao.findEntryItems(made.entryId), hasLength(2));
    });

    test('moves a one-off entry', () async {
      final entryId = await log.logAdhoc(
        logDate: day,
        name: 'Snack',
        macros: const Macros(calories: 90),
      );
      await log.moveEntry(entryId, target);
      expect((await db.logDao.findEntry(entryId))!.logDate, target);
      expect(await db.logDao.findEntriesForDate(day), isEmpty);
    });

    test('a malformed date key throws FormatException', () async {
      final entryId = await log.logAdhoc(
        logDate: day,
        name: 'Snack',
        macros: const Macros(calories: 90),
      );
      await expectLater(
        log.moveEntry(entryId, '21-10-2026'),
        throwsFormatException,
      );
      await expectLater(
        log.moveEntry(entryId, '2026-02-30'),
        throwsFormatException,
      );
      expect((await db.logDao.findEntry(entryId))!.logDate, day);
    });

    test('a missing entry throws StateError', () async {
      await expectLater(
        log.moveEntry('no-such-entry', target),
        throwsStateError,
      );
    });
  });
}
