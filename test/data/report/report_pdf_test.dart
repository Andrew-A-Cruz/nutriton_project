import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/body_weight.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/core/report.dart';
import 'package:nutriton_project/data/report/report_pdf.dart';

void main() {
  ShareableReport sample({
    List<({String date, double kg})> weights = const [],
  }) => buildReport(
    startKey: '2026-10-01',
    endKey: '2026-10-07',
    days: {
      '2026-10-02': const Macros(
        calories: 1800,
        protein: 90,
        carbs: 200,
        fat: 60,
      ),
      '2026-10-05': const Macros(
        calories: 2200,
        protein: 110,
        carbs: 200,
        fat: 60,
      ),
    },
    metrics: const [Metric.calories, Metric.protein],
    goals: const {Metric.calories: 2000},
    weights: weights,
  );

  /// The PDF's words in order, joined by spaces. Uncompressed, each word is
  /// a literal string in a TJ operator.
  Future<String> render(
    ShareableReport r, {
    BodyWeightUnit unit = BodyWeightUnit.kg,
  }) async {
    final bytes = await renderReportPdf(
      r,
      unit: unit,
      generatedOn: DateTime(2026, 11, 8),
      compress: false,
    );
    final raw = latin1.decode(bytes);
    expect(raw, startsWith('%PDF'));
    final words = RegExp(r'\[\(((?:\\.|[^\\)])*)\)\]TJ')
        .allMatches(raw)
        .map(
          (m) => m
              .group(1)!
              .replaceAllMapped(RegExp(r'\\(.)'), (e) => e.group(1)!),
        );
    return words.join(' ');
  }

  test('is a PDF with the range, averages, goal and daily totals', () async {
    final text = await render(sample());
    for (final s in [
      'Nutrition report',
      'Oct 1, 2026 - Oct 7, 2026',
      'Days logged: 2 of 7',
      'Calories',
      '2000 kcal',
      '100%',
      '2 of 2',
      '100.0 g',
      'Fri, Oct 2',
      '1800',
      '2200',
      'No weigh-ins in this period.',
      'Made with Logbite on Nov 8, 2026',
    ]) {
      expect(text, contains(s), reason: s);
    }
  });

  test('summarises the weight change in the chosen unit', () async {
    final text = await render(
      sample(
        weights: const [
          (date: '2026-10-02', kg: 80.5),
          (date: '2026-10-06', kg: 79.0),
        ],
      ),
    );
    expect(text, contains('80.5 kg on Oct 2 to 79 kg on Oct 6'));
    expect(text, contains('change: -1.5 kg, 2 weigh-ins'));
  });

  test('weight summary wording', () {
    expect(
      weightSummary(null, BodyWeightUnit.kg),
      'No weigh-ins in this period.',
    );
    const one = ReportWeight(
      first: (date: '2026-10-02', kg: 80),
      last: (date: '2026-10-02', kg: 80),
      count: 1,
    );
    expect(
      weightSummary(one, BodyWeightUnit.kg),
      '80 kg on Oct 2 (1 weigh-in).',
    );
    const gain = ReportWeight(
      first: (date: '2026-10-02', kg: 80),
      last: (date: '2026-10-06', kg: 81),
      count: 3,
    );
    expect(
      weightSummary(gain, BodyWeightUnit.lb),
      '176.4 lb on Oct 2 to 178.6 lb on Oct 6 (change: +2.2 lb, 3 weigh-ins).',
    );
  });
}
