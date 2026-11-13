import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/shortcuts/shortcut_logger.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late ShortcutLogger logger;
  final now = DateTime(2026, 11, 12, 8, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
    logger = ShortcutLogger(db);
  });

  tearDown(() => db.close());

  Future<String> oats() => catalog.createFood(
    name: 'Oats',
    perServing: const Macros(calories: 150, protein: 5, carbs: 27, fat: 3),
    servingWeightG: 40,
  );

  Future<List<FoodLogEntry>> entries() => db.select(db.foodLogEntries).get();

  test('logs a saved meal as saved, today, in the slot for the time', () async {
    final food = await oats();
    final meal = await catalog.createMeal(
      name: 'Breakfast bowl',
      items: [MealItemInput(foodItemId: food, weightG: 80)],
    );

    final name = await logger.log((itemId: 'meal:$meal', at: now), now: now);

    expect(name, 'Breakfast bowl');
    final entry = (await entries()).single;
    expect(entry.entryType, 'meal');
    expect(entry.logDate, '2026-11-12');
    expect(entry.mealSlot, 'breakfast');
    expect(entry.calories, 300);
  });

  test('logs a food at the servings last logged', () async {
    final food = await oats();
    await LogRepository(db).logFood(
      logDate: '2026-11-11',
      food: (await catalog.findFood(food))!,
      servings: 2,
    );

    final at = DateTime(2026, 11, 12, 13);
    expect(await logger.log((itemId: 'food:$food', at: at), now: at), 'Oats');
    final entry = (await entries()).firstWhere(
      (e) => e.logDate == '2026-11-12',
    );
    expect(entry.servings, 2);
    expect(entry.mealSlot, 'lunch');
  });

  test('a food never logged is one serving', () async {
    final food = await oats();
    await logger.log((itemId: 'food:$food', at: now), now: now);
    expect((await entries()).single.servings, 1);
  });

  test('an old request logs nothing', () async {
    final food = await oats();
    final asked = now.subtract(const Duration(minutes: 11));
    expect(
      await logger.log((itemId: 'food:$food', at: asked), now: now),
      isNull,
    );
    expect(await entries(), isEmpty);
  });

  test('a deleted, archived or unknown item logs nothing', () async {
    final food = await oats();
    await catalog.setFoodArchived(food, archived: true);
    for (final id in ['food:$food', 'food:gone', 'meal:gone', 'nonsense']) {
      expect(await logger.log((itemId: id, at: now), now: now), isNull);
    }
    expect(await entries(), isEmpty);
  });

  test('a recipe logs nothing, as it needs a portion', () async {
    final food = await oats();
    final recipe = await catalog.createMeal(
      name: 'Granola',
      items: [MealItemInput(foodItemId: food, weightG: 400)],
      cookedWeightG: 350,
    );
    expect(
      await logger.log((itemId: 'meal:$recipe', at: now), now: now),
      isNull,
    );
  });
}
