import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepository repo;
  late String mealId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    final catalog = CatalogRepository(db);
    final foodId = await catalog.createFood(
      name: 'Rice',
      perServing: const Macros(calories: 130, protein: 3, carbs: 28, fat: 0.3),
      servingWeightG: 100,
    );
    mealId = await catalog.createMeal(
      name: 'Lunch',
      items: [MealItemInput(foodItemId: foodId, weightG: 200)],
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<PendingScheduledMeal>> pending(String date) =>
      repo.watchPendingForDate(date).first;

  test('confirm logs the meal snapshot and hides the suggestion', () async {
    final id = await repo.scheduleOnce(mealId: mealId, date: '2026-10-21');
    expect((await pending('2026-10-21')).single.name, 'Lunch');

    final entryId = await repo.confirm(id, date: '2026-10-21');

    final entries = await db.logDao.findEntriesForDate('2026-10-21');
    expect(entries.single.id, entryId);
    expect(entries.single.entryType, 'meal');
    expect(entries.single.mealId, mealId);
    expect(entries.single.calories, closeTo(260, 1e-9));
    expect(await db.logDao.findEntryItems(entryId), hasLength(1));
    expect(await pending('2026-10-21'), isEmpty);
    final outcome = (await db.scheduledMealDao.findOutcomes(id)).single;
    expect(outcome.status, 'logged');
    expect(outcome.entryId, entryId);

    // Confirming twice would double-log.
    await expectLater(
      repo.confirm(id, date: '2026-10-21'),
      throwsA(isA<StateError>()),
    );
    expect(await db.logDao.findEntriesForDate('2026-10-21'), hasLength(1));
  });

  test('a repeating plan is confirmed per day', () async {
    final id = await repo.scheduleWeekdays(
      mealId: mealId,
      startDate: '2026-10-19',
      weekdays: {1, 2, 3, 4, 5},
    );
    await repo.confirm(id, date: '2026-10-21');
    expect(await pending('2026-10-21'), isEmpty);
    expect(await pending('2026-10-22'), hasLength(1));
    // Not due on a Saturday.
    await expectLater(
      repo.confirm(id, date: '2026-10-24'),
      throwsA(isA<StateError>()),
    );
  });

  test('dismiss hides one day and logs nothing', () async {
    final id = await repo.scheduleWeekdays(
      mealId: mealId,
      startDate: '2026-10-19',
      weekdays: {1, 2, 3, 4, 5},
    );
    await repo.dismiss(id, date: '2026-10-21');
    expect(await pending('2026-10-21'), isEmpty);
    expect(await pending('2026-10-22'), hasLength(1));
    expect(await db.logDao.findEntriesForDate('2026-10-21'), isEmpty);
  });

  test('removeSchedule stops a repeating plan', () async {
    final id = await repo.scheduleWeekdays(
      mealId: mealId,
      startDate: '2026-10-19',
      weekdays: {1},
    );
    await repo.removeSchedule(id);
    expect(await pending('2026-10-26'), isEmpty);
  });

  test('confirming a meal with no items fails and rolls back', () async {
    await db.mealDao.insertMeal(
      MealsCompanion.insert(id: 'empty-meal', name: 'Empty'),
    );
    final id = await repo.scheduleOnce(
      mealId: 'empty-meal',
      date: '2026-10-21',
    );
    await expectLater(
      repo.confirm(id, date: '2026-10-21'),
      throwsA(isA<ArgumentError>()),
    );
    expect(await pending('2026-10-21'), hasLength(1));
    expect(await db.scheduledMealDao.findOutcomes(id), isEmpty);
  });

  test('validation', () async {
    await expectLater(
      repo.scheduleOnce(mealId: 'nope', date: '2026-10-21'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      repo.scheduleOnce(mealId: mealId, date: '10/21/2026'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      repo.scheduleWeekdays(
        mealId: mealId,
        startDate: '2026-10-21',
        weekdays: {},
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repo.scheduleWeekdays(
        mealId: mealId,
        startDate: '2026-10-21',
        weekdays: {9},
      ),
      throwsA(isA<RangeError>()),
    );
  });
}
