import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/core/shortcuts.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/shortcuts_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_shortcuts_bridge.dart';
import '../support/test_app.dart';

/// Siri and Shortcuts: what the app publishes, and requests it carries out.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeShortcutsBridge bridge;
  final now = DateTime(2026, 11, 12, 8);
  const today = '2026-11-12';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    bridge = FakeShortcutsBridge();
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories'],
      'goal_calories': 2000.0,
    });
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [
          shortcutsBridgeProvider.overrideWithValue(bridge),
          clockProvider.overrideWithValue(() => now),
        ],
      ),
    );
    await settle(tester);
  }

  Future<String> seedCatalog() async {
    final catalog = CatalogRepository(db);
    final oats = await catalog.createFood(
      name: 'Oats',
      perServing: const Macros(calories: 150),
      servingWeightG: 40,
    );
    final banana = await catalog.createFood(
      name: 'Banana',
      perServing: const Macros(calories: 100),
      servingWeightG: 120,
    );
    await catalog.setFoodFavorite(banana, favorite: true);
    await catalog.createMeal(
      name: 'Breakfast',
      items: [MealItemInput(foodItemId: oats, weightG: 40)],
    );
    await catalog.createMeal(
      name: 'Granola',
      items: [MealItemInput(foodItemId: oats, weightG: 400)],
      cookedWeightG: 300,
    );
    return banana;
  }

  testWidgets('publishes today\'s sentence and the loggable items', (
    tester,
  ) async {
    await tester.runAsync(seedCatalog);
    await tester.runAsync(
      () => LogRepository(db).logAdhoc(
        logDate: today,
        name: 'Toast',
        macros: const Macros(calories: 300),
      ),
    );
    await pumpApp(tester);

    final last = bridge.published.last;
    expect(last.summary.dateKey, today);
    expect(last.summary.sentence, 'You have 1700 calories left today.');
    // Saved meals except recipes, and starred foods only.
    expect({for (final i in last.items) i.name}, {'Breakfast', 'Banana'});
    await unmount(tester);
  });

  testWidgets('publishes again after logging', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => LogRepository(db).logAdhoc(
        logDate: today,
        name: 'Toast',
        macros: const Macros(calories: 500),
      ),
    );
    await settle(tester);

    expect(
      bridge.published.last.summary.sentence,
      'You have 1500 calories left today.',
    );
    await unmount(tester);
  });

  testWidgets('a request waiting at launch is logged once', (tester) async {
    final banana = await tester.runAsync(seedCatalog);
    bridge.pending = (itemId: 'food:$banana', at: now);
    await pumpApp(tester);

    final entries = await tester.runAsync(
      () => db.select(db.foodLogEntries).get(),
    );
    expect(entries!.single.name, 'Banana');
    expect(entries.single.logDate, today);
    expect(find.text('Banana'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a request signalled while running is logged', (tester) async {
    final banana = await tester.runAsync(seedCatalog);
    await pumpApp(tester);
    expect(
      await tester.runAsync(() => db.select(db.foodLogEntries).get()),
      isEmpty,
    );

    bridge.pending = (itemId: 'food:$banana', at: now);
    bridge.signal();
    await settle(tester);

    expect(find.text('Banana'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a stale request is dropped', (tester) async {
    final banana = await tester.runAsync(seedCatalog);
    bridge.pending = (
      itemId: 'food:$banana',
      at: now.subtract(shortcutRequestLifetime * 2),
    );
    await pumpApp(tester);

    expect(
      await tester.runAsync(() => db.select(db.foodLogEntries).get()),
      isEmpty,
    );
    expect(bridge.pending, isNull);
    await unmount(tester);
  });
}
