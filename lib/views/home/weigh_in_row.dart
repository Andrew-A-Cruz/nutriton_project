import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/body_weight.dart';
import '../../providers/body_weight_providers.dart';
import '../../providers/preferences_providers.dart';

/// The day's body weight under the totals: the reading, or a "Weigh in"
/// prompt. Tapping opens [WeighInDialog] to set, replace or clear it.
class WeighInRow extends ConsumerWidget {
  const WeighInRow({super.key, required this.date});

  /// 'yyyy-MM-dd'
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kg = ref.watch(bodyWeightForDateProvider(date)).value;
    final unit = ref.watch(preferencesProvider).bodyWeightUnit;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: CupertinoButton(
        key: const Key('weigh-in-row'),
        padding: EdgeInsets.zero,
        onPressed: () => showCupertinoDialog<void>(
          context: context,
          builder: (_) => WeighInDialog(date: date, currentKg: kg, unit: unit),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(CupertinoIcons.gauge, size: 20, color: secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kg == null ? 'Weigh in' : 'Weight',
                    style: TextStyle(
                      fontSize: 15,
                      color: kg == null
                          ? CupertinoColors.activeBlue.resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                if (kg != null)
                  Flexible(
                    child: Text(
                      formatBodyWeight(kg, unit),
                      key: const Key('weigh-in-value'),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sets, replaces or clears the body weight of one day. The number is typed in
/// [unit] and stored in kilograms.
class WeighInDialog extends ConsumerStatefulWidget {
  const WeighInDialog({
    super.key,
    required this.date,
    required this.currentKg,
    required this.unit,
  });

  final String date;
  final double? currentKg;
  final BodyWeightUnit unit;

  @override
  ConsumerState<WeighInDialog> createState() => _WeighInDialogState();
}

class _WeighInDialogState extends ConsumerState<WeighInDialog> {
  late final _controller = TextEditingController(
    text: widget.currentKg == null
        ? ''
        : formatBodyWeightValue(widget.currentKg!, widget.unit),
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  void _save() {
    final error = validateBodyWeight(_controller.text, widget.unit);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final kg = widget.unit.toKg(double.parse(_controller.text.trim()));
    _run(
      () => ref.read(bodyWeightRepositoryProvider).setWeight(widget.date, kg),
    );
  }

  void _clear() => _run(
    () => ref.read(bodyWeightRepositoryProvider).clearWeight(widget.date),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Weight'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          CupertinoTextField(
            key: const Key('weigh-in-field'),
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(widget.unit.name),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: const Key('weigh-in-error'),
                style: const TextStyle(
                  color: CupertinoColors.systemRed,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.currentKg != null)
          CupertinoDialogAction(
            key: const Key('weigh-in-clear'),
            isDestructiveAction: true,
            onPressed: _saving ? null : _clear,
            child: const Text('Clear'),
          ),
        CupertinoDialogAction(
          key: const Key('weigh-in-save'),
          isDefaultAction: true,
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
