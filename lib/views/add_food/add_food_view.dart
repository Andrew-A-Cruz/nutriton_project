import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/food_lookup_repository.dart';
import '../catalog/barcode_scanner_page.dart';
import '../../providers/infrastructure_providers.dart';
import '../catalog/catalog_browser.dart';
import '../catalog/food_form_view.dart';
import '../meals/meal_log_view.dart';
import '../common/error_feedback.dart';
import 'adhoc_food_form.dart';
import 'log_food_view.dart';
import 'quick_add_form.dart';

enum _AddMode { catalog, quick, adhoc }

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
    } catch (e, stack) {
      // Prefilling is a convenience; fall back to one serving.
      reportError(ref, e, stack, 'Could not read the last servings');
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

  /// Creates a catalog food, then logs it straight away. A [scannedBarcode]
  /// is looked up on Open Food Facts as the form opens.
  Future<void> _newFood({String? scannedBarcode}) async {
    final food = await Navigator.of(context).push<FoodItem>(
      CupertinoPageRoute<FoodItem>(
        builder: (_) => FoodFormView(
          offerLogAfterSave: true,
          scannedBarcode: scannedBarcode,
        ),
      ),
    );
    if (food != null && mounted) await _logFood(food);
  }

  /// Scans a barcode. A catalog food with that code goes straight to logging;
  /// otherwise a new food opens, prefilled from Open Food Facts when it knows
  /// the product.
  Future<void> _scan() async {
    final scanned = await ref.read(barcodeScannerProvider)(context);
    if (!mounted || scanned == null || scanned.isEmpty) return;
    final code = FoodLookupRepository.normalizeBarcode(scanned) ?? scanned;
    FoodItem? local;
    try {
      local = await ref.read(catalogRepositoryProvider).findFoodByBarcode(code);
    } catch (e, stack) {
      // Fall through to a new food, which looks the code up online.
      reportError(ref, e, stack, 'Could not check the catalog for a barcode');
    }
    if (!mounted) return;
    if (local != null) {
      await _logFood(local);
    } else {
      await _newFood(scannedBarcode: code);
    }
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
                onPressed: () => _newFood(),
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
                  _AddMode.quick: Text('Quick add'),
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
                  onScan: ref.watch(barcodeScanSupportedProvider)
                      ? _scan
                      : null,
                  onFoodTap: _logFood,
                  onMealTap: _logMeal,
                ),
                _AddMode.quick => QuickAddForm(logDate: widget.logDate),
                _AddMode.adhoc => AdhocFoodForm(logDate: widget.logDate),
              },
            ),
          ],
        ),
      ),
    );
  }
}
