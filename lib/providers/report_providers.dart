import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/report/report_sharer.dart';

export '../data/report/report_sharer.dart' show ReportSharer;

/// Where a shared report goes. Tests override it with a fake.
final reportSharerProvider = Provider<ReportSharer>(
  (ref) => const SystemReportSharer(),
);
