import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/body_weight.dart';
import '../../core/date_key.dart';
import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/report.dart';
import '../../core/summary_math.dart';

/// Lays out [report] as a PDF: the range, averages against goals, body
/// weight, and a table of daily totals. [unit] is the body weight unit and
/// [generatedOn] the day printed in the footer. [compress] is off in tests so
/// the text can be read back.
///
/// Uses the PDF standard fonts, which cover Latin-1 only, so every string
/// here is plain ASCII (no en dashes).
Future<Uint8List> renderReportPdf(
  ShareableReport report, {
  required BodyWeightUnit unit,
  required DateTime generatedOn,
  bool compress = true,
}) {
  final doc = pw.Document(
    compress: compress,
    title: 'Logbite report, ${reportPeriod(report)}',
    creator: 'Logbite',
  );
  const small = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(40),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Made with Logbite on ${DateFormat.yMMMd().format(generatedOn)}. '
            'Values are as logged.',
            style: small,
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: small,
          ),
        ],
      ),
      build: (context) => [
        pw.Text(
          'Nutrition report',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(reportPeriod(report), style: const pw.TextStyle(fontSize: 13)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Days logged: ${report.daysLogged} of ${report.totalDays}. '
          'Averages are per logged day; days with nothing logged are left out.',
          style: small,
        ),
        pw.SizedBox(height: 16),
        _heading('Daily averages'),
        if (report.daysLogged == 0)
          pw.Text('Nothing logged in this period.')
        else
          _averagesTable(report),
        pw.SizedBox(height: 16),
        _heading('Body weight'),
        pw.Text(weightSummary(report.weight, unit)),
        if (report.days.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _heading('Daily totals'),
          _dailyTable(report),
        ],
      ],
    ),
  );
  return doc.save();
}

/// "Oct 10, 2026 - Nov 8, 2026", or one date for a one-day report.
String reportPeriod(ShareableReport report) {
  final f = DateFormat.yMMMd();
  final start = f.format(dateFromKey(report.startKey));
  if (report.startKey == report.endKey) return start;
  return '$start - ${f.format(dateFromKey(report.endKey))}';
}

/// One sentence on the weigh-ins in the range.
String weightSummary(ReportWeight? weight, BodyWeightUnit unit) {
  if (weight == null) return 'No weigh-ins in this period.';
  final f = DateFormat.MMMd();
  final first = formatBodyWeight(weight.first.kg, unit);
  if (weight.count == 1) {
    return '$first on ${f.format(dateFromKey(weight.first.date))} '
        '(1 weigh-in).';
  }
  final last = formatBodyWeight(weight.last.kg, unit);
  // From the rounded readings, so the change matches the numbers shown.
  final change = roundTo(
    roundTo(unit.fromKg(weight.last.kg), 1) -
        roundTo(unit.fromKg(weight.first.kg), 1),
    1,
  );
  final changeText =
      '${change > 0 ? '+' : ''}${plainNumber(change)} ${unit.name}';
  return '$first on ${f.format(dateFromKey(weight.first.date))} to $last on '
      '${f.format(dateFromKey(weight.last.date))} '
      '(change: $changeText, ${weight.count} weigh-ins).';
}

pw.Widget _heading(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
  ),
);

final _headerStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
const _cellStyle = pw.TextStyle(fontSize: 10);
const _headerDecoration = pw.BoxDecoration(color: PdfColors.grey200);

pw.Widget _averagesTable(ShareableReport report) {
  String amount(Metric m, double? v) =>
      v == null ? 'not recorded' : m.formatWithUnit(v);
  return pw.TableHelper.fromTextArray(
    headers: [
      'Metric',
      'Average',
      'Goal',
      '% of goal',
      'Days on target (within ${(goalTolerance * 100).round()}%)',
    ],
    data: [
      for (final r in report.rows)
        [
          r.metric.label,
          amount(r.metric, r.average),
          r.goal == null ? '-' : r.metric.formatWithUnit(r.goal!),
          r.percentOfGoal == null ? '-' : '${r.percentOfGoal}%',
          r.daysOnTarget == null
              ? '-'
              : '${r.daysOnTarget} of ${report.daysLogged}',
        ],
    ],
    headerStyle: _headerStyle,
    cellStyle: _cellStyle,
    headerDecoration: _headerDecoration,
    cellAlignment: pw.Alignment.centerLeft,
  );
}

pw.Widget _dailyTable(ShareableReport report) {
  final f = DateFormat('EEE, MMM d');
  return pw.TableHelper.fromTextArray(
    headers: ['Date', for (final m in report.metrics) '${m.label} (${m.unit})'],
    data: [
      for (final d in report.days)
        [
          f.format(dateFromKey(d.date)),
          for (final m in report.metrics)
            switch (m.recordedAmountIn(d.totals)) {
              null => '-',
              final v => m.format(v),
            },
        ],
    ],
    headerStyle: _headerStyle,
    cellStyle: _cellStyle,
    headerDecoration: _headerDecoration,
    cellAlignment: pw.Alignment.centerRight,
    cellAlignments: {0: pw.Alignment.centerLeft},
  );
}
