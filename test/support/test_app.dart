import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nutriton_project/app.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/providers/infrastructure_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sets the mocked preference values and loads them. Call outside
/// `testWidgets` (or inside `tester.runAsync`).
Future<SharedPreferences> mockPreferences(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// The app with an in-memory database and the given preferences. [overrides]
/// are added after the database and preferences overrides.
Widget testApp({
  required AppDatabase db,
  required SharedPreferences prefs,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
    child: const MyApp(),
  );
}

/// One screen under the same provider overrides as [testApp], without the
/// onboarding gate. Use it to test a form in isolation.
Widget testScreen({
  required AppDatabase db,
  required SharedPreferences prefs,
  required Widget home,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: CupertinoApp(home: home),
  );
}

/// A page with one button, key `open-route`, that pushes [route]. Lets a test
/// open a screen that pops back to a real page.
class RouteHost extends StatelessWidget {
  const RouteHost({super.key, required this.route});

  final WidgetBuilder route;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: CupertinoButton(
          key: const Key('open-route'),
          onPressed: () => Navigator.of(
            context,
          ).push(CupertinoPageRoute<void>(builder: route)),
          child: const Text('Open'),
        ),
      ),
    );
  }
}

/// Lets drift's real-time query streams deliver, then pumps the widget tree.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  // Long enough for a route transition (about 0.5 s) to finish.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Removes the widget tree and lets drift's stream cleanup timers finish, so
/// the test ends with no pending timers. Call at the end of each testWidgets.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump(const Duration(seconds: 1));
}

final _submitPreferences = find.byKey(const Key('submit-preferences'));

/// Scrolls the preferences form (onboarding or Settings) until its submit
/// button is built.
Future<void> scrollPreferencesToEnd(WidgetTester tester) =>
    scrollPreferencesTo(tester, _submitPreferences);

/// Scrolls the preferences form until [target] is built and on screen. A
/// negative [delta] scrolls back up.
Future<void> scrollPreferencesTo(
  WidgetTester tester,
  Finder target, {
  double delta = 200,
}) async {
  // The text fields contain their own Scrollables, so take the list's first.
  final scrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(target, delta, scrollable: scrollable);
}

/// Scrolls the preferences form until its submit button is built, then taps it.
Future<void> tapSubmitPreferences(WidgetTester tester) async {
  await scrollPreferencesToEnd(tester);
  // Stopping at the edge can leave the button under the tab bar.
  await tester.drag(
    find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, -80),
  );
  await tester.pump();
  await tester.tap(_submitPreferences);
}

/// Skips the onboarding welcome pages, leaving the setup form showing.
Future<void> skipWelcome(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('welcome-skip')));
  await settle(tester);
}
