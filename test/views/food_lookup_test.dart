import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/providers/food_lookup_providers.dart';
import 'package:nutriton_project/providers/infrastructure_providers.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> open(
    WidgetTester tester,
    http.Client client, {
    FoodItem? existing,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          httpClientProvider.overrideWithValue(client),
        ],
        child: CupertinoApp(home: FoodForm(existing)),
      ),
    );
    await settle(tester);
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<CupertinoTextField>(find.byKey(Key(key))).controller!.text;

  testWidgets('name search lists results; tapping one prefills editable form', (
    tester,
  ) async {
    final client = MockClient((req) async {
      expect(req.headers['User-Agent'], isNotEmpty);
      return _json({
        'products': [
          {
            'product_name': 'Granola',
            'brands': 'Acme',
            'serving_quantity': 40,
            'nutriments': {
              'energy-kcal_100g': 450,
              'proteins_100g': 10,
              'carbohydrates_100g': 60,
              'fat_100g': 15,
            },
          },
          {'product_name': 'Plain'},
        ],
      });
    });
    await open(tester, client);

    await tester.enterText(find.byKey(const Key('lookup-query')), 'granola');
    await tester.tap(find.byKey(const Key('lookup-query-go')));
    await settle(tester);

    expect(find.byKey(const Key('lookup-result-0')), findsOneWidget);
    expect(find.byKey(const Key('lookup-result-1')), findsOneWidget);
    expect(find.text('Acme - 180 kcal, 40 g serving'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lookup-result-0')));
    await tester.pump();
    expect(text(tester, 'food-name'), 'Granola');
    expect(text(tester, 'food-calories'), '180');
    expect(text(tester, 'food-protein'), '4');
    expect(text(tester, 'food-carbs'), '24');
    expect(text(tester, 'food-fat'), '6');
    expect(text(tester, 'food-serving-weight'), '40');

    // Still editable.
    await tester.enterText(find.byKey(const Key('food-name')), 'My granola');
    expect(text(tester, 'food-name'), 'My granola');
    await unmount(tester);
  });

  testWidgets('barcode lookup prefills; not found shows a message', (
    tester,
  ) async {
    final client = MockClient((req) async {
      if (req.url.path.contains('11111111')) {
        return _json({
          'status': 1,
          'product': {
            'product_name': 'Soda',
            'nutriments': {'energy-kcal_100g': 42},
          },
        });
      }
      return _json({'status': 0}, 404);
    });
    await open(tester, client);

    await tester.enterText(find.byKey(const Key('lookup-barcode')), '22222222');
    await tester.tap(find.byKey(const Key('lookup-barcode-go')));
    await settle(tester);
    expect(find.byKey(const Key('lookup-not-found')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('lookup-barcode')), '11111111');
    await tester.tap(find.byKey(const Key('lookup-barcode-go')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('lookup-result-0')));
    await tester.pump();
    expect(text(tester, 'food-name'), 'Soda');
    expect(text(tester, 'food-calories'), '42');
    expect(text(tester, 'food-serving-weight'), '100');
    await unmount(tester);
  });

  testWidgets('invalid barcode and network failure show errors', (
    tester,
  ) async {
    final client = MockClient((_) async => throw http.ClientException('down'));
    await open(tester, client);

    await tester.enterText(find.byKey(const Key('lookup-barcode')), '12');
    await tester.tap(find.byKey(const Key('lookup-barcode-go')));
    await settle(tester);
    expect(find.textContaining('8 to 14 digits'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('lookup-query')), 'oat');
    await tester.tap(find.byKey(const Key('lookup-query-go')));
    await settle(tester);
    expect(find.textContaining('Could not reach'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('shows a loading indicator while waiting', (tester) async {
    final completer = Completer<http.Response>();
    await open(tester, MockClient((_) => completer.future));

    await tester.enterText(find.byKey(const Key('lookup-query')), 'oat');
    await tester.tap(find.byKey(const Key('lookup-query-go')));
    await tester.pump();
    expect(find.byKey(const Key('lookup-loading')), findsOneWidget);

    completer.complete(_json({'products': []}));
    await settle(tester);
    expect(find.byKey(const Key('lookup-loading')), findsNothing);
    expect(find.byKey(const Key('lookup-not-found')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no lookup section when editing an existing food', (
    tester,
  ) async {
    final food = (await tester.runAsync(() async {
      final catalog = CatalogRepository(db);
      final id = await catalog.createFood(
        name: 'Egg',
        perServing: const Macros(calories: 70, protein: 6, fat: 5),
        servingWeightG: 50,
      );
      return catalog.findFood(id);
    }))!;
    await open(tester, MockClient((_) async => _json({})), existing: food);
    expect(find.byKey(const Key('lookup-query')), findsNothing);
    await unmount(tester);
  });
}

/// The form under test.
class FoodForm extends StatelessWidget {
  const FoodForm(this.existing, {super.key});

  final FoodItem? existing;

  @override
  Widget build(BuildContext context) => FoodFormView(existing: existing);
}
