import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/summary_providers.dart';

/// The logging streak in the Home header: a flame and the number of days.
/// Hidden when there is no streak.
class StreakBadge extends ConsumerWidget {
  const StreakBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(streakProvider).value ?? 0;
    if (days == 0) return const SizedBox.shrink();
    return Semantics(
      label: days == 1 ? '1 day streak' : '$days day streak',
      excludeSemantics: true,
      child: Row(
        key: const Key('streak-badge'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.flame_fill,
            size: 18,
            color: CupertinoColors.systemOrange,
          ),
          const SizedBox(width: 2),
          Text(
            '$days',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
