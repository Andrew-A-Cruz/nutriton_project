import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_key.dart';
import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../../data/database/app_database.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/preferences_providers.dart';
import '../common/form_widgets.dart';
import '../home/date_header.dart';

enum AmountMode { servings, weight }

/// Logs one catalog food for [logDate], by servings or by weight (in the
/// user's display unit). A weight is converted to grams and then to servings
/// with [servingsForWeight], so the entry is always a servings entry. Pops to
/// the root after logging.
class LogFoodView extends ConsumerStatefulWidget {
  const LogFoodView({super.key, required this.food, required this.logDate});

  final FoodItem food;
  final String logDate;

  @override
  ConsumerState<LogFoodView> createState() => _LogFoodViewState();
}

class _LogFoodViewState extends ConsumerState<LogFoodView> {
  late final TextEditingController _amount;
  AmountMode _mode = AmountMode.servings;
  String? _error;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Macros get _perServing => Macros(
    calories: widget.food.calories,
    protein: widget.food.protein,
    carbs: widget.food.carbs,
    fat: widget.food.fat,
  );

  /// The unit weights are typed in: the user's display unit.
  WeightUnit get _unit => ref.read(preferencesProvider).displayUnit;

  String get _weightLabel => _unit == WeightUnit.g ? 'Grams' : 'Ounces';

  /// Switching modes converts the typed amount, so 1.5 servings becomes 150 g.
  void _setMode(AmountMode mode) {
    final typed = parseNumber(_amount.text);
    setState(() {
      if (typed != null && typed >= 0 && mode != _mode) {
        // Called with the old mode still in _mode, so this converts from it.
        final converted = mode == AmountMode.weight
            ? _unit.fromGrams(typed * widget.food.servingWeightG)
            : servingsForWeight(
                weightG: _unit.toGrams(typed),
                servingWeightG: widget.food.servingWeightG,
              );
        _amount.text = plainNumber(roundTo(converted, 2));
      }
      _mode = mode;
      _error = null;
    });
  }

  /// The amount in servings, or null when the input is not valid.
  double? get _servings {
    final typed = parseNumber(_amount.text);
    if (typed == null || typed <= 0) return null;
    return _mode == AmountMode.servings
        ? typed
        : servingsForWeight(
            weightG: _unit.toGrams(typed),
            servingWeightG: widget.food.servingWeightG,
          );
  }

  Future<void> _log() async {
    final servings = _servings;
    setState(() {
      _error = servings == null ? positiveNumber(_amount.text) : null;
      _saveError = null;
    });
    if (servings == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(logRepositoryProvider)
          .logFood(
            logDate: widget.logDate,
            food: widget.food,
            servings: servings,
          );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not log food: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final servings = _servings;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: Text(widget.food.name),
        trailing: CupertinoButton(
          key: const Key('log-food-confirm'),
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _log,
          child: const Text('Log'),
        ),
      ),
      // The nav bar is translucent, so the content needs the top inset.
      child: SafeArea(
        bottom: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Logging to ${dayLabel(widget.logDate, today: todayKey())}',
                key: const Key('log-food-date'),
                textAlign: TextAlign.center,
                style: TextStyle(color: secondary),
              ),
            ),
            CupertinoFormSection.insetGrouped(
              children: [
                CupertinoFormRow(
                  prefix: const Text('Amount in'),
                  child: CupertinoSlidingSegmentedControl<AmountMode>(
                    key: const Key('log-mode'),
                    groupValue: _mode,
                    children: {
                      AmountMode.servings: const Text('Servings'),
                      AmountMode.weight: Text(_weightLabel),
                    },
                    onValueChanged: (mode) {
                      if (mode != null) _setMode(mode);
                    },
                  ),
                ),
                formRow(
                  fieldKey: const Key('log-amount'),
                  label: _mode == AmountMode.servings
                      ? 'Servings'
                      : _weightLabel,
                  controller: _amount,
                  error: _error,
                  suffix: _mode == AmountMode.servings ? 'serving' : _unit.name,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('TOTAL FOR THIS ENTRY'),
              children: [
                CupertinoListTile(
                  title: Text(
                    servings == null
                        ? 'Enter an amount'
                        : _macroLine(scaleByServings(_perServing, servings)),
                    key: const Key('log-preview'),
                  ),
                  subtitle: servings == null
                      ? null
                      : Text(
                          '${plainNumber(roundTo(servings, 2))} '
                          '${servings == 1 ? 'serving' : 'servings'}',
                          key: const Key('log-servings'),
                        ),
                ),
              ],
            ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _saveError!,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _macroLine(Macros m) => formatMacroLine(m);
}
