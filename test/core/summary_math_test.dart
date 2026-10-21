import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/core/summary_math.dart';

DayTotal day(String key, double calories) => DayTotal(
  logDate: key,
  totals: Macros(calories: calories, protein: calories / 10),
);

void main() {
  group('windowStart', () {
    test('a 7-day window ending today starts six days back', () {
      expect(windowStart('2026-10-20', 7), '2026-10-14');
    });

    test('a 1-day window is just the end day', () {
      expect(windowStart('2026-10-20', 1), '2026-10-20');
    });

    test('a 365-day window spans a non-leap year exactly', () {
      expect(windowStart('2026-10-20', 365), '2025-10-21');
    });

    test('crosses the end of February in a leap year', () {
      expect(windowStart('2024-03-01', 3), '2024-02-28');
      expect(windowStart('2024-03-01', 2), '2024-02-29');
    });

    test('rejects a window shorter than one day', () {
      expect(() => windowStart('2026-10-20', 0), throwsArgumentError);
    });
  });

  group('SummaryRange', () {
    test('lengths match the spec', () {
      expect(SummaryRange.day.days, 1);
      expect(SummaryRange.week.days, 7);
      expect(SummaryRange.month.days, 30);
      expect(SummaryRange.sixMonths.days, 180);
      expect(SummaryRange.year.days, 365);
    });

    test('long ranges are bucketed by week or month', () {
      expect(SummaryRange.week.bucketSize, BucketSize.day);
      expect(SummaryRange.month.bucketSize, BucketSize.day);
      expect(SummaryRange.sixMonths.bucketSize, BucketSize.week);
      expect(SummaryRange.year.bucketSize, BucketSize.month);
    });
  });

  group('averageOverLoggedDays', () {
    test('is null when there are no days', () {
      expect(averageOverLoggedDays(const []), isNull);
    });

    test('divides each macro by the number of days given', () {
      final avg = averageOverLoggedDays(const [
        Macros(calories: 1000, protein: 50, carbs: 10, fat: 1),
        Macros(calories: 2000, protein: 70, carbs: 30, fat: 3),
      ])!;
      expect(avg.calories, 1500);
      expect(avg.protein, 60);
      expect(avg.carbs, 20);
      expect(avg.fat, 2);
    });
  });

  group('bucketSpans', () {
    test('day buckets are one per day', () {
      expect(
        bucketSpans(
          start: '2026-10-19',
          end: '2026-10-20',
          size: BucketSize.day,
        ),
        [('2026-10-19', '2026-10-19'), ('2026-10-20', '2026-10-20')],
      );
    });

    test(
      'week buckets count 7 days back from the end; the oldest may be short',
      () {
        expect(
          bucketSpans(
            start: '2026-10-01',
            end: '2026-10-10',
            size: BucketSize.week,
          ),
          [('2026-10-01', '2026-10-03'), ('2026-10-04', '2026-10-10')],
        );
      },
    );

    test('month buckets are calendar months, clipped to the range', () {
      expect(
        bucketSpans(
          start: '2024-02-15',
          end: '2024-03-10',
          size: BucketSize.month,
        ),
        [('2024-02-15', '2024-02-29'), ('2024-03-01', '2024-03-10')],
      );
    });

    test('rejects a start after the end', () {
      expect(
        () => bucketSpans(
          start: '2026-10-20',
          end: '2026-10-19',
          size: BucketSize.day,
        ),
        throwsArgumentError,
      );
    });
  });

  group('buildSummaryReport', () {
    test('week: averages over logged days only, skipped days do not count', () {
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.week,
        days: [day('2026-10-14', 1000), day('2026-10-20', 2000)],
      );

      expect(report.startKey, '2026-10-14');
      expect(report.endKey, '2026-10-20');
      expect(report.totalDays, 7);
      expect(report.daysLogged, 2);
      expect(report.averages!.calories, 1500);
      expect(report.averages!.protein, 150);
    });

    test('week: the day before the window is excluded', () {
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.week,
        days: [day('2026-10-13', 9999), day('2026-10-21', 9999)],
      );

      expect(report.daysLogged, 0);
      expect(report.averages, isNull);
    });

    test('several entries on one day are summed before averaging', () {
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.week,
        days: [
          day('2026-10-19', 300),
          day('2026-10-19', 200),
          day('2026-10-20', 1000),
        ],
      );

      // Day totals are 500 (300 + 200) and 1000; the mean over two days is 750.
      expect(report.daysLogged, 2);
      expect(report.averages!.calories, 750);
    });

    test('day range: one day, no bars', () {
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.day,
        days: [day('2026-10-19', 500), day('2026-10-20', 800)],
      );

      expect(report.startKey, '2026-10-20');
      expect(report.totalDays, 1);
      expect(report.daysLogged, 1);
      expect(report.averages!.calories, 800);
      expect(report.buckets, isEmpty);
    });

    test('week range: one bar per day, empty days have no averages', () {
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.week,
        days: [day('2026-10-18', 1200)],
      );

      expect(report.buckets, hasLength(7));
      expect(report.buckets.every((b) => b.dayCount == 1), isTrue);
      final logged = report.buckets.where((b) => b.daysLogged > 0);
      expect(logged.single.startKey, '2026-10-18');
      expect(logged.single.averages!.calories, 1200);
      expect(report.buckets.first.averages, isNull);
    });

    test('six-month range: weekly buckets covering all 180 days', () {
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.sixMonths,
        days: const [],
      );

      expect(report.buckets, hasLength(26));
      expect(report.buckets.first.startKey, report.startKey);
      expect(report.buckets.last.endKey, '2026-10-20');
      expect(report.buckets.fold(0, (sum, b) => sum + b.dayCount), 180);
      // The newest week is complete; the partial week is the oldest.
      expect(report.buckets.last.dayCount, 7);
      expect(report.buckets.first.dayCount, 5);
    });

    test('year range: calendar-month buckets covering all 365 days', () {
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.year,
        days: const [],
      );

      expect(report.buckets, hasLength(13));
      expect(report.buckets.first.startKey, '2025-10-21');
      expect(report.buckets.first.endKey, '2025-10-31');
      expect(report.buckets[1].startKey, '2025-11-01');
      expect(report.buckets[1].endKey, '2025-11-30');
      expect(report.buckets.last.startKey, '2026-10-01');
      expect(report.buckets.last.endKey, '2026-10-20');
      expect(report.buckets.fold(0, (sum, b) => sum + b.dayCount), 365);
    });

    test('bucket averages are per logged day within that bucket', () {
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.sixMonths,
        days: [
          // Week of 2026-10-14..2026-10-20: two logged days.
          day('2026-10-14', 1000),
          day('2026-10-20', 2000),
          // Week of 2026-10-07..2026-10-13: one logged day.
          day('2026-10-07', 600),
        ],
      );

      final last = report.buckets.last;
      expect(last.startKey, '2026-10-14');
      expect(last.daysLogged, 2);
      expect(last.averages!.calories, 1500);

      final previous = report.buckets[report.buckets.length - 2];
      expect(previous.startKey, '2026-10-07');
      expect(previous.daysLogged, 1);
      expect(previous.averages!.calories, 600);
    });

    test('the overall average is over logged days, not bucket averages', () {
      // Week one: 1 logged day at 100. Week two: 3 logged days at 500.
      // Mean of the 4 logged days is 400; mean of bucket means would be 300.
      final report = buildSummaryReport(
        endKey: '2026-10-20',
        range: SummaryRange.sixMonths,
        days: [
          day('2026-10-07', 100),
          day('2026-10-14', 500),
          day('2026-10-15', 500),
          day('2026-10-16', 500),
        ],
      );

      expect(report.daysLogged, 4);
      expect(report.averages!.calories, 400);
    });
  });
}
