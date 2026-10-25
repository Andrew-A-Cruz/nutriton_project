import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/providers/food_lookup_providers.dart';
import 'package:nutriton_project/views/add_food/log_food_view.dart';
import 'package:nutriton_project/views/catalog/barcode_scanner_page.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

/// The scan flow end to end from Add Food, with a fake scanner and a mock
/// Open Food Facts.
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

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<CupertinoTextField>(find.byKey(Key(key))).controller!.text;

  http.Response ok(Map<String, dynamic> product) => http.Response(
    jsonEncode({'status': 1, 'product': product}),
    200,
    headers: {'content-type': 'application/json'},
  );

  /// Home -> Add Food -> New food -> Scan, with a scanner that returns
  /// [scanned] and [handler] standing in for Open Food Facts.
  Future<void> scanFromAddFood(
    WidgetTester tester, {
    required String scanned,
    required Future<http.Response> Function(http.Request) handler,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [
          httpClientProvider.overrideWithValue(MockClient(handler)),
          barcodeScanSupportedProvider.overrideWithValue(true),
          barcodeScannerProvider.overrideWithValue((_) async => scanned),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-new-food')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('lookup-barcode-scan')));
    await settle(tester);
  }

  testWidgets('a catalog hit goes to the log flow with no network call', (
    tester,
  ) async {
    await tester.runAsync(
      () => CatalogRepository(db).createFood(
        name: 'Cola',
        perServing: const Macros(calories: 140, protein: 0, carbs: 35, fat: 0),
        servingWeightG: 330,
        barcode: '12345678',
      ),
    );
    final looked = <String>[];
    await scanFromAddFood(
      tester,
      scanned: '12345678',
      handler: (req) async {
        looked.add(req.url.toString());
        return ok({'product_name': 'Other'});
      },
    );

    expect(looked, isEmpty);
    expect(find.byType(LogFoodView), findsOneWidget);
    expect(find.text('Cola'), findsWidgets);
    expect(find.byType(FoodFormView), findsNothing);
    await unmount(tester);
  });

  testWidgets('an archived food with the barcode is not a local hit', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final catalog = CatalogRepository(db);
      final id = await catalog.createFood(
        name: 'Cola',
        perServing: const Macros(calories: 140, protein: 0, carbs: 35, fat: 0),
        servingWeightG: 330,
        barcode: '12345678',
      );
      await catalog.setFoodArchived(id, archived: true);
    });
    final looked = <String>[];
    await scanFromAddFood(
      tester,
      scanned: '12345678',
      handler: (req) async {
        looked.add(req.url.toString());
        return ok({'product_name': 'Cola Zero'});
      },
    );

    expect(looked, hasLength(1));
    expect(fieldText(tester, 'food-name'), 'Cola Zero');
    await unmount(tester);
  });

  testWidgets('a remote hit opens a prefilled form and saves the barcode', (
    tester,
  ) async {
    await scanFromAddFood(
      tester,
      scanned: '87654321',
      handler: (_) async => ok({
        'product_name': 'Granola',
        'serving_quantity': 40,
        'nutriments': {'energy-kcal_100g': 450, 'sodium_100g': 0.1},
      }),
    );

    expect(find.byType(LogFoodView), findsNothing);
    expect(fieldText(tester, 'food-name'), 'Granola');
    expect(fieldText(tester, 'food-calories'), '180');
    expect(fieldText(tester, 'food-barcode'), '87654321');
    // Nothing is saved until the user says so.
    expect(await db.select(db.foodItems).get(), isEmpty);

    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);
    final saved = (await db.select(db.foodItems).get()).single;
    expect(saved.barcode, '87654321');
    expect(saved.name, 'Granola');
    await unmount(tester);
  });

  testWidgets('not found says so and still keeps the scanned barcode', (
    tester,
  ) async {
    await scanFromAddFood(
      tester,
      scanned: '22222222',
      handler: (_) async => http.Response('{"status":0}', 404),
    );

    expect(find.byKey(const Key('lookup-not-found')), findsOneWidget);
    expect(find.textContaining('No product with that barcode'), findsOneWidget);
    expect(fieldText(tester, 'food-barcode'), '22222222');
    expect(fieldText(tester, 'food-name'), isEmpty);
    await unmount(tester);
  });

  testWidgets('offline shows a connection message', (tester) async {
    await scanFromAddFood(
      tester,
      scanned: '33333333',
      handler: (_) async => throw http.ClientException('down'),
    );

    expect(find.byKey(const Key('lookup-error')), findsOneWidget);
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(fieldText(tester, 'food-name'), isEmpty);
    await unmount(tester);
  });

  testWidgets('a product without nutrition prefills and warns', (tester) async {
    await scanFromAddFood(
      tester,
      scanned: '44444444',
      handler: (_) async => ok({'product_name': 'Mystery sauce'}),
    );

    expect(fieldText(tester, 'food-name'), 'Mystery sauce');
    expect(find.byKey(const Key('lookup-notice')), findsOneWidget);
    expect(find.textContaining('no nutrition facts'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a product without a serving size warns it is per 100 g', (
    tester,
  ) async {
    await scanFromAddFood(
      tester,
      scanned: '55555555',
      handler: (_) async => ok({
        'product_name': 'Crackers',
        'nutriments': {'energy-kj_100g': 1674},
      }),
    );

    // kJ only: 1674 / 4.184 = 400 kcal.
    expect(fieldText(tester, 'food-calories'), '400');
    expect(fieldText(tester, 'food-serving-weight'), '100');
    expect(find.textContaining('No serving size'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a typed barcode already in the catalog form is reported', (
    tester,
  ) async {
    await tester.runAsync(
      () => CatalogRepository(db).createFood(
        name: 'Cola',
        perServing: const Macros(calories: 140),
        servingWeightG: 330,
        barcode: '66666666',
      ),
    );
    final looked = <String>[];
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testScreen(
        db: db,
        prefs: prefs,
        home: const FoodFormView(),
        overrides: [
          httpClientProvider.overrideWithValue(
            MockClient((req) async {
              looked.add(req.url.toString());
              return ok({'product_name': 'x'});
            }),
          ),
        ],
      ),
    );
    await settle(tester);

    await tester.enterText(find.byKey(const Key('lookup-barcode')), '66666666');
    await tester.tap(find.byKey(const Key('lookup-barcode-go')));
    await settle(tester);

    expect(looked, isEmpty);
    expect(find.byKey(const Key('lookup-in-catalog')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an invalid barcode in the form is rejected on save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testScreen(db: db, prefs: prefs, home: const FoodFormView()),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const Key('food-name')), 'Thing');
    await tester.enterText(find.byKey(const Key('food-barcode')), '12ab');
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);
    expect(find.textContaining('8 to 14 digits'), findsOneWidget);
    await unmount(tester);
  });
}
