import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

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

  /// Three active foods and one archived food.
  Future<void> seedFoods() async {
    final catalog = CatalogRepository(db);
    await catalog.createFood(
      name: 'White rice',
      perServing: const Macros(
        calories: 130,
        protein: 2.7,
        carbs: 28,
        fat: 0.3,
      ),
      servingWeightG: 100,
    );
    await catalog.createFood(
      name: 'Chicken breast',
      perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
      servingWeightG: 100,
    );
    await catalog.createFood(
      name: 'Chickpeas',
      perServing: const Macros(calories: 120, protein: 6, carbs: 18, fat: 2),
      servingWeightG: 100,
    );
    final old = await catalog.createFood(
      name: 'Old yogurt',
      perServing: const Macros(calories: 90, protein: 9, carbs: 7, fat: 2),
      servingWeightG: 170,
    );
    await catalog.setFoodArchived(old, archived: true);
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

  testWidgets('lists active foods by name with calories per serving', (
    tester,
  ) async {
    await tester.runAsync(seedFoods);
    await openCatalog(tester);

    expect(find.text('Chicken breast'), findsOneWidget);
    expect(find.text('165 kcal per 100 g'), findsOneWidget);
    expect(find.text('White rice'), findsOneWidget);
    expect(find.text('Chickpeas'), findsOneWidget);
    // Archived foods leave the list.
    expect(find.text('Old yogurt'), findsNothing);
    await unmount(tester);
  });

  testWidgets('search narrows the list and says when nothing matches', (
    tester,
  ) async {
    await tester.runAsync(seedFoods);
    await openCatalog(tester);

    await tester.enterText(find.byKey(const Key('catalog-search')), 'chi');
    await settle(tester);
    expect(find.text('Chicken breast'), findsOneWidget);
    expect(find.text('Chickpeas'), findsOneWidget);
    expect(find.text('White rice'), findsNothing);

    await tester.enterText(find.byKey(const Key('catalog-search')), 'xyz');
    await settle(tester);
    expect(find.text('No foods match "xyz".'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an empty catalog says how to add a food', (tester) async {
    await openCatalog(tester);

    expect(find.text('No foods yet. Tap + to add one.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'swiping a food archives it: it leaves the list and the db keeps it',
    (tester) async {
      await tester.runAsync(seedFoods);
      await openCatalog(tester);

      await tester.drag(find.text('White rice'), const Offset(-500, 0));
      await tester.pump();
      await settle(tester);
      await settle(tester);

      expect(find.text('White rice'), findsNothing);
      expect(find.text('Chicken breast'), findsOneWidget);
      final active = await tester.runAsync(() => db.foodDao.findActive());
      expect(active!.map((f) => f.name), ['Chicken breast', 'Chickpeas']);
      // The row still exists, archived, so past log entries keep their link.
      final rows = await tester.runAsync(
        () => db
            .customSelect(
              "SELECT archived FROM food_items WHERE name = 'White rice'",
            )
            .get(),
      );
      expect(rows!.single.read<int>('archived'), 1);
      await unmount(tester);
    },
  );
}
