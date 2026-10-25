import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/providers/food_lookup_providers.dart';
import 'package:nutriton_project/providers/infrastructure_providers.dart';
import 'package:nutriton_project/views/catalog/barcode_scanner_page.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

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

  /// Opens the New Food form with a fake scanner returning [scanned] and
  /// records every barcode requested from the (mock) lookup API in [looked].
  Future<void> open(
    WidgetTester tester, {
    required bool supported,
    String? scanned,
    List<String>? looked,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((req) async {
      looked?.add(req.url.path);
      return http.Response(
        jsonEncode({
          'status': 1,
          'product': {
            'product_name': 'Soda',
            'nutriments': {'energy-kcal_100g': 42},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          httpClientProvider.overrideWithValue(client),
          barcodeScanSupportedProvider.overrideWithValue(supported),
          barcodeScannerProvider.overrideWithValue((_) async => scanned),
        ],
        child: const CupertinoApp(home: FoodFormView()),
      ),
    );
    await settle(tester);
  }

  String barcodeText(WidgetTester tester) => tester
      .widget<CupertinoTextField>(find.byKey(const Key('lookup-barcode')))
      .controller!
      .text;

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<CupertinoTextField>(find.byKey(Key(key))).controller!.text;

  testWidgets('scan button is shown only where scanning is supported', (
    tester,
  ) async {
    await open(tester, supported: true);
    expect(find.byKey(const Key('lookup-barcode-scan')), findsOneWidget);
    await unmount(tester);

    await open(tester, supported: false);
    expect(find.byKey(const Key('lookup-barcode-scan')), findsNothing);
    await unmount(tester);
  });

  testWidgets('scanned code fills the field and runs the lookup', (
    tester,
  ) async {
    final looked = <String>[];
    await open(tester, supported: true, scanned: '12345678', looked: looked);

    await tester.tap(find.byKey(const Key('lookup-barcode-scan')));
    await settle(tester);

    expect(barcodeText(tester), '12345678');
    expect(looked.single, contains('12345678'));
    // A scan fills the form for review; nothing is saved.
    expect(fieldText(tester, 'food-name'), 'Soda');
    expect(fieldText(tester, 'food-calories'), '42');
    expect(fieldText(tester, 'food-barcode'), '12345678');
    expect(await db.select(db.foodItems).get(), isEmpty);
    await unmount(tester);
  });

  testWidgets('cancelling the scanner does nothing', (tester) async {
    final looked = <String>[];
    await open(tester, supported: true, scanned: null, looked: looked);

    await tester.tap(find.byKey(const Key('lookup-barcode-scan')));
    await settle(tester);

    expect(barcodeText(tester), isEmpty);
    expect(looked, isEmpty);
    expect(find.byKey(const Key('lookup-result-0')), findsNothing);
    expect(find.byKey(const Key('lookup-loading')), findsNothing);
    await unmount(tester);
  });
}
