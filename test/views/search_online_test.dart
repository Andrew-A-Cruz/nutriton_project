import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/providers/food_lookup_providers.dart';
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
    });
  });

  tearDown(() async {
    await db.close();
  });

  final searches = <String>[];
  final client = MockClient((req) async {
    searches.add(req.url.queryParameters['search_terms'] ?? req.url.toString());
    return http.Response(
      jsonEncode({
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
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  Future<void> openAddFood(WidgetTester tester) async {
    searches.clear();
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [httpClientProvider.overrideWithValue(client)],
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
  }

  final row = find.byKey(const Key('search-online'));

  testWidgets('the row appears only while searching foods', (tester) async {
    await openAddFood(tester);
    expect(row, findsNothing);

    await tester.enterText(find.byKey(const Key('catalog-search')), 'granola');
    await tester.pump();
    expect(find.text('Search Open Food Facts for "granola"'), findsOneWidget);

    await tester.tap(find.text('Meals'));
    await tester.pump();
    expect(row, findsNothing);
    await unmount(tester);
  });

  testWidgets('it opens a new food with the online results; a pick logs it', (
    tester,
  ) async {
    await openAddFood(tester);
    await tester.enterText(find.byKey(const Key('catalog-search')), 'granola');
    await tester.pump();
    await tester.tap(row);
    await settle(tester);

    expect(searches, hasLength(1));
    expect(searches.single, contains('granola'));
    expect(find.byKey(const Key('lookup-result-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('lookup-result-0')));
    await tester.pump();
    expect(
      tester
          .widget<CupertinoTextField>(find.byKey(const Key('food-name')))
          .controller!
          .text,
      'Granola',
    );
    await unmount(tester);
  });
}
