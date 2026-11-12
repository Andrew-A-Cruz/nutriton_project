import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/menus.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';

import '../../support/menu_fixture.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  final menus = parseMenus(menuFixture());
  // The next release: the fries changed.
  final newer = parseMenus(menuFixture(version: 2, friesCalories: 350));
  final fries = menus.itemById('example-burger/fries-medium')!;
  final cola = menus.itemById('example-burger/cola-medium')!;
  final lemonade = menus.itemById('sample-chicken/lemonade-large')!;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<FoodItem>> foods() => db.select(db.foodItems).get();

  Future<void> edit(FoodItem food, {required double calories}) =>
      catalog.updateFood(
        food.id,
        name: food.name,
        perServing: Macros(
          calories: calories,
          protein: food.protein,
          carbs: food.carbs,
          fat: food.fat,
        ),
        servingWeightG: food.servingWeightG,
        brand: food.brand,
      );

  group('adoptMenuItem', () {
    test('the first use copies the item in, with the chain as brand', () async {
      final food = await catalog.adoptMenuItem(fries, version: 1);

      expect(food.name, 'French Fries, Medium');
      expect(food.brand, 'Example Burger');
      expect(food.servingWeightG, 114);
      expect(food.calories, 320);
      expect(food.protein, 5);
      expect(food.carbs, 43);
      expect(food.fat, 15);
      expect(food.fiber, 4);
      expect(food.sugar, 0);
      expect(food.sodium, 260);
      expect(food.menuItemId, 'example-burger/fries-medium');
      expect(food.menuVersion, 1);
      expect(food.archived, isFalse);
      expect(await foods(), hasLength(1));
    });

    test('nutrients the chain does not publish stay unrecorded', () async {
      final food = await catalog.adoptMenuItem(cola, version: 1);
      expect(food.fiber, isNull);
      expect(food.sugar, isNull);
      expect(food.sodium, isNull);
    });

    test('an item with no published weight is counted in items', () async {
      final food = await catalog.adoptMenuItem(lemonade, version: 1);
      expect(food.weightUnknown, isTrue);
      expect(food.servingWeightG, unknownServingWeightG);
      expect(food.calories, 250);
      // An item with a weight is not.
      expect(
        (await catalog.adoptMenuItem(fries, version: 1)).weightUnknown,
        isFalse,
      );
    });

    test('a second use returns the same food and makes nothing', () async {
      final first = await catalog.adoptMenuItem(fries, version: 1);
      final second = await catalog.adoptMenuItem(fries, version: 1);

      expect(second.id, first.id);
      expect(await foods(), hasLength(1));
    });

    test('an edited copy is returned as it is', () async {
      final first = await catalog.adoptMenuItem(fries, version: 1);
      await edit(first, calories: 400);

      final again = await catalog.adoptMenuItem(fries, version: 2);
      expect(again.id, first.id);
      expect(again.calories, 400);
      expect(again.menuVersion, isNull);
      expect(await foods(), hasLength(1));
    });

    test('an archived copy is brought back, not duplicated', () async {
      final first = await catalog.adoptMenuItem(fries, version: 1);
      await catalog.setFoodArchived(first.id, archived: true);

      final again = await catalog.adoptMenuItem(fries, version: 1);
      expect(again.id, first.id);
      expect(again.archived, isFalse);
      expect(await foods(), hasLength(1));
    });

    test('the food is found by searching for the chain', () async {
      await catalog.adoptMenuItem(fries, version: 1);
      final found = await catalog.findFoods(search: 'example');
      expect(found.single.name, 'French Fries, Medium');
    });
  });

  group('editing', () {
    test('saving the form clears the version and keeps the link', () async {
      final food = await catalog.adoptMenuItem(fries, version: 1);
      await edit(food, calories: 400);

      final saved = (await catalog.findFood(food.id))!;
      expect(saved.menuVersion, isNull);
      expect(saved.menuItemId, 'example-burger/fries-medium');
    });

    test('saving without a weight keeps the food counted in items', () async {
      final food = await catalog.adoptMenuItem(lemonade, version: 1);
      await edit(food, calories: 260);

      final saved = (await catalog.findFood(food.id))!;
      expect(saved.calories, 260);
      expect(saved.weightUnknown, isTrue);
    });

    test('saving with a weight gives the food one', () async {
      final food = await catalog.adoptMenuItem(lemonade, version: 1);
      await catalog.updateFood(
        food.id,
        name: food.name,
        perServing: const Macros(calories: 250, carbs: 64),
        servingWeightG: 650,
      );

      final saved = (await catalog.findFood(food.id))!;
      expect(saved.weightUnknown, isFalse);
      expect(saved.servingWeightG, 650);
      // And it stays that way on later saves.
      await edit(saved, calories: 240);
      expect((await catalog.findFood(food.id))!.weightUnknown, isFalse);
    });

    test('starring and archiving do not count as edits', () async {
      final food = await catalog.adoptMenuItem(fries, version: 1);
      await catalog.setFoodFavorite(food.id, favorite: true);
      await catalog.setFoodArchived(food.id, archived: true);
      await catalog.setFoodArchived(food.id, archived: false);

      final saved = (await catalog.findFood(food.id))!;
      expect(saved.favorite, isTrue);
      expect(saved.menuVersion, 1);
    });

    test('a food made in the form has no menu columns', () async {
      final id = await catalog.createFood(
        name: 'French Fries, Medium',
        perServing: const Macros(calories: 320),
        servingWeightG: 114,
        brand: 'Example Burger',
      );
      final food = (await catalog.findFood(id))!;
      expect(food.menuItemId, isNull);
      expect(food.menuVersion, isNull);
    });
  });

  group('refreshMenuFoods', () {
    test('updates an unedited food to the newer file', () async {
      final food = await catalog.adoptMenuItem(fries, version: 1);
      await catalog.setFoodFavorite(food.id, favorite: true);

      expect(await catalog.refreshMenuFoods(newer), 1);

      final refreshed = (await catalog.findFood(food.id))!;
      expect(refreshed.calories, 350);
      expect(refreshed.menuVersion, 2);
      expect(refreshed.brand, 'Example Burger');
      expect(refreshed.favorite, isTrue);
      // Nothing left to do the second time.
      expect(await catalog.refreshMenuFoods(newer), 0);
    });

    test('follows an item that gains or loses its weight', () async {
      // The newer file's fries have a weight; this copy was made without.
      await db.foodDao.insertFood(
        FoodItemsCompanion.insert(
          id: 'unweighed',
          name: 'French Fries, Medium',
          calories: 320,
          protein: 5,
          carbs: 43,
          fat: 15,
          servingWeightG: unknownServingWeightG,
          weightUnknown: const Value(true),
          menuItemId: const Value('example-burger/fries-medium'),
          menuVersion: const Value(1),
        ),
      );
      final weighed = await catalog.adoptMenuItem(lemonade, version: 1);
      await db.foodDao.updateFood(
        weighed.id,
        const FoodItemsCompanion(
          servingWeightG: Value(600),
          weightUnknown: Value(false),
        ),
      );

      expect(await catalog.refreshMenuFoods(newer), 2);
      final fries = (await catalog.findFood('unweighed'))!;
      expect(fries.weightUnknown, isFalse);
      expect(fries.servingWeightG, 114);
      final drink = (await catalog.findFood(weighed.id))!;
      expect(drink.weightUnknown, isTrue);
      expect(drink.servingWeightG, unknownServingWeightG);
    });

    test('does nothing when the file is the same version', () async {
      await catalog.adoptMenuItem(fries, version: 1);
      expect(await catalog.refreshMenuFoods(menus), 0);
    });

    test('leaves an edited food alone', () async {
      final food = await catalog.adoptMenuItem(fries, version: 1);
      await edit(food, calories: 400);

      expect(await catalog.refreshMenuFoods(newer), 0);
      expect((await catalog.findFood(food.id))!.calories, 400);
    });

    test('leaves a food whose item has left the file alone', () async {
      const gone = MenuItem(
        id: 'example-burger/retired',
        chainId: 'example-burger',
        chainName: 'Example Burger',
        name: 'Retired Burger',
        category: 'Burgers',
        perItem: Macros(calories: 500, protein: 20, carbs: 40, fat: 28),
        servingWeightG: 200,
      );
      final food = await catalog.adoptMenuItem(gone, version: 1);

      expect(await catalog.refreshMenuFoods(newer), 0);
      final after = (await catalog.findFood(food.id))!;
      expect(after.calories, 500);
      expect(after.menuVersion, 1);
    });

    test('does not touch other foods or past log entries', () async {
      final ownId = await catalog.createFood(
        name: 'French Fries, Medium',
        perServing: const Macros(calories: 111),
        servingWeightG: 114,
      );
      final food = await catalog.adoptMenuItem(fries, version: 1);
      await LogRepository(
        db,
      ).logFood(logDate: todayKey(), food: food, servings: 1);

      expect(await catalog.refreshMenuFoods(newer), 1);

      expect((await catalog.findFood(ownId))!.calories, 111);
      final entry = (await db.select(db.foodLogEntries).get()).single;
      expect(entry.calories, 320);
    });

    test('brings a restored older food up to the current file', () async {
      // As a backup made before the new release would restore it.
      await db.foodDao.insertFood(
        FoodItemsCompanion.insert(
          id: 'restored',
          name: 'Old name',
          calories: 300,
          protein: 5,
          carbs: 43,
          fat: 15,
          servingWeightG: 110,
          menuItemId: const Value('example-burger/fries-medium'),
          menuVersion: const Value(1),
        ),
      );

      expect(await catalog.refreshMenuFoods(newer), 1);
      final food = (await catalog.findFood('restored'))!;
      expect(food.name, 'French Fries, Medium');
      expect(food.calories, 350);
      expect(food.servingWeightG, 114);
      expect(food.menuVersion, 2);
    });
  });
}
