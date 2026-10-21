import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../providers/log_providers.dart';
import 'food_list.dart';
import 'meal_list.dart';

enum CatalogSection { foods, meals }

/// Foods / Meals switch, a search field, and the matching list. Shared by the
/// Catalog tab and the Add Food sheet. Expects a bounded height.
class CatalogBrowser extends StatefulWidget {
  const CatalogBrowser({
    super.key,
    required this.onFoodTap,
    required this.onMealTap,
    this.archivable = false,
    this.showRecent = false,
  });

  final ValueChanged<FoodItem> onFoodTap;
  final ValueChanged<Meal> onMealTap;
  final bool archivable;

  /// Shows recently logged foods above the Foods list (when not searching).
  final bool showRecent;

  @override
  State<CatalogBrowser> createState() => _CatalogBrowserState();
}

class _CatalogBrowserState extends State<CatalogBrowser> {
  CatalogSection _section = CatalogSection.foods;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CupertinoSlidingSegmentedControl<CatalogSection>(
            key: const Key('catalog-section'),
            groupValue: _section,
            children: const {
              CatalogSection.foods: Text('Foods'),
              CatalogSection.meals: Text('Meals'),
            },
            onValueChanged: (section) {
              if (section != null) setState(() => _section = section);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: CupertinoSearchTextField(
            key: const Key('catalog-search'),
            placeholder: 'Search',
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        if (widget.showRecent &&
            _section == CatalogSection.foods &&
            _search.trim().isEmpty)
          RecentFoods(onTap: widget.onFoodTap),
        Expanded(
          child: switch (_section) {
            CatalogSection.foods => FoodList(
              search: _search,
              onTap: widget.onFoodTap,
              archivable: widget.archivable,
            ),
            CatalogSection.meals => MealList(
              search: _search,
              onTap: widget.onMealTap,
              archivable: widget.archivable,
            ),
          },
        ),
      ],
    );
  }
}

/// A horizontal strip of the foods logged most recently. Hidden when there
/// are none.
class RecentFoods extends ConsumerWidget {
  const RecentFoods({super.key, required this.onTap});

  final ValueChanged<FoodItem> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(recentFoodsProvider).value ?? const <FoodItem>[];
    if (foods.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('recent-foods'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Recent',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final food in foods)
                CupertinoButton(
                  key: Key('recent-food-${food.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  onPressed: () => onTap(food),
                  child: Text(food.name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
