import 'package:flutter/cupertino.dart';

import '../../core/macro_split.dart';
import '../../core/metrics.dart';

/// A stacked bar of the share of calories from protein, carbs and fat, with
/// a legend. VoiceOver reads it as one sentence.
class MacroSplitBar extends StatelessWidget {
  const MacroSplitBar({super.key, required this.split});

  final MacroSplit split;

  /// Not green, orange or red, which mean on, under and over goal elsewhere.
  static CupertinoDynamicColor colorFor(Metric metric) => switch (metric) {
    Metric.protein => CupertinoColors.systemIndigo,
    Metric.carbs => CupertinoColors.systemTeal,
    _ => CupertinoColors.systemPink,
  };

  @override
  Widget build(BuildContext context) {
    final parts = [
      (Metric.protein, split.protein),
      (Metric.carbs, split.carbs),
      (Metric.fat, split.fat),
    ];
    return Semantics(
      container: true,
      label: macroSplitText(split),
      child: ExcludeSemantics(
        child: Column(
          key: const Key('macro-split'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final (metric, percent) in parts)
                      if (percent > 0)
                        Expanded(
                          flex: percent,
                          child: ColoredBox(
                            color: colorFor(metric).resolveFrom(context),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final (metric, percent) in parts)
                  _LegendItem(
                    color: colorFor(metric).resolveFrom(context),
                    text: '${metric.label} $percent%',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}
