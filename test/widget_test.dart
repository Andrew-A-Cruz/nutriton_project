import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('app launches with the three main tabs once onboarded', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final prefs = await tester.runAsync(
      () => mockPreferences({'onboarding_complete': true}),
    );

    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Catalog'), findsWidgets);
    expect(find.text('Summary'), findsWidgets);
    await unmount(tester);
    await tester.runAsync(db.close);
  });
}
