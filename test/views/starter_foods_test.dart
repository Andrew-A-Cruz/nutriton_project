import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/providers/catalog_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

const _foods =
    'Bananas, raw\t89\t1.1\t22.8\t0.3\t2.6\t12.2\t1\tsmall=101\n'
    'Bananas, dehydrated\t346\t3.9\t88.3\t1.8\t9.9\t47.3\t3\t\n'
    'Rice, white, cooked\t130\t2.7\t28.2\t0.3\t0.4\t0.1\t1\tcup=158\n';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories'],
      'goal_calories': 2000.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openAddFood(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [
          genericFoodsSourceProvider.overrideWithValue(() async => _foods),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('catalog-search')), text);
    await settle(tester);
  }

  final header = find.byKey(const Key('bundled-foods-header'));

  testWidgets('starter foods show only while searching foods', (tester) async {
    await openAddFood(tester);
    expect(header, findsNothing);

    await search(tester, 'banana');
    expect(header, findsOneWidget);
    expect(find.text('Bananas, raw'), findsOneWidget);
    expect(find.text('Bananas, dehydrated'), findsOneWidget);
    expect(find.text('89 kcal per 100 g'), findsOneWidget);
    expect(find.text('Rice, white, cooked'), findsNothing);
    // With no catalog food matching, there is no "no foods" message.
    expect(find.textContaining('No foods match'), findsNothing);

    await tester.tap(find.text('Meals'));
    await settle(tester);
    expect(header, findsNothing);
    await unmount(tester);
  });

  testWidgets('a search that matches nothing still says so', (tester) async {
    await openAddFood(tester);
    await search(tester, 'zzz');
    expect(header, findsNothing);
    expect(find.text('No foods match "zzz".'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tapping one copies it to the catalog and logs it', (
    tester,
  ) async {
    await openAddFood(tester);
    await search(tester, 'banana raw');

    await tester.tap(find.byKey(const Key('bundled-food-0')));
    await settle(tester);

    // The servings screen for the new catalog food, with its portion.
    final food = (await db.select(db.foodItems).get()).single;
    expect(food.name, 'Bananas, raw');
    expect(food.servingWeightG, 100);
    expect(find.textContaining('small'), findsOneWidget);

    await tester.tap(find.byKey(const Key('log-food-confirm')));
    await settle(tester);

    final entry = (await db.select(db.foodLogEntries).get()).single;
    expect(entry.name, 'Bananas, raw');
    expect(entry.calories, 89);
    expect(entry.foodItemId, food.id);
    expect(entry.logDate, todayKey());
    await unmount(tester);
  });

  testWidgets('a food already copied shows once, as a catalog food', (
    tester,
  ) async {
    await tester.runAsync(
      () => CatalogRepository(db).createFood(
        name: 'Bananas, raw',
        perServing: const Macros(calories: 89),
        servingWeightG: 100,
      ),
    );
    await openAddFood(tester);
    await search(tester, 'banana');

    expect(find.text('Bananas, raw'), findsOneWidget);
    expect(find.text('Bananas, dehydrated'), findsOneWidget);
    // Only the dehydrated one is still a starter food.
    expect(find.byKey(const Key('bundled-food-0')), findsOneWidget);
    expect(find.byKey(const Key('bundled-food-1')), findsNothing);
    await unmount(tester);
  });

  testWidgets('the Catalog tab does not list starter foods', (tester) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [
          genericFoodsSourceProvider.overrideWithValue(() async => _foods),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.book_fill));
    await settle(tester);
    await search(tester, 'banana');

    expect(header, findsNothing);
    await unmount(tester);
  });
}
