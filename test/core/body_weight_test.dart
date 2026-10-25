import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/body_weight.dart';

WeightReading r(String date, double kg) => (date: date, kg: kg);

void main() {
  group('unit conversion', () {
    test('kg is the identity', () {
      expect(BodyWeightUnit.kg.toKg(80), 80);
      expect(BodyWeightUnit.kg.fromKg(80), 80);
    });

    test('lb uses 0.45359237 kg per pound', () {
      expect(BodyWeightUnit.lb.toKg(100), closeTo(45.359237, 1e-9));
      expect(BodyWeightUnit.lb.fromKg(45.359237), closeTo(100, 1e-9));
    });

    test('lb round trips', () {
      expect(
        BodyWeightUnit.lb.fromKg(BodyWeightUnit.lb.toKg(176.4)),
        closeTo(176.4, 1e-9),
      );
    });
  });

  group('formatBodyWeight', () {
    test('rounds to one decimal and drops a trailing zero', () {
      expect(formatBodyWeight(80.54, BodyWeightUnit.kg), '80.5 kg');
      expect(formatBodyWeight(80, BodyWeightUnit.kg), '80 kg');
    });

    test('converts to pounds', () {
      expect(formatBodyWeight(80, BodyWeightUnit.lb), '176.4 lb');
      expect(formatBodyWeightValue(80, BodyWeightUnit.lb), '176.4');
    });
  });

  group('validateBodyWeight', () {
    test('accepts a normal weight in either unit', () {
      expect(validateBodyWeight('80.5', BodyWeightUnit.kg), isNull);
      expect(validateBodyWeight(' 177 ', BodyWeightUnit.lb), isNull);
    });

    test('rejects text, zero and negatives', () {
      expect(validateBodyWeight('', BodyWeightUnit.kg), 'Enter a number');
      expect(validateBodyWeight('abc', BodyWeightUnit.kg), 'Enter a number');
      expect(validateBodyWeight('NaN', BodyWeightUnit.kg), 'Enter a number');
      expect(validateBodyWeight('0', BodyWeightUnit.kg), isNotNull);
      expect(validateBodyWeight('-5', BodyWeightUnit.kg), isNotNull);
    });

    test('bounds are checked in kilograms, whatever the unit', () {
      expect(validateBodyWeight('19.9', BodyWeightUnit.kg), isNotNull);
      expect(validateBodyWeight('20', BodyWeightUnit.kg), isNull);
      expect(validateBodyWeight('500', BodyWeightUnit.kg), isNull);
      expect(validateBodyWeight('500.1', BodyWeightUnit.kg), isNotNull);
      // 44 lb is 19.96 kg, 45 lb is 20.41 kg.
      expect(validateBodyWeight('44', BodyWeightUnit.lb), isNotNull);
      expect(validateBodyWeight('45', BodyWeightUnit.lb), isNull);
    });

    test('the range message is in the chosen unit', () {
      expect(
        validateBodyWeight('5', BodyWeightUnit.lb),
        'Enter a weight between 44.1 and 1102.3 lb',
      );
    });
  });

  group('movingAverage', () {
    test('no readings gives no points', () {
      expect(movingAverage([]), isEmpty);
    });

    test('a single reading averages to itself', () {
      expect(movingAverage([r('2026-10-20', 80)]), [r('2026-10-20', 80)]);
    });

    test('fewer than seven readings average over those available', () {
      final out = movingAverage([
        r('2026-10-20', 80),
        r('2026-10-21', 82),
        r('2026-10-22', 81),
      ]);
      expect(out.map((p) => p.date), [
        '2026-10-20',
        '2026-10-21',
        '2026-10-22',
      ]);
      expect(out[0].kg, 80);
      expect(out[1].kg, 81);
      expect(out[2].kg, 81);
    });

    test('the window is the reading day and the six before it', () {
      final readings = [
        for (var d = 14; d <= 21; d++) r('2026-10-$d', d.toDouble()),
      ];
      final out = movingAverage(readings);
      // Oct 20 sees 14..20, Oct 21 sees 15..21 (Oct 14 has dropped out).
      expect(out[6].kg, closeTo(17, 1e-9));
      expect(out[7].kg, closeTo(18, 1e-9));
    });

    test('days without a reading are skipped, not counted as zero', () {
      final out = movingAverage([
        r('2026-10-14', 80),
        r('2026-10-17', 82),
        r('2026-10-20', 84),
      ]);
      expect(out[2].kg, closeTo(82, 1e-9));
    });

    test('a gap longer than the window starts fresh', () {
      final out = movingAverage([
        r('2026-10-01', 90),
        r('2026-10-02', 90),
        r('2026-10-20', 80),
      ]);
      expect(out[2].kg, 80);
    });

    test('the window crosses a month and year boundary', () {
      final out = movingAverage([
        r('2026-12-30', 80),
        r('2026-12-31', 82),
        r('2027-01-02', 84),
      ]);
      expect(out[2].kg, closeTo(82, 1e-9));
    });

    test('a custom window length', () {
      final out = movingAverage([
        r('2026-10-20', 80),
        r('2026-10-21', 82),
        r('2026-10-22', 84),
      ], windowDays: 2);
      expect(out.map((p) => p.kg), [80, 81, 83]);
    });

    test('rejects a window shorter than one day', () {
      expect(() => movingAverage([], windowDays: 0), throwsArgumentError);
    });

    test('averages are in kilograms, so converting after matches', () {
      final out = movingAverage([r('2026-10-20', 80), r('2026-10-21', 82)]);
      expect(BodyWeightUnit.lb.fromKg(out[1].kg), closeTo(178.57, 0.01));
    });
  });
}
