import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late String oatsId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed() async {
    final catalog = CatalogRepository(db);
    oatsId = await catalog.createFood(
      name: 'Rolled oats',
      brand: 'Acme',
      perServing: const Macros(calories: 150, protein: 5, carbs: 27, fat: 3),
      servingWeightG: 40,
      barcode: '4006381333931',
    );
    await catalog.createFood(
      name: 'Banana',
      perServing: const Macros(
        calories: 105,
        protein: 1.3,
        carbs: 27,
        fat: 0.4,
      ),
      servingWeightG: 118,
    );
  }

  /// Tall enough for the whole food form.
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openCatalog(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('Catalog'),
      ),
    );
    await settle(tester);
  }

  Future<FoodItem> foodNamed(WidgetTester tester, String name) async =>
      (await tester.runAsync(
        () => (db.select(
          db.foodItems,
        )..where((t) => t.name.equals(name))).getSingle(),
      ))!;

  testWidgets('the brand shows in the list, is searchable and editable', (
    tester,
  ) async {
    tallView(tester);
    await tester.runAsync(seed);
    await openCatalog(tester);

    expect(find.text('Acme · 150 kcal per 40 g'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('catalog-search')), 'acme');
    await settle(tester);
    expect(find.text('Rolled oats'), findsOneWidget);
    expect(find.text('Banana'), findsNothing);

    await tester.tap(find.text('Rolled oats'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('food-brand')), '  Oatco ');
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    expect((await foodNamed(tester, 'Rolled oats')).brand, 'Oatco');
    await unmount(tester);
  });

  testWidgets('the star marks a favorite, which Add Food pins and logs', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await openCatalog(tester);

    await tester.tap(find.byKey(Key('favorite-food-$oatsId')));
    await settle(tester);
    expect((await foodNamed(tester, 'Rolled oats')).favorite, isTrue);

    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('Today'),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);

    expect(find.byKey(const Key('favorite-sources')), findsOneWidget);
    await tester.tap(find.byKey(Key('pinned-food-$oatsId')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('log-food-confirm')));
    await settle(tester);

    final entries = await tester.runAsync(
      () => db.logDao.watchEntriesForDate(todayKey()).first,
    );
    expect(entries!.single.name, 'Rolled oats');
    await unmount(tester);
  });

  testWidgets('a food with no favorites shows no Favorites strip', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    expect(find.byKey(const Key('favorite-sources')), findsNothing);
    await unmount(tester);
  });

  testWidgets('Duplicate copies a food into a new one, without its barcode', (
    tester,
  ) async {
    tallView(tester);
    await tester.runAsync(seed);
    await openCatalog(tester);
    await tester.tap(find.text('Rolled oats'));
    await settle(tester);

    await tester.tap(find.byKey(const Key('food-duplicate')));
    await settle(tester);
    expect(find.text('New Food'), findsOneWidget);
    final name = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('food-name')),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.controller.text, 'Rolled oats copy');

    await tester.enterText(find.byKey(const Key('food-name')), 'Oats, large');
    await tester.enterText(find.byKey(const Key('food-serving-weight')), '80');
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    final copy = await foodNamed(tester, 'Oats, large');
    expect(copy.id, isNot(oatsId));
    expect(copy.brand, 'Acme');
    expect(copy.calories, 150);
    expect(copy.servingWeightG, 80);
    expect(copy.barcode, isNull);
    expect(copy.favorite, isFalse);
    // The original is unchanged, and the list is back on screen.
    expect((await foodNamed(tester, 'Rolled oats')).servingWeightG, 40);
    expect(find.text('Catalog'), findsWidgets);
    await unmount(tester);
  });
}
