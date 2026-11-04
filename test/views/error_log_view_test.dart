import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/diagnostics/error_log.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/providers/infrastructure_providers.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:nutriton_project/views/settings/error_log_view.dart';
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
    });
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Settings opens the error log, which starts empty', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-error-log')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open-error-log')));
    await settle(tester);

    expect(find.text('No errors recorded.'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    await unmount(tester);
  });

  testWidgets('lists entries, shows details, shares and clears', (
    tester,
  ) async {
    await tester.runAsync(
      () => ErrorLog(prefs).record(
        StateError('disk full'),
        StackTrace.fromString('#0 save'),
        context: 'Could not save',
      ),
    );
    String? shared;
    await tester.pumpWidget(
      testScreen(
        db: db,
        prefs: prefs,
        home: const ErrorLogView(),
        overrides: [
          textSharerProvider.overrideWithValue((String text, Rect? _) async {
            shared = text;
          }),
        ],
      ),
    );
    await settle(tester);

    expect(find.text('Could not save'), findsOneWidget);
    expect(find.textContaining('Bad state: disk full'), findsOneWidget);

    await tester.tap(find.text('Could not save'));
    await settle(tester);
    expect(find.textContaining('#0 save'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);

    await tester.tap(find.text('Share'));
    await settle(tester);
    expect(shared, contains('Bad state: disk full'));

    await tester.tap(find.byKey(const Key('clear-error-log')));
    await settle(tester);
    expect(find.text('No errors recorded.'), findsOneWidget);
    expect(ErrorLog(prefs).entries, isEmpty);
    await unmount(tester);
  });

  testWidgets('a failed save shows a plain message and records the error', (
    tester,
  ) async {
    await tester.pumpWidget(
      testScreen(
        db: db,
        prefs: prefs,
        home: const FoodFormView(),
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_FailingCatalog(db)),
        ],
      ),
    );
    await settle(tester);

    await tester.enterText(find.byKey(const Key('food-name')), 'Oats');
    await tester.enterText(find.byKey(const Key('food-calories')), '150');
    await tester.enterText(find.byKey(const Key('food-protein')), '5');
    await tester.enterText(find.byKey(const Key('food-carbs')), '27');
    await tester.enterText(find.byKey(const Key('food-fat')), '3');
    await tester.enterText(find.byKey(const Key('food-serving-weight')), '40');
    await tester.ensureVisible(find.byKey(const Key('food-save')));
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    // The message sits at the end of the form.
    await tester.scrollUntilVisible(
      find.text('Could not save. Try again.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('disk full'), findsNothing);
    final entry = ErrorLog(prefs).entries.single;
    expect(entry.context, 'Could not save');
    await unmount(tester);
  });
}

/// Every new food fails to save.
class _FailingCatalog extends CatalogRepository {
  _FailingCatalog(super.db);

  @override
  Future<String> createFood({
    required String name,
    required Macros perServing,
    required double servingWeightG,
    WeightUnit displayUnit = WeightUnit.g,
    String? barcode,
  }) => Future.error(StateError('disk full'));
}
