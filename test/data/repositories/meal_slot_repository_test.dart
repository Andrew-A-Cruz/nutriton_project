import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/meal_slot.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late CatalogRepository catalog;
  late LogRepository log;
  late FoodItem rice;
  late Meal meal;

  const day = '2026-10-20';
  const other = '2026-10-21';
  const macros = Macros(calories: 90, protein: 1, carbs: 15, fat: 3);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
    log = LogRepository(db);
    final riceId = await catalog.createFood(
      name: 'Rice',
      perServing: const Macros(calories: 130, protein: 3, carbs: 28, fat: 0.3),
      servingWeightG: 100,
    );
    rice = (await catalog.findFood(riceId))!;
    final mealId = await catalog.createMeal(
      name: 'Bowl',
      items: [MealItemInput(foodItemId: riceId, weightG: 200)],
    );
    meal = (await catalog.findMeal(mealId))!;
  });

  tearDown(() async {
    await db.close();
  });

  Future<String?> slotOf(String id) async =>
      (await db.logDao.findEntry(id))!.mealSlot;

  Future<String> logMeal({MealSlot? slot}) => log.logMeal(
    logDate: day,
    meal: meal,
    items: [MealItemInput(foodItemId: rice.id, weightG: 150)],
    mealSlot: slot,
  );

  test('each log method stores the slot, or null when none is given', () async {
    final food = await log.logFood(
      logDate: day,
      food: rice,
      servings: 1,
      mealSlot: MealSlot.breakfast,
    );
    final adhoc = await log.logAdhoc(
      logDate: day,
      name: 'Cookie',
      macros: macros,
      mealSlot: MealSlot.snack,
    );
    final mealId = await logMeal(slot: MealSlot.dinner);
    expect(await slotOf(food), 'breakfast');
    expect(await slotOf(adhoc), 'snack');
    expect(await slotOf(mealId), 'dinner');

    final none = await log.logFood(logDate: day, food: rice, servings: 1);
    expect(await slotOf(none), isNull);
  });

  test('duplicateEntry and copyDay keep the slot', () async {
    final food = await log.logFood(
      logDate: day,
      food: rice,
      servings: 1,
      mealSlot: MealSlot.lunch,
    );
    await log.logAdhoc(logDate: day, name: 'Cookie', macros: macros);
    await logMeal(slot: MealSlot.dinner);

    final copy = await log.duplicateEntry(food, other);
    expect(await slotOf(copy), 'lunch');

    await log.copyDay(fromDate: day, toDate: '2026-10-22');
    final copied = await db.logDao.findEntriesForDate('2026-10-22');
    expect(
      copied.map((e) => e.mealSlot),
      unorderedEquals(['lunch', null, 'dinner']),
    );
  });

  test('restoreEntry after a delete keeps the slot', () async {
    final id = await logMeal(slot: MealSlot.dinner);
    final deleted = await log.deleteEntryForUndo(id);
    expect(await db.logDao.findEntry(id), isNull);
    await log.restoreEntry(deleted!);
    expect(await slotOf(id), 'dinner');
  });

  test('updateMealSlot sets, changes and rejects unknown entries', () async {
    final id = await log.logFood(logDate: day, food: rice, servings: 1);
    await log.updateMealSlot(id, MealSlot.snack);
    expect(await slotOf(id), 'snack');
    await log.updateMealSlot(id, MealSlot.breakfast);
    expect(await slotOf(id), 'breakfast');
    await expectLater(
      log.updateMealSlot('nope', MealSlot.lunch),
      throwsStateError,
    );
  });

  test('editing servings or a one-off entry leaves the slot alone', () async {
    final food = await log.logFood(
      logDate: day,
      food: rice,
      servings: 1,
      mealSlot: MealSlot.lunch,
    );
    await log.updateServings(food, servings: 2);
    expect(await slotOf(food), 'lunch');
    final adhoc = await log.logAdhoc(
      logDate: day,
      name: 'Cookie',
      macros: macros,
      mealSlot: MealSlot.snack,
    );
    await log.updateAdhoc(adhoc, name: 'Big cookie', macros: macros);
    expect(await slotOf(adhoc), 'snack');
  });

  test('confirming a plan logs it in a slot for the time of day', () async {
    final schedule = ScheduleRepository(db);
    final planId = await schedule.scheduleOnce(mealId: meal.id, date: day);
    await schedule.confirm(planId, date: day);
    final entry = (await db.logDao.findEntriesForDate(day)).single;
    expect(MealSlot.fromName(entry.mealSlot), isNotNull);
  });

  test('the database refuses an unknown slot', () async {
    final id = await log.logFood(logDate: day, food: rice, servings: 1);
    await expectLater(
      db.logDao.updateEntry(
        id,
        const FoodLogEntriesCompanion(mealSlot: Value('brunch')),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
