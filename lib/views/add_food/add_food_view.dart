import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../providers/infrastructure_providers.dart';
import '../catalog/catalog_browser.dart';
import '../catalog/food_form_view.dart';
import '../meals/meal_log_view.dart';
import 'adhoc_food_form.dart';
import 'log_food_view.dart';

enum _AddMode { catalog, adhoc }

/// The Add Food sheet. Everything it logs goes to [logDate], the day Home is
/// showing, which need not be today.
class AddFoodView extends ConsumerStatefulWidget {
  const AddFoodView({super.key, required this.logDate});

  final String logDate;

  @override
  ConsumerState<AddFoodView> createState() => _AddFoodViewState();
}

class _AddFoodViewState extends ConsumerState<AddFoodView> {
  _AddMode _mode = _AddMode.catalog;

  /// Opens the servings screen, starting from what was used last time.
  Future<void> _logFood(FoodItem food) async {
    double? last;
    try {
      last = await ref.read(logRepositoryProvider).lastServingsFor(food.id);
    } catch (_) {
      // Prefilling is a convenience; fall back to one serving.
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => LogFoodView(
          food: food,
          logDate: widget.logDate,
          initialServings: last,
        ),
      ),
    );
  }

  void _logMeal(Meal meal) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => MealLogView(meal: meal, logDate: widget.logDate),
      ),
    );
  }

  /// Creates a catalog food, then logs it straight away.
  Future<void> _newFood() async {
    final food = await Navigator.of(context).push<FoodItem>(
      CupertinoPageRoute<FoodItem>(
        builder: (_) => const FoodFormView(offerLogAfterSave: true),
      ),
    );
    if (food != null && mounted) _logFood(food);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          key: const Key('add-food-close'),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        middle: const Text('Add Food'),
        trailing: _mode == _AddMode.catalog
            ? CupertinoButton(
                key: const Key('add-new-food'),
                padding: EdgeInsets.zero,
                onPressed: _newFood,
                child: const Text('New food'),
              )
            : null,
      ),
      // The nav bar is translucent, so the content needs the top inset.
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CupertinoSlidingSegmentedControl<_AddMode>(
                key: const Key('add-food-mode'),
                groupValue: _mode,
                children: const {
                  _AddMode.catalog: Text('Catalog'),
                  _AddMode.adhoc: Text('One-off'),
                },
                onValueChanged: (mode) {
                  if (mode != null) setState(() => _mode = mode);
                },
              ),
            ),
            Expanded(
              child: switch (_mode) {
                _AddMode.catalog => CatalogBrowser(
                  showRecent: true,
                  onFoodTap: _logFood,
                  onMealTap: _logMeal,
                ),
                _AddMode.adhoc => AdhocFoodForm(logDate: widget.logDate),
              },
            ),
          ],
        ),
      ),
    );
  }
}
