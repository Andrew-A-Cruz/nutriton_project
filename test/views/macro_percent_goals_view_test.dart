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
      'tracked_metrics': ['calories', 'protein', 'carbs', 'fat'],
      'goal_calories': 2000.0,
      'goal_protein': 150.0,
      'goal_carbs': 200.0,
      'goal_fat': 67.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openSettingsInPercentMode(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await tester.tap(find.text('% of calories'));
    await tester.pump();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<CupertinoTextField>(find.byKey(Key(key))).controller!.text;

  testWidgets('percentages start from the gram goals and show their grams', (
    tester,
  ) async {
    await openSettingsInPercentMode(tester);

    expect(fieldText(tester, 'goal-percent-protein'), '30');
    expect(fieldText(tester, 'goal-percent-carbs'), '40');
    expect(fieldText(tester, 'goal-percent-fat'), '30');
    expect(find.byKey(const Key('goal-protein')), findsNothing);
    expect(find.text('= 150.0 g'), findsOneWidget);

    // The grams follow the calorie goal as it is typed.
    await tester.enterText(find.byKey(const Key('goal-calories')), '2400');
    await tester.pump();
    expect(find.text('= 180.0 g'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('saving stores the percentages and the derived grams', (
    tester,
  ) async {
    await openSettingsInPercentMode(tester);
    await tester.enterText(find.byKey(const Key('goal-percent-protein')), '35');
    await tester.enterText(find.byKey(const Key('goal-percent-carbs')), '35');
    await tapSubmitPreferences(tester);
    await settle(tester);

    expect(prefs.getInt('goal_percent_protein'), 35);
    expect(prefs.getInt('goal_percent_fat'), 30);
    expect(prefs.getDouble('goal_protein'), 175);
    expect(prefs.getDouble('goal_carbs'), 175);
    expect(prefs.getDouble('goal_fat'), 66.7);
    await unmount(tester);
  });

  testWidgets('percentages that do not add up to 100 block saving', (
    tester,
  ) async {
    await openSettingsInPercentMode(tester);
    await tester.enterText(find.byKey(const Key('goal-percent-fat')), '40');
    await tapSubmitPreferences(tester);
    await settle(tester);

    // Still on Settings, with the error beside the fat field above.
    final error = find.text('The percentages add up to 110%, not 100%');
    await scrollPreferencesTo(tester, error, delta: -200);
    expect(error, findsOneWidget);
    expect(prefs.getInt('goal_percent_protein'), isNull);
    await unmount(tester);
  });

  testWidgets('switching back to grams clears the percentages', (tester) async {
    await prefs.setInt('goal_percent_protein', 30);
    await prefs.setInt('goal_percent_carbs', 40);
    await prefs.setInt('goal_percent_fat', 30);
    tester.view.physicalSize = const Size(2400, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    expect(find.byKey(const Key('goal-percent-protein')), findsOneWidget);

    await tester.tap(find.text('Macros in grams'));
    await tester.pump();
    await tapSubmitPreferences(tester);
    await settle(tester);

    expect(prefs.getInt('goal_percent_protein'), isNull);
    expect(prefs.getDouble('goal_protein'), 150);
    await unmount(tester);
  });
}
