import 'package:flutter/cupertino.dart';

import '../../data/database/app_database.dart';
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
  });

  final ValueChanged<FoodItem> onFoodTap;
  final ValueChanged<Meal> onMealTap;
  final bool archivable;

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
