import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/views/home/undo_banner.dart';
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
    });
  });

  tearDown(() async {
    await db.close();
  });

  /// The haptic types sent to the platform, e.g. 'HapticFeedbackType.lightImpact'.
  List<String> recordHaptics(WidgetTester tester) {
    final types = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          types.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return types;
  }

  testWidgets('logging gives a light tap', (tester) async {
    final haptics = recordHaptics(tester);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.text('Quick add'));
    await settle(tester);
    expect(haptics, isEmpty);

    await tester.enterText(find.byKey(const Key('quick-calories')), '300');
    await tester.tap(find.byKey(const Key('quick-log')));
    await settle(tester);

    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await unmount(tester);
  });

  testWidgets('deleting gives a firmer tap', (tester) async {
    await tester.runAsync(
      () => LogRepository(db).logAdhoc(
        logDate: todayKey(),
        name: 'Protein bar',
        macros: const Macros(calories: 200, protein: 20, carbs: 22, fat: 7),
      ),
    );
    final haptics = recordHaptics(tester);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    await tester.drag(find.byType(Dismissible).first, const Offset(-500, 0));
    await tester.pump();
    await settle(tester);
    await settle(tester);

    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    // Let the undo banner time out, so no timer is left.
    await tester.pump(undoBannerDuration + const Duration(milliseconds: 100));
    await unmount(tester);
  });
}
