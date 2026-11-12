import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/menus.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/providers/menu_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/menu_fixture.dart';
import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late List<Uri> opened;

  setUp(() async {
    opened = [];
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

  Future<void> pumpApp(WidgetTester tester, {String? menus}) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        menus: menus ?? menuFixture(),
        overrides: [
          linkOpenerProvider.overrideWithValue((url) async => opened.add(url)),
        ],
      ),
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await settle(tester);
  }

  final entry = find.byKey(const Key('restaurants-entry'));

  group('the Restaurants row', () {
    testWidgets('shows in Add Food until a search is typed', (tester) async {
      await pumpApp(tester);
      await tap(tester, 'add-food-button');
      expect(entry, findsOneWidget);

      await type(tester, 'catalog-search', 'fries');
      expect(entry, findsNothing);
      await unmount(tester);
    });

    testWidgets('is not on the Meals side or in the Catalog tab', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Catalog'));
      await settle(tester);
      expect(find.byKey(const Key('catalog-search')), findsOneWidget);
      expect(entry, findsNothing);

      await tester.tap(find.text('Today'));
      await settle(tester);
      await tap(tester, 'add-food-button');
      expect(entry, findsOneWidget);
      await tester.tap(find.text('Meals').last);
      await settle(tester);
      expect(entry, findsNothing);
      await unmount(tester);
    });

    testWidgets('is hidden when no menus are bundled', (tester) async {
      await pumpApp(tester, menus: noMenus);
      await tap(tester, 'add-food-button');
      expect(find.byKey(const Key('catalog-search')), findsOneWidget);
      expect(entry, findsNothing);
      await unmount(tester);
    });

    testWidgets('is hidden when the menus file cannot be read', (tester) async {
      await pumpApp(tester, menus: 'not json');
      await tap(tester, 'add-food-button');
      expect(find.byKey(const Key('catalog-search')), findsOneWidget);
      expect(entry, findsNothing);
      await unmount(tester);
    });
  });

  testWidgets('a menu item is logged in five taps', (tester) async {
    await pumpApp(tester);

    await tap(tester, 'add-food-button'); // 1
    await tap(tester, 'restaurants-entry'); // 2
    expect(find.text('Example Burger'), findsOneWidget);
    expect(find.text("Sample's Chicken"), findsOneWidget);

    await tap(tester, 'chain-example-burger'); // 3
    // Grouped under the chain's categories, in the file's order.
    expect(find.text('BURGERS'), findsOneWidget);
    expect(find.text('SIDES'), findsOneWidget);
    expect(find.text('DRINKS'), findsOneWidget);
    expect(find.text('320 kcal · 114 g'), findsOneWidget);
    // Nothing is copied into the catalog by browsing.
    expect(await db.select(db.foodItems).get(), isEmpty);

    await tap(tester, 'menu-item-fries-medium'); // 4
    final food = (await db.select(db.foodItems).get()).single;
    expect(food.name, 'French Fries, Medium');
    expect(food.brand, 'Example Burger');
    expect(food.menuItemId, 'example-burger/fries-medium');
    expect(food.menuVersion, 1);

    await tap(tester, 'log-food-confirm'); // 5
    final logged = (await db.select(db.foodLogEntries).get()).single;
    expect(logged.name, 'French Fries, Medium');
    expect(logged.calories, 320);
    expect(logged.foodItemId, food.id);
    expect(logged.logDate, todayKey());
    // Back on Today, with the sheet closed.
    expect(find.byKey(const Key('add-food-button')), findsOneWidget);
    expect(find.byKey(const Key('restaurants-search')), findsNothing);
    await unmount(tester);
  });

  testWidgets('logging an item twice makes two entries and one food', (
    tester,
  ) async {
    await pumpApp(tester);
    for (var i = 0; i < 2; i++) {
      await tap(tester, 'add-food-button');
      await tap(tester, 'restaurants-entry');
      await tap(tester, 'chain-example-burger');
      await tap(tester, 'menu-item-fries-medium');
      await tap(tester, 'log-food-confirm');
    }
    expect(await db.select(db.foodLogEntries).get(), hasLength(2));
    expect(await db.select(db.foodItems).get(), hasLength(1));
    await unmount(tester);
  });

  testWidgets('searching within a chain filters its items', (tester) async {
    await pumpApp(tester);
    await tap(tester, 'add-food-button');
    await tap(tester, 'restaurants-entry');
    await tap(tester, 'chain-example-burger');

    await type(tester, 'chain-search', 'cola');
    expect(find.byKey(const Key('menu-item-cola-medium')), findsOneWidget);
    expect(find.byKey(const Key('menu-item-fries-medium')), findsNothing);
    expect(find.text('DRINKS'), findsOneWidget);
    expect(find.text('SIDES'), findsNothing);

    // Another chain's items never show here.
    await type(tester, 'chain-search', 'tenders');
    expect(find.text('No items match "tenders".'), findsOneWidget);
    expect(find.byKey(const Key('menu-attribution')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('searching Restaurants covers every chain', (tester) async {
    await pumpApp(tester);
    await tap(tester, 'add-food-button');
    await tap(tester, 'restaurants-entry');

    await type(tester, 'restaurants-search', 'fries');
    expect(find.byKey(const Key('chain-example-burger')), findsNothing);
    expect(find.text('French Fries, Medium'), findsOneWidget);
    expect(find.text('Example Burger · 320 kcal'), findsOneWidget);
    expect(find.text('Seasoned Fries, Large'), findsOneWidget);
    expect(find.text("Sample's Chicken · 480 kcal"), findsOneWidget);

    await type(tester, 'restaurants-search', 'zzz');
    expect(find.text('No menu items match "zzz".'), findsOneWidget);

    await type(tester, 'restaurants-search', 'samples tenders');
    await tap(tester, 'menu-result-0');
    final food = (await db.select(db.foodItems).get()).single;
    expect(food.name, 'Chicken Tenders (3)');
    expect(food.brand, "Sample's Chicken");
    await unmount(tester);
  });

  group('Add Food search', () {
    final header = find.byKey(const Key('menu-foods-header'));

    testWidgets('lists matching menu items under RESTAURANTS', (tester) async {
      await pumpApp(tester);
      await tap(tester, 'add-food-button');
      expect(header, findsNothing);

      await type(tester, 'catalog-search', 'fries');
      expect(header, findsOneWidget);
      expect(find.text('RESTAURANTS'), findsOneWidget);
      expect(find.text('French Fries, Medium'), findsOneWidget);
      expect(find.text('Example Burger · 320 kcal'), findsOneWidget);
      expect(find.text('Seasoned Fries, Large'), findsOneWidget);
      // With no catalog food matching, there is no "no foods" message.
      expect(find.textContaining('No foods match'), findsNothing);

      await tester.tap(find.text('Meals').last);
      await settle(tester);
      expect(header, findsNothing);
      await unmount(tester);
    });

    testWidgets('tapping one copies it in and opens the servings screen', (
      tester,
    ) async {
      await pumpApp(tester);
      await tap(tester, 'add-food-button');
      await type(tester, 'catalog-search', 'cheeseburger');
      await tap(tester, 'menu-food-0');

      final food = (await db.select(db.foodItems).get()).single;
      expect(food.name, 'Cheeseburger');
      await tap(tester, 'log-food-confirm');
      final logged = (await db.select(db.foodLogEntries).get()).single;
      expect(logged.calories, 300);
      await unmount(tester);
    });

    testWidgets('an item already in the catalog shows once', (tester) async {
      final menus = parseMenus(menuFixture());
      await tester.runAsync(
        () => CatalogRepository(db).adoptMenuItem(
          menus.itemById('example-burger/fries-medium')!,
          version: 1,
        ),
      );
      await pumpApp(tester);
      await tap(tester, 'add-food-button');
      await type(tester, 'catalog-search', 'fries');

      // Once as the catalog's own row, and the other chain's under the
      // header.
      expect(find.text('French Fries, Medium'), findsOneWidget);
      expect(find.text('Example Burger · 320 kcal per 114 g'), findsOneWidget);
      expect(find.text('Example Burger · 320 kcal'), findsNothing);
      expect(find.text('Seasoned Fries, Large'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the Catalog tab search lists no menu items', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Catalog'));
      await settle(tester);
      await type(tester, 'catalog-search', 'fries');
      expect(header, findsNothing);
      expect(find.text('No foods match "fries".'), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('a chain says where its values come from, with a report link', (
    tester,
  ) async {
    await pumpApp(tester);
    await tap(tester, 'add-food-button');
    await tap(tester, 'restaurants-entry');
    await tap(tester, 'chain-example-burger');

    expect(
      find.text(
        'Values from Example Burger, checked November 2026. Recipes change.',
      ),
      findsOneWidget,
    );
    await tap(tester, 'report-menu-value');
    final url = opened.single;
    expect(url.scheme, 'mailto');
    expect(url.path, 'logbite.app@gmail.com');
    expect(url.toString(), contains('subject=Wrong%20menu%20value'));
    expect(url.toString(), contains('Example%20Burger'));
    await unmount(tester);
  });

  testWidgets('an item with no published weight is logged by the item', (
    tester,
  ) async {
    await pumpApp(tester);
    await tap(tester, 'add-food-button');
    await tap(tester, 'restaurants-entry');
    await tap(tester, 'chain-sample-chicken');
    // No weight beside the calories.
    expect(find.text('250 kcal'), findsOneWidget);
    expect(find.text('480 kcal · 160 g'), findsOneWidget);

    await tap(tester, 'menu-item-lemonade-large');
    // Servings only: there is no weight to convert from.
    expect(find.byKey(const Key('log-amount')), findsOneWidget);
    expect(find.byKey(const Key('log-mode')), findsNothing);
    await tap(tester, 'log-food-confirm');

    final food = (await db.select(db.foodItems).get()).single;
    expect(food.weightUnknown, isTrue);
    final logged = (await db.select(db.foodLogEntries).get()).single;
    expect(logged.name, 'Lemonade, Large');
    expect(logged.calories, 250);

    // In the catalog it reads "per item", never "per 1 g".
    await tap(tester, 'add-food-button');
    await type(tester, 'catalog-search', 'lemonade');
    expect(find.text("Sample's Chicken · 250 kcal per item"), findsOneWidget);
    expect(find.textContaining('per 1 g'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a food with a weight still offers logging by weight', (
    tester,
  ) async {
    await pumpApp(tester);
    await tap(tester, 'add-food-button');
    await tap(tester, 'restaurants-entry');
    await tap(tester, 'chain-example-burger');
    await tap(tester, 'menu-item-fries-medium');
    expect(find.byKey(const Key('log-mode')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('weights follow the display unit', (tester) async {
    prefs = await tester
        .runAsync(
          () => mockPreferences({
            'onboarding_complete': true,
            'primary_metric': 'calories',
            'tracked_metrics': ['calories'],
            'goal_calories': 2000.0,
            'display_unit': 'oz',
          }),
        )
        .then((p) => p!);
    await pumpApp(tester);
    await tap(tester, 'add-food-button');
    await tap(tester, 'restaurants-entry');
    await tap(tester, 'chain-example-burger');
    expect(find.text('320 kcal · 4 oz'), findsOneWidget);
    await unmount(tester);
  });

  group('at launch', () {
    Future<void> seed({required int? menuVersion}) => db.foodDao.insertFood(
      FoodItemsCompanion.insert(
        id: 'fries',
        name: 'French Fries, Medium',
        calories: 320,
        protein: 5,
        carbs: 43,
        fat: 15,
        servingWeightG: 114,
        brand: const Value('Example Burger'),
        menuItemId: const Value('example-burger/fries-medium'),
        menuVersion: Value(menuVersion),
      ),
    );

    testWidgets('an unedited menu food is brought up to a newer file', (
      tester,
    ) async {
      await tester.runAsync(() => seed(menuVersion: 1));
      await pumpApp(tester, menus: menuFixture(version: 2, friesCalories: 350));
      await settle(tester);

      final food = (await db.select(db.foodItems).get()).single;
      expect(food.calories, 350);
      expect(food.menuVersion, 2);
      await unmount(tester);
    });

    testWidgets('an edited menu food is left alone', (tester) async {
      await tester.runAsync(() => seed(menuVersion: null));
      await pumpApp(tester, menus: menuFixture(version: 2, friesCalories: 350));
      await settle(tester);

      final food = (await db.select(db.foodItems).get()).single;
      expect(food.calories, 320);
      expect(food.menuVersion, isNull);
      await unmount(tester);
    });
  });
}
