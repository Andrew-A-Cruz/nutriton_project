import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
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
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
      'goal_protein': 150.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('the gear opens settings with the current goals filled in', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);

    expect(find.text('Settings'), findsOneWidget);
    final goal = tester.widget<CupertinoTextField>(
      find.byKey(const Key('goal-calories')),
    );
    expect(goal.controller!.text, '2000');
    await unmount(tester);
  });

  testWidgets('saving changes the goal, updates Home and returns to it', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('goal-calories')), '2500');
    await tapSubmitPreferences(tester);
    await settle(tester);

    expect(prefs.getDouble('goal_calories'), 2500);
    // Back on Home, with the new goal in the macro summary.
    expect(find.byKey(const Key('goal-calories')), findsNothing);
    expect(find.text('Food Log'), findsOneWidget);
    expect(find.textContaining('2500'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('an invalid goal blocks saving and stays on settings', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('goal-calories')), '0');
    await tapSubmitPreferences(tester);
    await settle(tester);

    // The error is under the goal, far above the button.
    await scrollPreferencesTo(
      tester,
      find.byKey(const Key('goal-calories')),
      delta: -200,
    );
    expect(find.text('Enter a number greater than 0'), findsWidgets);
    expect(prefs.getDouble('goal_calories'), 2000);
    expect(find.byKey(const Key('goal-calories')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a NaN goal is rejected, not saved', (tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('goal-calories')), 'NaN');
    await tapSubmitPreferences(tester);
    await settle(tester);

    await scrollPreferencesTo(
      tester,
      find.byKey(const Key('goal-calories')),
      delta: -200,
    );
    expect(find.text('Enter a number greater than 0'), findsWidgets);
    expect(prefs.getDouble('goal_calories'), 2000);
    expect(find.byKey(const Key('goal-calories')), findsOneWidget);
    await unmount(tester);
  });
}
