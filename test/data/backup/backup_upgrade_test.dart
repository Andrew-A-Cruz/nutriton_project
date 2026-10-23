import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fixturePath = 'test/data/backup/fixtures/backup_v1.json';

// Ids from the v1 fixture.
const _riceId = '9b43d1da-fbae-4c85-a93a-7e033c28a1db';
const _lunchId = 'aca79285-753d-4223-87a3-8825e5788c89';
const _foodEntryId = '9a7d20d2-9148-429d-aa16-188508c73f8c';
const _adhocEntryId = '11250835-a54b-4806-924b-81f0d29458b4';
const _lunchEntry1020Id = '34ac0ca9-37b3-4e0c-a834-e64c4ff38947';
const _lunchEntry1021Id = '2944d383-b7d5-4294-8619-19b0df47cfa2';
const _repeatingPlanId = 'bbd6a628-3548-45ad-bce7-298abcc2660b';
const _oneOffPlanId = 'f2654205-e3b7-4100-a0b7-595cb2441250';

const _damaged = 'The backup is damaged or has unexpected data.';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const codec = BackupCodec();

  Map<String, dynamic> fixtureJson() =>
      jsonDecode(File(_fixturePath).readAsStringSync())
          as Map<String, dynamic>;

  Map<String, dynamic> copy(Map<String, dynamic> json) =>
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

  BackupException failure(Object? json) {
    try {
      codec.decode(json is String ? json : jsonEncode(json));
    } on BackupException catch (e) {
      return e;
    }
    fail('expected a BackupException');
  }

  group('a v1 backup from disk', () {
    late AppDatabase target;
    late UserPreferences userPrefs;
    late BackupRepository targetRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      userPrefs = UserPreferences(prefs);
      target = AppDatabase(NativeDatabase.memory());
      targetRepo = BackupRepository(target, userPrefs);
    });

    tearDown(() async {
      await target.close();
    });

    test('restores every table and the preferences', () async {
      final json = File(_fixturePath).readAsStringSync();

      final settings = await targetRepo.importJson(json);

      expect(await target.select(target.foodItems).get(), hasLength(1));
      expect(await target.select(target.meals).get(), hasLength(1));
      expect(await target.select(target.mealFoodItems).get(), hasLength(1));
      expect(await target.select(target.foodLogEntries).get(), hasLength(4));
      expect(await target.select(target.foodLogEntryItems).get(), hasLength(2));
      expect(await target.select(target.scheduledMeals).get(), hasLength(2));
      expect(
        await target.select(target.scheduledMealOutcomes).get(),
        hasLength(1),
      );

      expect(settings.onboardingComplete, isTrue);
      expect(settings.primaryMetric, Metric.protein);
      expect(settings.trackedMetrics, {Metric.protein, Metric.carbs});
      expect(settings.displayUnit, WeightUnit.oz);
      expect(settings.goals, {Metric.protein: 140, Metric.carbs: 250});
      expect(userPrefs.read().goals, {Metric.protein: 140, Metric.carbs: 250});
    });

    test('restores the food, meal and breakdown values', () async {
      await targetRepo.importJson(File(_fixturePath).readAsStringSync());

      final rice = (await target.foodDao.findById(_riceId))!;
      expect(rice.name, 'Rice');
      expect(rice.calories, 130);
      expect(rice.servingWeightG, 100);

      final lunch = (await target.mealDao.findById(_lunchId))!;
      expect(lunch.name, 'Lunch');

      final item = await target.select(target.mealFoodItems).getSingle();
      expect(item.mealId, _lunchId);
      expect(item.foodItemId, _riceId);
      expect(item.weightG, 200);

      final breakdown = await target.select(target.foodLogEntryItems).get();
      expect(
        breakdown.map((r) => (r.entryId, r.weightG)),
        unorderedEquals([
          (_lunchEntry1020Id, 150.0),
          (_lunchEntry1021Id, 200.0),
        ]),
      );
    });

    test('restores the log entries with their dates and kcal', () async {
      await targetRepo.importJson(File(_fixturePath).readAsStringSync());

      final entries = {
        for (final e in await target.select(target.foodLogEntries).get())
          e.id: e,
      };

      final food = entries[_foodEntryId]!;
      expect(food.logDate, '2026-10-20');
      expect(food.entryType, 'food');
      expect(food.calories, 195);
      expect(food.servings, 1.5);
      expect(food.foodItemId, _riceId);
      expect(food.createdAt.millisecondsSinceEpoch, 1792719684000);

      final adhoc = entries[_adhocEntryId]!;
      expect(adhoc.logDate, '2026-10-20');
      expect(adhoc.entryType, 'adhoc');
      expect(adhoc.name, 'Snack');
      expect(adhoc.calories, 90);
      expect(adhoc.foodItemId, isNull);
      expect(adhoc.mealId, isNull);

      final lunch20 = entries[_lunchEntry1020Id]!;
      expect(lunch20.logDate, '2026-10-20');
      expect(lunch20.entryType, 'meal');
      expect(lunch20.calories, 195);
      expect(lunch20.mealId, _lunchId);

      final lunch21 = entries[_lunchEntry1021Id]!;
      expect(lunch21.logDate, '2026-10-21');
      expect(lunch21.calories, 260);
      expect(lunch21.protein, 6);
    });

    test('restores the schedules and the confirmed outcome link', () async {
      await targetRepo.importJson(File(_fixturePath).readAsStringSync());

      final plans = {
        for (final p in await target.select(target.scheduledMeals).get())
          p.id: p,
      };
      expect(plans[_repeatingPlanId]!.startDate, '2026-10-19');
      expect(plans[_repeatingPlanId]!.weekdays, 5);
      expect(plans[_oneOffPlanId]!.startDate, '2026-10-25');
      expect(plans[_oneOffPlanId]!.weekdays, isNull);

      final outcome = await target
          .select(target.scheduledMealOutcomes)
          .getSingle();
      expect(outcome.scheduledMealId, _repeatingPlanId);
      expect(outcome.date, '2026-10-21');
      expect(outcome.status, 'logged');
      expect(outcome.entryId, _lunchEntry1021Id);
    });
  });

  group('upgradeBackupJson', () {
    test('the runner does not mutate the root map it is given', () {
      final root = {
        'version': 1,
        'rows': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      };
      final before = copy(root);

      final out = upgradeBackupJson(
        root,
        fromVersion: 1,
        toVersion: 2,
        upgrades: {
          1: (r) => {
            ...r,
            'rows': [
              for (final row in r['rows'] as List)
                {...(row as Map<String, dynamic>), 'color': 0},
            ],
          },
        },
      );

      expect(out['version'], 2);
      expect(out['rows'], [
        {'id': 'a', 'color': 0},
        {'id': 'b', 'color': 0},
      ]);
      expect(root, before);
    });

    test('chained steps run in order, 1 -> 2 -> 3', () {
      final out = upgradeBackupJson(
        {'version': 1, 'trail': <String>[]},
        fromVersion: 1,
        toVersion: 3,
        upgrades: {
          1: (r) => {
            ...r,
            'trail': [...(r['trail'] as List), 'v1->v2'],
          },
          2: (r) => {
            ...r,
            'trail': [...(r['trail'] as List), 'v2->v3'],
          },
        },
      );

      expect(out['version'], 3);
      expect(out['trail'], ['v1->v2', 'v2->v3']);
    });

    test('a missing step throws a BackupException', () {
      expect(
        () => upgradeBackupJson(
          {'version': 1},
          fromVersion: 1,
          toVersion: 3,
          upgrades: {1: (r) => {...r}},
        ),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            'This backup (format 2) can no longer be read.',
          ),
        ),
      );
    });

    test('fromVersion equal to toVersion returns the input unchanged', () {
      final root = {'version': 1, 'app': 'nutriton'};
      final out = upgradeBackupJson(
        root,
        fromVersion: 1,
        toVersion: 1,
        upgrades: const {},
      );
      expect(identical(out, root), isTrue);
      expect(out, {'version': 1, 'app': 'nutriton'});
    });

    test('fromVersion above toVersion also returns the input unchanged', () {
      final root = {'version': 5};
      final out = upgradeBackupJson(
        root,
        fromVersion: 5,
        toVersion: 2,
        upgrades: const {},
      );
      expect(identical(out, root), isTrue);
    });
  });

  group('decode runs the upgrade pipeline', () {
    test('a v1 file goes through the registered step before parsing', () {
      var ran = 0;
      final versionsSeen = <int>[];
      final upgraded = BackupCodec(
        currentVersion: 2,
        upgrades: {
          1: (root) {
            ran++;
            final prefs = Map<String, dynamic>.of(
              root['preferences'] as Map<String, dynamic>,
            );
            prefs['displayUnit'] = 'g';
            versionsSeen.add(root['version'] as int);
            return {...root, 'preferences': prefs};
          },
        },
      ).decode(File(_fixturePath).readAsStringSync());

      expect(ran, 1);
      expect(versionsSeen, [1]);
      expect(upgraded.settings.displayUnit, WeightUnit.g);
      expect(upgraded.foodItems, hasLength(1));
      expect(upgraded.logEntries, hasLength(4));
    });

    test('a step that throws is reported as damaged', () {
      final codec = BackupCodec(
        currentVersion: 2,
        upgrades: {1: (_) => throw StateError('boom')},
      );
      expect(
        () => codec.decode(File(_fixturePath).readAsStringSync()),
        throwsA(
          isA<BackupException>().having((e) => e.message, 'message', _damaged),
        ),
      );
    });

    test('a v1 file with no step to version 2 says it cannot be read', () {
      final codec = BackupCodec(currentVersion: 2, upgrades: const {});
      expect(
        () => codec.decode(File(_fixturePath).readAsStringSync()),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            'This backup (format 1) can no longer be read.',
          ),
        ),
      );
    });

    test('a file at the current version is accepted without steps', () {
      final json = fixtureJson()..['version'] = 2;
      final out = BackupCodec(
        currentVersion: 2,
        upgrades: const {},
      ).decode(jsonEncode(json));
      expect(out.foodItems, hasLength(1));
    });

    test('a version above the codec current version is rejected as newer', () {
      final json = fixtureJson()..['version'] = 3;
      expect(
        () => BackupCodec(
          currentVersion: 2,
          upgrades: const {},
        ).decode(jsonEncode(json)),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('(format 3). Update the app'),
          ),
        ),
      );
    });
  });

  group('decode errors not covered by backup_codec_test', () {
    test('a row missing a non-null column is damaged', () {
      final json = copy(fixtureJson());
      ((json['food_items'] as List).first as Map).remove('name');
      expect(failure(json).message, _damaged);
    });

    test('a row missing a nullable column parses with null there', () {
      final json = copy(fixtureJson());
      final food =
          (json['food_log_entries'] as List).first as Map<String, dynamic>;
      expect(food['id'], _foodEntryId);
      food.remove('servings');
      food.remove('foodItemId');

      final out = codec.decode(jsonEncode(json));

      final row = out.logEntries.firstWhere((e) => e.id == _foodEntryId);
      expect(row.servings, isNull);
      expect(row.foodItemId, isNull);
      expect(row.calories, 195);
    });
  });
}
