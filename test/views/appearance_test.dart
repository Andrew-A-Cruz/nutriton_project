import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/appearance.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/providers/appearance_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_app_icon_service.dart';
import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late FakeAppIconService icons;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    icons = FakeAppIconService();
  });

  tearDown(() async {
    await db.close();
  });

  Future<SharedPreferences> prefsWith({
    bool pro = true,
    Map<String, Object> extra = const {},
  }) => mockPreferences({
    'onboarding_complete': true,
    'primary_metric': 'calories',
    'tracked_metrics': ['calories'],
    'goal_calories': 2000.0,
    'pro_purchased': pro,
    ...extra,
  });

  Future<void> pumpApp(
    WidgetTester tester,
    SharedPreferences prefs, {
    bool withIcons = true,
  }) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [
          if (withIcons) appIconServiceProvider.overrideWithValue(icons),
        ],
      ),
    );
    await settle(tester);
  }

  Future<void> openAppearance(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await scrollPreferencesTo(tester, find.text('APPEARANCE'));
    await tester.ensureVisible(find.text('Accent colour'));
    await settle(tester);
  }

  Color accent(WidgetTester tester) => CupertinoTheme.of(
    tester.element(find.byType(CupertinoPageScaffold).first),
  ).primaryColor;

  group('accent colour', () {
    testWidgets('picking a colour applies and saves it at once', (
      tester,
    ) async {
      final prefs = await prefsWith();
      await pumpApp(tester, prefs);
      expect(accent(tester), isSameColorAs(CupertinoColors.systemBlue));
      await openAppearance(tester);

      await tester.tap(find.byKey(const Key('theme-purple')));
      await settle(tester);

      expect(prefs.getString('theme'), 'purple');
      expect(accent(tester), isSameColorAs(Color(AppTheme.purple.light)));
      await unmount(tester);
    });

    testWidgets('the saved colour is used at launch', (tester) async {
      await pumpApp(tester, await prefsWith(extra: {'theme': 'green'}));
      expect(accent(tester), isSameColorAs(Color(AppTheme.green.light)));
      await unmount(tester);
    });

    testWidgets('without Pro the default is used and the choice is kept', (
      tester,
    ) async {
      final prefs = await prefsWith(pro: false, extra: {'theme': 'green'});
      await pumpApp(tester, prefs);

      expect(accent(tester), isSameColorAs(CupertinoColors.systemBlue));
      expect(prefs.getString('theme'), 'green');
      await unmount(tester);
    });

    testWidgets('without Pro both pickers are locks that open the paywall', (
      tester,
    ) async {
      await pumpApp(tester, await prefsWith(pro: false));
      await openAppearance(tester);

      expect(find.byKey(const Key('theme-purple')), findsNothing);
      expect(find.byKey(const Key('icon-midnight')), findsNothing);
      final locks = find.descendant(
        of: find.ancestor(
          of: find.text('APPEARANCE'),
          matching: find.byType(CupertinoFormSection),
        ),
        matching: find.byKey(const Key('pro-lock')),
      );
      expect(locks, findsNWidgets(2));

      await tester.tap(locks.first);
      await settle(tester);
      expect(find.text('Themes and App Icons'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('app icon', () {
    testWidgets('picking an icon asks the system for it', (tester) async {
      await pumpApp(tester, await prefsWith());
      await openAppearance(tester);

      await tester.tap(find.byKey(const Key('icon-midnight')));
      await settle(tester);
      expect(icons.changes, ['AppIcon-Midnight']);

      await tester.tap(find.byKey(const Key('icon-standard')));
      await settle(tester);
      expect(icons.changes, ['AppIcon-Midnight', null]);
      await unmount(tester);
    });

    testWidgets('a refusal shows an error and keeps the icon', (tester) async {
      await pumpApp(tester, await prefsWith());
      await openAppearance(tester);
      icons.failNext = true;

      await tester.tap(find.byKey(const Key('icon-ocean')));
      await settle(tester);

      expect(
        find.text('Could not change the app icon. Try again.'),
        findsOneWidget,
      );
      expect(icons.icon, isNull);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await unmount(tester);
    });

    testWidgets('an icon chosen earlier stays after Pro is lost', (
      tester,
    ) async {
      icons.icon = 'AppIcon-Ocean';
      await pumpApp(tester, await prefsWith(pro: false));
      await openAppearance(tester);

      // Locked, and nothing reset the icon.
      expect(find.byKey(const Key('icon-ocean')), findsNothing);
      expect(icons.icon, 'AppIcon-Ocean');
      expect(icons.changes, isEmpty);
      await unmount(tester);
    });

    testWidgets('the picker is hidden where icons cannot change', (
      tester,
    ) async {
      await pumpApp(tester, await prefsWith(), withIcons: false);
      await openAppearance(tester);

      expect(find.text('Accent colour'), findsOneWidget);
      expect(find.text('App icon'), findsNothing);
      await unmount(tester);
    });
  });
}
