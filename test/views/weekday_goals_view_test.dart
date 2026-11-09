import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

// A Monday.
final _now = DateTime(2026, 11, 9, 12);

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('a Monday goal set in Settings shows on Monday', (tester) async {
    tester.view.physicalSize = const Size(2400, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [clockProvider.overrideWithValue(() => _now)],
      ),
    );
    await settle(tester);
    expect(find.text('/ 2000 kcal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    final row = find.byKey(const Key('weekday-goals'));
    await scrollPreferencesTo(tester, row);
    await tester.tap(row);
    await settle(tester);
    await tester.tap(find.byKey(const Key('weekday-goals-mon')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('weekday-goal-calories')),
      '2600',
    );
    await tester.tap(find.byKey(const Key('weekday-goals-save')));
    await settle(tester);

    expect(find.text('2600 kcal'), findsOneWidget);
    expect(find.text('Usual goals'), findsNWidgets(6));
    expect(prefs.getDouble('goal_calories_mon'), 2600);

    // Back out of Settings without saving the form: the weekday goal stays.
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    expect(find.text('/ 2600 kcal'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('saving the Settings form keeps the weekday goals', (
    tester,
  ) async {
    await prefs.setDouble('goal_calories_mon', 2600);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('goal-calories')), '2100');
    await tapSubmitPreferences(tester);
    await settle(tester);

    expect(prefs.getDouble('goal_calories'), 2100);
    expect(prefs.getDouble('goal_calories_mon'), 2600);
    await unmount(tester);
  });
}
