import 'package:flutter/cupertino.dart';

import '../../data/database/app_database.dart';
import '../catalog/food_list.dart';

/// Searches the catalog for a food to add to a meal. Pops with the chosen
/// [FoodItem], or null when cancelled.
class FoodPickerPage extends StatefulWidget {
  const FoodPickerPage({super.key});

  @override
  State<FoodPickerPage> createState() => _FoodPickerPageState();
}

class _FoodPickerPageState extends State<FoodPickerPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: const Text('Choose a food'),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CupertinoSearchTextField(
                key: const Key('picker-search'),
                placeholder: 'Search',
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            Expanded(
              child: FoodList(
                search: _search,
                onTap: (FoodItem food) => Navigator.of(context).pop(food),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
