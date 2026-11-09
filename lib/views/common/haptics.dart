import 'dart:async';

import 'package:flutter/services.dart';

/// Haptic taps for the actions that change the log. The phone's own haptics
/// setting still applies, so people who turned them off feel nothing.
abstract final class Haptics {
  /// Something was logged: an entry, a meal, a confirmed plan or a copied
  /// day.
  static void logged() => unawaited(HapticFeedback.lightImpact());

  /// An entry was deleted. Firmer than [logged], so it reads as a warning.
  static void deleted() => unawaited(HapticFeedback.mediumImpact());
}
