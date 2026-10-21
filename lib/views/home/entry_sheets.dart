import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../core/validation.dart';
import '../../data/database/app_database.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/preferences_providers.dart';
import '../common/form_widgets.dart';

/// Edits the serving count of a logged food entry.
class EditServingsDialog extends ConsumerStatefulWidget {
  const EditServingsDialog({super.key, required this.entry});

  final FoodLogEntry entry;

  @override
  ConsumerState<EditServingsDialog> createState() => _EditServingsDialogState();
}

class _EditServingsDialogState extends ConsumerState<EditServingsDialog> {
  late final _controller = TextEditingController(
    text: plainNumber(widget.entry.servings ?? 1),
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = parseNumber(_controller.text);
    if (value == null || value <= 0) {
      setState(() => _error = positiveNumber(_controller.text));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(logRepositoryProvider)
          .updateServings(widget.entry.id, servings: value);
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

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.entry.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Servings'),
          ),
          CupertinoTextField(
            key: const Key('servings-field'),
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
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
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Lists what was actually eaten in a logged meal, from its breakdown rows.
class MealBreakdownSheet extends ConsumerWidget {
  const MealBreakdownSheet({super.key, required this.entry});

  final FoodLogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(entryItemsProvider(entry.id));
    final unit = ref.watch(preferencesProvider.select((s) => s.displayUnit));

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.6,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${Metric.calories.format(entry.calories)} kcal total',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.when(
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (error, _) =>
                    Center(child: Text('Could not load breakdown: $error')),
                data: (rows) => rows.isEmpty
                    ? const Center(child: Text('No items recorded'))
                    : ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          for (final row in rows)
                            CupertinoListTile(
                              title: Text(row.name),
                              subtitle: Text(formatWeight(row.weightG, unit)),
                              trailing: Text(
                                '${Metric.calories.format(row.calories)} kcal',
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
