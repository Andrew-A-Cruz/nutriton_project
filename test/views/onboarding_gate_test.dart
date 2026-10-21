import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'shows onboarding, not the tabs, when it has not been completed',
    (tester) async {
      final prefs = await tester.runAsync(() => mockPreferences({}));

      await tester.pumpWidget(testApp(db: db, prefs: prefs!));
      await settle(tester);

      expect(find.text('Set up Nutriton'), findsOneWidget);
      expect(find.byKey(const Key('goal-calories')), findsOneWidget);
      expect(find.byType(CupertinoTabScaffold), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets('a valid form saves preferences and opens the tabs', (
    tester,
  ) async {
    final prefs = await tester.runAsync(() => mockPreferences({}));

    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('goal-calories')), '2000');
    await tapSubmitPreferences(tester);
    await settle(tester);

    expect(find.text('Food Log'), findsOneWidget);
    expect(find.byType(CupertinoTabScaffold), findsOneWidget);
    expect(prefs.getBool('onboarding_complete'), isTrue);
    expect(prefs.getDouble('goal_calories'), 2000);
    expect(prefs.getStringList('tracked_metrics'), ['calories']);
    await unmount(tester);
  });

  testWidgets('a blank primary goal is rejected and nothing is saved', (
    tester,
  ) async {
    final prefs = await tester.runAsync(() => mockPreferences({}));

    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);

    await tapSubmitPreferences(tester);
    await settle(tester);

    expect(find.text('Enter a daily goal for Calories'), findsOneWidget);
    expect(find.text('Set up Nutriton'), findsOneWidget);
    expect(prefs.getBool('onboarding_complete'), isNull);
    await unmount(tester);
  });

  testWidgets('goes straight to the tabs when onboarding is complete', (
    tester,
  ) async {
    final prefs = await tester.runAsync(
      () => mockPreferences({'onboarding_complete': true}),
    );

    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);

    expect(find.text('Set up Nutriton'), findsNothing);
    expect(find.byType(CupertinoTabScaffold), findsOneWidget);
    await unmount(tester);
  });
}
