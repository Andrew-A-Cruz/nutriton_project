import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fasting.dart';
import '../../data/database/app_database.dart';
import '../../providers/fasting_providers.dart';
import '../../providers/preferences_providers.dart';
import '../../providers/today_providers.dart';
import '../common/error_feedback.dart';

/// The fasting timer on Today: "Start fast", or the time fasted so far with
/// "End". Shown only when the timer is switched on in Settings, and only on
/// today, since the timer is about now.
class FastingRow extends ConsumerStatefulWidget {
  const FastingRow({super.key, required this.date});

  /// The day Home is showing, 'yyyy-MM-dd'.
  final String date;

  @override
  ConsumerState<FastingRow> createState() => _FastingRowState();
}

class _FastingRowState extends ConsumerState<FastingRow> {
  /// Redraws the elapsed time while a fast runs.
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTick(bool running) {
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  Future<void> _run(Future<void> Function() action, String failed) async {
    try {
      await action();
    } catch (e, stack) {
      if (mounted) {
        await showErrorDialog(context, reportError(ref, e, stack, failed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      preferencesProvider.select((s) => s.fastingEnabled),
    );
    final shown = enabled && widget.date == ref.watch(todayProvider);
    final Fast? fast = shown ? ref.watch(activeFastProvider).value : null;
    _syncTick(fast != null);
    if (!shown) return const SizedBox.shrink();

    final now = ref.read(clockProvider);
    final repo = ref.read(fastingRepositoryProvider);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final elapsed = fast == null
        ? null
        : formatFastLength(fastLength(fast.startedAt, now()));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        key: const Key('fasting-row'),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
            context,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Icon(CupertinoIcons.timer, size: 20, color: secondary),
              const SizedBox(width: 8),
              Text(
                fast == null ? 'Not fasting' : 'Fasting',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: elapsed == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        label: 'Fasting for $elapsed',
                        excludeSemantics: true,
                        child: Text(
                          elapsed,
                          key: const Key('fasting-elapsed'),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              CupertinoButton(
                key: Key(fast == null ? 'fasting-start' : 'fasting-end'),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size.square(44),
                onPressed: () => fast == null
                    ? _run(() => repo.start(now()), 'Could not start the fast')
                    : _run(() => repo.end(now()), 'Could not end the fast'),
                child: Text(fast == null ? 'Start fast' : 'End'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
