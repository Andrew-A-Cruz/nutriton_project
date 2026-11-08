import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/views/common/keyboard_done_bar.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Onboarding's setup form with the on-screen keyboard up.
  Future<void> openGoals(WidgetTester tester) async {
    // Tall enough that the goal rows are still built with the keyboard up.
    tester.view.physicalSize = const Size(2400, 4200);
    addTearDown(tester.view.resetPhysicalSize);
    final prefs = await tester.runAsync(() => mockPreferences({}));
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);
    await skipWelcome(tester);
    // Physical pixels: a 300 pt keyboard at 3x.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
  }

  final done = find.byKey(const Key('keyboard-done'));

  testWidgets(
    'Done closes the number keyboard and keeps the typed goal',
    (tester) async {
      await openGoals(tester);
      expect(done, findsNothing);

      final goal = find.byKey(const Key('goal-calories'));
      await tester.enterText(goal, '2100');
      await tester.pump();
      expect(done, findsOneWidget);

      await tester.tap(done);
      await tester.pump();

      expect(done, findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      expect(tester.widget<CupertinoTextField>(goal).controller!.text, '2100');
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'pages see the bar as part of the keyboard, so fields stay above it',
    (tester) async {
      await openGoals(tester);
      await tester.showKeyboard(find.byKey(const Key('goal-calories')));
      await tester.pump();

      // Read above the page scaffold, which takes the inset out for its body.
      final pageInset = MediaQuery.of(
        tester.element(find.byType(Navigator).first),
      ).viewInsets.bottom;
      expect(pageInset, 300 + KeyboardDoneBar.height);
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('no bar on Android, whose number keyboard has a done key', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await openGoals(tester);
    await tester.showKeyboard(find.byKey(const Key('goal-calories')));
    await tester.pump();

    expect(done, findsNothing);
    debugDefaultTargetPlatformOverride = null;
    await unmount(tester);
  });

  testWidgets(
    'no bar when the keyboard is down, e.g. a hardware keyboard',
    (tester) async {
      final prefs = await tester.runAsync(() => mockPreferences({}));
      await tester.pumpWidget(testApp(db: db, prefs: prefs!));
      await settle(tester);
      await skipWelcome(tester);
      await tester.showKeyboard(find.byKey(const Key('goal-calories')));
      await tester.pump();

      expect(done, findsNothing);
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
