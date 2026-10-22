import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../providers/log_providers.dart';
import '../../providers/preferences_providers.dart';
import '../add_food/add_food_view.dart';
import '../settings/settings_view.dart';
import '../tour/app_tour.dart';
import 'date_header.dart';
import 'day_log_list.dart';
import 'macro_summary.dart';
import 'scheduled_suggestions.dart';

/// The Today tab: date header, day totals, and the day's log.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final settings = ref.watch(preferencesProvider);
    final entriesAsync = ref.watch(dayEntriesProvider(date));
    final entries = entriesAsync.value ?? const <FoodLogEntry>[];

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Food Log'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(
              key: TourTargets.settings,
              child: CupertinoButton(
                key: const Key('settings-button'),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const SettingsView(),
                  ),
                ),
                child: const Icon(CupertinoIcons.settings),
              ),
            ),
            KeyedSubtree(
              key: TourTargets.addFood,
              child: CupertinoButton(
                key: const Key('add-food-button'),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    fullscreenDialog: true,
                    // Logs go to the day shown here, which may not be today.
                    builder: (_) => AddFoodView(logDate: date),
                  ),
                ),
                child: const Icon(CupertinoIcons.add),
              ),
            ),
          ],
        ),
      ),
      // The nav bar is translucent, so the content needs the top inset.
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: TourTargets.date,
                child: DateHeader(date: date),
              ),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: TourTargets.totals,
                child: MacroSummary(entries: entries, settings: settings),
              ),
            ),
            SliverToBoxAdapter(child: ScheduledSuggestions(date: date)),
            if (entriesAsync.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Could not load this day: ${entriesAsync.error}'),
                ),
              )
            else if (!entriesAsync.hasValue)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyLogState(date: date),
              )
            else
              DayLogList(entries: entries),
          ],
        ),
      ),
    );
  }
}
