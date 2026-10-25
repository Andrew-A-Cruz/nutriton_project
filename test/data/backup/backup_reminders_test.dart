import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/reminder.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reminder settings (M14) in backups. The format version stays at 1: the
/// "reminders" key is optional on read.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late UserPreferences prefs;
  late BackupRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = UserPreferences(await SharedPreferences.getInstance());
    db = AppDatabase(NativeDatabase.memory());
    repo = BackupRepository(db, prefs);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Map<String, dynamic>> export() async =>
      jsonDecode(await repo.exportJson()) as Map<String, dynamic>;

  test('reminders round-trip through a backup', () async {
    await prefs.write(
      prefs.read().copyWith(
        reminders: const [
          Reminder(minutes: 7 * 60 + 15, enabled: true),
          Reminder(minutes: 12 * 60),
          Reminder(minutes: 21 * 60, enabled: true),
        ],
      ),
    );
    final json = await export();
    expect(json['version'], 1);

    // Wipe the stored reminders, then restore from the file.
    await prefs.write(prefs.read().copyWith(reminders: Reminder.defaults));
    final restored = await repo.importJson(jsonEncode(json));

    expect(restored.reminders, [
      const Reminder(minutes: 7 * 60 + 15, enabled: true),
      const Reminder(minutes: 12 * 60),
      const Reminder(minutes: 21 * 60, enabled: true),
    ]);
    expect(prefs.read().reminders, restored.reminders);
  });

  test('a backup from before reminders imports with all off', () async {
    final json =
        jsonDecode(
              File(
                'test/data/backup/fixtures/backup_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect((json['preferences'] as Map).containsKey('reminders'), isFalse);

    final restored = await repo.importJson(jsonEncode(json));
    expect(restored.reminders, Reminder.defaults);
    expect(restored.reminders.every((r) => !r.enabled), isTrue);
  });

  test('malformed reminders are rejected', () async {
    final json = await export();
    (json['preferences'] as Map)['reminders'] = [
      {'enabled': true, 'minutes': 5000},
    ];
    await expectLater(
      repo.importJson(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test(
    'preferences keep reminders across a reload, and bad values reset',
    () async {
      await prefs.write(
        prefs.read().copyWith(
          reminders: const [
            Reminder(minutes: 8 * 60, enabled: true),
            Reminder(minutes: 13 * 60),
            Reminder(minutes: 19 * 60),
          ],
        ),
      );
      expect(
        prefs.read().reminders.first,
        const Reminder(minutes: 480, enabled: true),
      );

      SharedPreferences.setMockInitialValues({'reminder_1_minutes': 99999});
      final bad = UserPreferences(await SharedPreferences.getInstance());
      expect(bad.read().reminders[1].minutes, Reminder.defaults[1].minutes);
    },
  );
}
