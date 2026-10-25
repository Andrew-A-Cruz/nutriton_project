import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/meal_slot.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';

/// Planned foods, slots and servings (M17), on top of the scheduling tests in
/// schedule_repository_test.dart.
void main() {
  late AppDatabase db;
  late ScheduleRepository repo;
  late CatalogRepository catalog;
  late String foodId;
  late String mealId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    catalog = CatalogRepository(db);
    foodId = await catalog.createFood(
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

  group('a planned food', () {
    test('is pending as a food and logs with its servings and slot', () async {
      final id = await repo.scheduleOnce(
        foodItemId: foodId,
        date: '2026-10-21',
        mealSlot: MealSlot.dinner,
        servings: 2,
      );
      final item = (await pending('2026-10-21')).single;
      expect(item.food?.name, 'Rice');
      expect(item.meal, isNull);
      expect(item.name, 'Rice');
      expect(item.schedule.servings, 2);

      final entryId = await repo.confirm(id, date: '2026-10-21');

      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.entryType, 'food');
      expect(entry.foodItemId, foodId);
      expect(entry.servings, 2);
      expect(entry.calories, closeTo(260, 1e-9));
      expect(entry.mealSlot, 'dinner');
      expect(entry.logDate, '2026-10-21');
      expect(await pending('2026-10-21'), isEmpty);
      final outcome = (await db.scheduledMealDao.findOutcomes(id)).single;
      expect((outcome.status, outcome.entryId), ('logged', entryId));
    });

    test('without a slot is filed by the time of day when logged', () async {
      final id = await repo.scheduleOnce(
        foodItemId: foodId,
        date: '2026-10-21',
      );
      final before = MealSlot.forTime(DateTime.now());
      final entryId = await repo.confirm(id, date: '2026-10-21');
      final after = MealSlot.forTime(DateTime.now());

      final slot = (await db.logDao.findEntry(entryId))!.mealSlot;
      expect([before.name, after.name], contains(slot));
      expect(
        ScheduleRepository.slotOf(
          item(slotName: null),
          DateTime(2026, 1, 1, 8),
        ),
        MealSlot.breakfast,
      );
      expect(
        ScheduleRepository.slotOf(
          item(slotName: 'snack'),
          DateTime(2026, 1, 1, 8),
        ),
        MealSlot.snack,
      );
    });

    test('a repeating food plan comes back each due day', () async {
      final id = await repo.scheduleWeekdays(
        foodItemId: foodId,
        startDate: '2026-10-19',
        weekdays: {1, 3},
      );
      await repo.confirm(id, date: '2026-10-19');
      expect(await pending('2026-10-19'), isEmpty);
      expect(await pending('2026-10-21'), hasLength(1));
      expect(await db.logDao.findEntriesForDate('2026-10-21'), isEmpty);
    });

    test('is hidden while the food is archived', () async {
      await repo.scheduleOnce(foodItemId: foodId, date: '2026-10-21');
      await catalog.setFoodArchived(foodId, archived: true);
      expect(await pending('2026-10-21'), isEmpty);
      await catalog.setFoodArchived(foodId, archived: false);
      expect(await pending('2026-10-21'), hasLength(1));
    });
  });

  group('a planned meal', () {
    test('scales the item weights by servings and uses its slot', () async {
      final id = await repo.scheduleOnce(
        mealId: mealId,
        date: '2026-10-21',
        mealSlot: MealSlot.snack,
        servings: 1.5,
      );
      final entryId = await repo.confirm(id, date: '2026-10-21');

      final entry = (await db.logDao.findEntry(entryId))!;
      expect(entry.entryType, 'meal');
      expect(entry.calories, closeTo(390, 1e-9)); // 200 g x 1.5 of 130/100 g
      expect(entry.mealSlot, 'snack');
      final items = await db.logDao.findEntryItems(entryId);
      expect(items.single.weightG, closeTo(300, 1e-9));
    });

    test('is hidden while the meal is archived', () async {
      await repo.scheduleOnce(mealId: mealId, date: '2026-10-21');
      await catalog.setMealArchived(mealId, archived: true);
      expect(await pending('2026-10-21'), isEmpty);
    });
  });

  group('which days a plan shows on', () {
    test(
      'a weekday plan matches its weekdays from the start date on',
      () async {
        await repo.scheduleWeekdays(
          foodItemId: foodId,
          startDate: '2026-10-19', // a Monday
          weekdays: {1, 3, 7},
        );
        expect(await pending('2026-10-12'), isEmpty); // Mon before the start
        expect(await pending('2026-10-19'), hasLength(1)); // Mon
        expect(await pending('2026-10-20'), isEmpty); // Tue
        expect(await pending('2026-10-21'), hasLength(1)); // Wed
        expect(await pending('2026-10-25'), hasLength(1)); // Sun
        expect(await pending('2026-10-26'), hasLength(1)); // next Mon
      },
    );

    test('a one-off shows on its date only', () async {
      await repo.scheduleOnce(foodItemId: foodId, date: '2026-10-21');
      expect(await pending('2026-10-20'), isEmpty);
      expect(await pending('2026-10-21'), hasLength(1));
      expect(await pending('2026-10-28'), isEmpty);
    });

    test('a skipped plan is gone for that day only', () async {
      final id = await repo.scheduleWeekdays(
        foodItemId: foodId,
        startDate: '2026-10-19',
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      );
      await repo.dismiss(id, date: '2026-10-21');
      expect(await pending('2026-10-21'), isEmpty);
      expect(await pending('2026-10-22'), hasLength(1));
      expect(await db.logDao.findEntriesForDate('2026-10-21'), isEmpty);
      final outcome = (await db.scheduledMealDao.findOutcomes(id)).single;
      expect((outcome.status, outcome.date), ('dismissed', '2026-10-21'));
    });

    test('a confirmed plan is gone for that day only', () async {
      final id = await repo.scheduleWeekdays(
        mealId: mealId,
        startDate: '2026-10-19',
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      );
      await repo.confirm(id, date: '2026-10-21');
      expect(await pending('2026-10-21'), isEmpty);
      expect(await pending('2026-10-22'), hasLength(1));
    });
  });

  group('creating a plan', () {
    test('needs exactly one of a meal and a food', () async {
      await expectLater(
        repo.scheduleOnce(date: '2026-10-21'),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repo.scheduleOnce(
          mealId: mealId,
          foodItemId: foodId,
          date: '2026-10-21',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects unknown sources and bad servings', () async {
      await expectLater(
        repo.scheduleOnce(foodItemId: 'nope', date: '2026-10-21'),
        throwsA(isA<StateError>()),
      );
      for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          repo.scheduleOnce(
            foodItemId: foodId,
            date: '2026-10-21',
            servings: bad,
          ),
          throwsA(isA<ArgumentError>()),
          reason: '$bad',
        );
      }
    });
  });

  group('the table rules', () {
    Future<void> insert({
      String? meal,
      String? food,
      String? slot,
      double? servings,
    }) => db.scheduledMealDao.insertSchedule(
      ScheduledMealsCompanion.insert(
        id: 'x',
        mealId: Value(meal),
        foodItemId: Value(food),
        mealSlot: Value(slot),
        servings: servings == null ? const Value.absent() : Value(servings),
        startDate: '2026-10-21',
        createdAt: DateTime(2026, 10, 20),
      ),
    );

    test('one source is accepted, with servings defaulting to 1', () async {
      await insert(food: foodId);
      final plan = (await db.scheduledMealDao.findSchedule('x'))!;
      expect((plan.servings, plan.mealSlot, plan.mealId), (1.0, null, null));
    });

    test('both sources or neither are rejected', () async {
      await expectLater(
        insert(meal: mealId, food: foodId),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(insert(), throwsA(isA<SqliteException>()));
    });

    test('a bad slot or non-positive servings are rejected', () async {
      await expectLater(
        insert(food: foodId, slot: 'brunch'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        insert(food: foodId, servings: 0),
        throwsA(isA<SqliteException>()),
      );
    });

    test('deleting the food deletes its plans and their outcomes', () async {
      final other = await catalog.createFood(
        name: 'Oats',
        perServing: const Macros(calories: 70, protein: 2, carbs: 12, fat: 1),
        servingWeightG: 30,
      );
      final id = await repo.scheduleOnce(foodItemId: other, date: '2026-10-21');
      await repo.dismiss(id, date: '2026-10-21');
      await (db.delete(db.foodItems)..where((t) => t.id.equals(other))).go();
      expect(await db.scheduledMealDao.findSchedule(id), isNull);
      expect(await db.scheduledMealDao.findOutcomes(id), isEmpty);
    });
  });
}

/// A plan row with only the slot filled in, for [ScheduleRepository.slotOf].
ScheduledMeal item({required String? slotName}) => ScheduledMeal(
  id: 'p',
  mealId: null,
  foodItemId: 'f',
  startDate: '2026-10-21',
  weekdays: null,
  mealSlot: slotName,
  servings: 1,
  createdAt: DateTime(2026, 10, 20),
);
