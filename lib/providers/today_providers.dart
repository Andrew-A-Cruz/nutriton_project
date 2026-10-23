import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_key.dart';

/// The current time. Tests override this to control "now".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The current local day as a 'yyyy-MM-dd' key. Recomputed when the app
/// resumes and at each local midnight, so a long-lived session never shows
/// yesterday as "Today".
class TodayNotifier extends Notifier<String> {
  Timer? _midnight;
  AppLifecycleListener? _lifecycle;

  @override
  String build() {
    ref.keepAlive();
    _lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      _midnight?.cancel();
      _lifecycle?.dispose();
    });
    final now = ref.read(clockProvider)();
    _armMidnight(now);
    return todayKey(now);
  }

  /// Re-reads the clock, updates [state] and re-arms the midnight timer.
  void refresh() {
    final now = ref.read(clockProvider)();
    state = todayKey(now);
    _armMidnight(now);
  }

  void _armMidnight(DateTime now) {
    _midnight?.cancel();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    var wait = nextMidnight.difference(now);
    if (wait < const Duration(seconds: 1)) wait = const Duration(seconds: 1);
    _midnight = Timer(wait, refresh);
  }
}

final todayProvider = NotifierProvider<TodayNotifier, String>(
  TodayNotifier.new,
);
