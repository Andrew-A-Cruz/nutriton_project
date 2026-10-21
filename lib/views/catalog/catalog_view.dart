import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../providers/log_providers.dart';
import '../meals/meal_builder_view.dart';
import '../meals/meal_log_view.dart';
import '../meals/schedule_meal_view.dart';
import 'catalog_browser.dart';
import 'food_form_view.dart';

/// The Catalog tab: saved foods and meal templates. Swipe a row to archive it.
class CatalogView extends ConsumerWidget {
  const CatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Catalog'),
        trailing: CupertinoButton(
          key: const Key('catalog-add'),
          padding: EdgeInsets.zero,
          onPressed: () => _showAddMenu(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      // The nav bar is translucent, so the content needs the top inset.
      child: SafeArea(
        bottom: false,
        child: CatalogBrowser(
          archivable: true,
          onFoodTap: (food) => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => FoodFormView(existing: food),
            ),
          ),
          onMealTap: (meal) => _showMealActions(context, ref, meal),
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            key: const Key('catalog-new-food'),
            onPressed: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => const FoodFormView()),
              );
            },
            child: const Text('New food'),
          ),
          CupertinoActionSheetAction(
            key: const Key('catalog-new-meal'),
            onPressed: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const MealBuilderView(),
                ),
              );
            },
            child: const Text('New meal'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showMealActions(BuildContext context, WidgetRef ref, Meal meal) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text(meal.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => MealLogView(
                    meal: meal,
                    logDate: ref.read(selectedDateProvider),
                  ),
                ),
              );
            },
            child: const Text('Log meal'),
          ),
          CupertinoActionSheetAction(
            key: const Key('meal-action-schedule'),
            onPressed: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => ScheduleMealView(
                    meal: meal,
                    initialDate: ref.read(selectedDateProvider),
                  ),
                ),
              );
            },
            child: const Text('Schedule meal'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => MealBuilderView(existing: meal),
                ),
              );
            },
            child: const Text('Edit meal'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
