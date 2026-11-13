import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

/// System Back (Android) at the root of a tab.
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

  tearDown(() => db.close());

  /// What the system does on Back; true when the app handled it.
  Future<bool> back(WidgetTester tester) async {
    final handled = await tester.binding.handlePopRoute();
    await settle(tester);
    return handled;
  }

  testWidgets('Back on Summary goes to Today, then leaves the app', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
    expect(find.byKey(const Key('summary-range')), findsOneWidget);

    expect(await back(tester), isTrue);
    expect(find.byKey(const Key('add-food-button')), findsOneWidget);
    expect(find.byKey(const Key('summary-range')), findsNothing);

    // On Today, Back is left to the system, which closes the app.
    expect(await back(tester), isFalse);
    await unmount(tester);
  });

  testWidgets('Back on a page pushed in a tab pops that page first', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.book_fill));
    await settle(tester);
    await tester.tap(find.byKey(const Key('catalog-add')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('catalog-new-food')));
    await settle(tester);
    expect(find.byType(FoodFormView), findsOneWidget);

    expect(await back(tester), isTrue);
    // Back on Catalog, not Today.
    expect(find.byType(FoodFormView), findsNothing);
    expect(find.byKey(const Key('catalog-add')), findsOneWidget);
    expect(find.byKey(const Key('add-food-button')), findsNothing);
    await unmount(tester);
  });
}
