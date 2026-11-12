import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/water.dart';
import '../../providers/preferences_providers.dart';
import '../../providers/water_providers.dart';
import '../common/error_feedback.dart';

/// The day's water under the weigh-in row: the total, against the goal when
/// there is one, with − and + to take away or add a glass. Hidden when water
/// tracking is off in Settings.
class WaterRow extends ConsumerWidget {
  const WaterRow({super.key, required this.date});

  /// 'yyyy-MM-dd'
  final String date;

  Future<void> _add(BuildContext context, WidgetRef ref, double deltaMl) async {
    try {
      await ref.read(waterRepositoryProvider).add(date, deltaMl);
    } catch (e, stack) {
      if (context.mounted) {
        await showErrorDialog(
          context,
          reportError(ref, e, stack, 'Could not save'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final water = ref.watch(preferencesProvider.select((s) => s.water));
    if (!water.enabled) return const SizedBox.shrink();
    final ml = ref.watch(waterForDateProvider(date)).value ?? 0;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final goal = water.goalMl;
    final reached = goal != null && goal > 0 && ml >= goal;
    final text = waterProgressText(ml, water);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        key: const Key('water-row'),
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
              Icon(CupertinoIcons.drop, size: 20, color: secondary),
              const SizedBox(width: 8),
              const Text('Water', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: 'Water: $text',
                  excludeSemantics: true,
                  child: Text(
                    text,
                    key: const Key('water-value'),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: reached
                          ? CupertinoColors.systemGreen.resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              ),
              CupertinoButton(
                key: const Key('water-minus'),
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
                onPressed: ml <= 0 ? null : () => _add(context, ref, -glassMl),
                child: const Icon(
                  CupertinoIcons.minus_circle,
                  semanticLabel: 'Take away a glass of water',
                ),
              ),
              CupertinoButton(
                key: const Key('water-plus'),
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
                onPressed: ml >= maxWaterMl
                    ? null
                    : () => _add(context, ref, glassMl),
                child: const Icon(
                  CupertinoIcons.plus_circle_fill,
                  semanticLabel: 'Add a glass of water',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
