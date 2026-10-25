import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/body_weight.dart';
import 'package:nutriton_project/core/health.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/health/health_sync.dart';
import 'package:nutriton_project/data/repositories/body_weight_repository.dart';

import '../../support/fake_health_service.dart';

void main() {
  const today = '2026-10-21';
  late AppDatabase db;
  late BodyWeightRepository weights;
  late FakeHealthService service;
  late HealthSync sync;

  const lunch = Macros(calories: 600, protein: 40, carbs: 70, fat: 15);
  const dinner = Macros(calories: 900, protein: 50, carbs: 90, fat: 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    weights = BodyWeightRepository(db);
    service = FakeHealthService();
    sync = HealthSync(service, weights);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> nutrition(Map<String, Macros> totals, {bool enabled = true}) =>
      sync.syncNutrition(enabled: enabled, today: today, totals: totals);

  group('nutrition', () {
    test('disabled makes no calls', () async {
      await nutrition({today: lunch}, enabled: false);
      await nutrition({today: dinner}, enabled: false);

      expect(service.writes, isEmpty);
      expect(service.authorizations, isEmpty);
    });

    test(
      'turning it on backfills the window, days with entries only',
      () async {
        await nutrition(const {}, enabled: false);
        await nutrition({
          today: lunch,
          '2026-10-20': dinner,
          '2026-09-22': lunch, // 29 days back: the oldest day in the window
          '2026-09-21': lunch, // 30 days back: outside it
        });

        expect(
          service.writtenDates,
          unorderedEquals(['2026-09-22', '2026-10-20', today]),
        );
        expect(service.samplesFor(today), nutritionSamples(lunch));
        expect(service.samplesFor('2026-10-20'), nutritionSamples(dinner));
      },
    );

    test('at launch with it already on, only today is written', () async {
      await nutrition({today: lunch, '2026-10-20': dinner});

      expect(service.writtenDates, [today]);
    });

    test('repeating the same totals writes nothing more', () async {
      await nutrition(const {}, enabled: false);
      await nutrition({today: lunch, '2026-10-20': dinner});
      service.writes.clear();

      await nutrition({today: lunch, '2026-10-20': dinner});

      expect(service.writes, isEmpty);
    });

    test('adding or editing an entry rewrites only that day', () async {
      await nutrition(const {}, enabled: false);
      await nutrition({today: lunch, '2026-10-20': dinner});
      service.writes.clear();

      await nutrition({today: lunch + dinner, '2026-10-20': dinner});
      expect(service.writtenDates, [today]);
      expect(service.samplesFor(today), nutritionSamples(lunch + dinner));

      service.writes.clear();
      await nutrition({today: lunch + dinner, '2026-10-20': lunch});
      expect(service.writtenDates, ['2026-10-20']);
    });

    test('deleting the last entry of a day clears it once', () async {
      await nutrition(const {}, enabled: false);
      await nutrition({today: lunch, '2026-10-20': dinner});
      service.writes.clear();

      await nutrition({today: lunch});
      expect(service.writtenDates, ['2026-10-20']);
      expect(service.samplesFor('2026-10-20'), isEmpty);

      service.writes.clear();
      await nutrition({today: lunch});
      expect(service.writes, isEmpty);
    });

    test('turning it off and on again backfills again', () async {
      await nutrition(const {}, enabled: false);
      await nutrition({today: lunch, '2026-10-20': dinner});
      await nutrition({today: lunch, '2026-10-20': dinner}, enabled: false);
      service.writes.clear();

      await nutrition({today: lunch, '2026-10-20': dinner});

      expect(service.writtenDates, unorderedEquals(['2026-10-20', today]));
    });

    test('a failed day is retried on the next call', () async {
      final failing = _FailingOnce(service);
      sync = HealthSync(failing, weights);
      await nutrition(const {}, enabled: false);

      await expectLater(nutrition({today: lunch}), throwsA(isA<StateError>()));
      await nutrition({today: lunch});

      expect(service.writtenDates, [today]);
    });
  });

  group('body weight', () {
    Future<Map<String, (double, WeightSource)>> stored() async => {
      for (final r in await db.select(db.bodyWeights).get())
        r.logDate: (r.weightKg, WeightSource.fromDb(r.source)),
    };

    test('disabled reads nothing', () async {
      service.weights = [(date: today, kg: 80.0)];

      await sync.importWeights(enabled: false, today: today);

      expect(service.reads, isEmpty);
      expect(await stored(), isEmpty);
    });

    test('reads the last 90 days and fills empty days as health', () async {
      service.weights = [
        (date: '2026-10-20', kg: 80.4),
        (date: today, kg: 80.0),
        (date: '2026-07-22', kg: 85.0), // 91 days back: outside the range
      ];

      await sync.importWeights(enabled: true, today: today);

      expect(service.reads.single, (start: '2026-07-24', end: today));
      expect(await stored(), {
        '2026-10-20': (80.4, WeightSource.health),
        today: (80.0, WeightSource.health),
      });
    });

    test('never overwrites a manual weight', () async {
      await weights.setWeight(today, 79.0);
      service.weights = [(date: today, kg: 80.0), (date: '2026-10-20', kg: 81)];

      await sync.importWeights(enabled: true, today: today);

      expect(await stored(), {
        today: (79.0, WeightSource.manual),
        '2026-10-20': (81.0, WeightSource.health),
      });
    });

    test(
      'updates a health weight, and a manual edit makes it manual',
      () async {
        service.weights = [(date: today, kg: 80.0)];
        await sync.importWeights(enabled: true, today: today);

        service.weights = [(date: today, kg: 79.5)];
        await sync.importWeights(enabled: true, today: today);
        expect(await stored(), {today: (79.5, WeightSource.health)});

        await weights.setWeight(today, 79.2);
        service.weights = [(date: today, kg: 78.0)];
        await sync.importWeights(enabled: true, today: today);
        expect(await stored(), {today: (79.2, WeightSource.manual)});
      },
    );

    test('is idempotent', () async {
      service.weights = [(date: today, kg: 80.0)];
      await sync.importWeights(enabled: true, today: today);

      expect(await weights.importHealthReadings(service.weights), 0);
      await sync.importWeights(enabled: true, today: today);

      expect(await stored(), {today: (80.0, WeightSource.health)});
    });

    test('does not write weight back to the health store', () async {
      service.weights = [(date: today, kg: 80.0)];
      await sync.importWeights(enabled: true, today: today);
      await weights.setWeight('2026-10-20', 81);
      await nutrition({today: const Macros(calories: 100)});

      final types = service.writes.expand((w) => w.samples).map((s) => s.type);
      expect(types, [HealthNutrient.energy]);
    });
  });
}

/// Fails the first write, then passes calls on to [inner].
class _FailingOnce extends FakeHealthService {
  _FailingOnce(this.inner);

  final FakeHealthService inner;
  var _failed = false;

  @override
  Future<void> replaceDailyNutrition(
    String date,
    List<NutritionSample> samples,
  ) async {
    if (!_failed) {
      _failed = true;
      throw StateError('Health said no');
    }
    await inner.replaceDailyNutrition(date, samples);
  }
}
