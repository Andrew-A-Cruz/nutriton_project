import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app tour's current step, or null when it is not showing. Not saved:
/// the tour starts right after onboarding and from Settings, never by itself.
class TourNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void start() => state = 0;

  /// Moves to the next step, or ends the tour after the last of [stepCount].
  void next(int stepCount) {
    final step = state;
    if (step == null) return;
    state = step + 1 < stepCount ? step + 1 : null;
  }

  void finish() => state = null;
}

final tourProvider = NotifierProvider<TourNotifier, int?>(TourNotifier.new);
