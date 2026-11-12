import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/fasting_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backups and the fasts table and switch (schema v13). The backup format
/// version stays at 1: `fasts` and `fastingEnabled` are optional on read.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase source;
  late AppDatabase target;
  late UserPreferences prefs;
  late BackupRepository sourceRepo;
  late BackupRepository targetRepo;
  final start = DateTime(2026, 11, 10, 20);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = UserPreferences(await SharedPreferences.getInstance());
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
    sourceRepo = BackupRepository(source, prefs);
    targetRepo = BackupRepository(target, prefs);
    final fasting = FastingRepository(source);
    await fasting.start(start);
    await fasting.end(start.add(const Duration(hours: 16)));
    // One still running.
    await fasting.start(start.add(const Duration(days: 1)));
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, dynamic>> export() async =>
      jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;

  test('the file carries fasts and the switch; version stays 1', () async {
    final json = await export();
    expect(json['version'], 1);
    expect(json['fasts'], hasLength(2));
    expect((json['preferences'] as Map)['fastingEnabled'], isFalse);
  });

  test('round trip restores fasts, the running one and the switch', () async {
    await prefs.write(
      UserSettings(onboardingComplete: true, fastingEnabled: true),
    );
    await FastingRepository(target).start(DateTime(2026, 9, 1));

    final settings = await targetRepo.importJson(await sourceRepo.exportJson());

    expect(settings.fastingEnabled, isTrue);
    final fasts = await target.select(target.fasts).get();
    expect(fasts, hasLength(2));
    expect(
      (await FastingRepository(target).watchActive().first)!.startedAt,
      start.add(const Duration(days: 1)),
    );
    final done = (await FastingRepository(target).watchFinished().first).single;
    expect(done.endedAt!.difference(done.startedAt), const Duration(hours: 16));
  });

  test('a file without fasting imports with none, switched off', () async {
    final json = await export();
    json.remove('fasts');
    (json['preferences'] as Map).remove('fastingEnabled');
    await FastingRepository(target).start(DateTime(2026, 9, 1));

    final settings = await targetRepo.importJson(jsonEncode(json));

    expect(settings.fastingEnabled, isFalse);
    expect(await target.select(target.fasts).get(), isEmpty);
  });

  test('the real version 1 fixture still imports', () async {
    final text = File(
      'test/data/backup/fixtures/backup_v1.json',
    ).readAsStringSync();

    final settings = await targetRepo.importJson(text);

    expect(settings.fastingEnabled, isFalse);
    expect(await target.select(target.fasts).get(), isEmpty);
  });

  test('a bad switch or row is rejected', () async {
    final badSwitch = await export();
    (badSwitch['preferences'] as Map)['fastingEnabled'] = 'yes';
    expect(
      () => const BackupCodec().decode(jsonEncode(badSwitch)),
      throwsA(isA<BackupException>()),
    );
    final badRows = await export();
    badRows['fasts'] = ['nope'];
    expect(
      () => const BackupCodec().decode(jsonEncode(badRows)),
      throwsA(isA<BackupException>()),
    );
  });

  test('a fast that ends before it starts fails the import', () async {
    final json = await export();
    final row = (json['fasts'] as List).first as Map;
    row['endedAt'] = (row['startedAt'] as int) - 1000;
    await FastingRepository(target).start(DateTime(2026, 9, 1));

    await expectLater(
      targetRepo.importJson(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
    expect(await target.select(target.fasts).get(), hasLength(1));
  });
}
