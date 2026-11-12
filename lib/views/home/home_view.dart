import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../providers/log_providers.dart';
import '../../providers/preferences_providers.dart';
import '../../providers/schedule_providers.dart';
import '../add_food/add_food_view.dart';
import '../common/wide_layout.dart';
import '../settings/settings_view.dart';
import '../tour/app_tour.dart';
import 'copy_day_sheet.dart';
import 'date_header.dart';
import 'fasting_row.dart';
import 'day_log_list.dart';
import 'macro_summary.dart';
import 'streak_badge.dart';
import 'trial_ended_notice.dart';
import 'water_row.dart';
import 'weigh_in_row.dart';

/// The Today tab: date header, day totals, and the day's log.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final settings = ref.watch(preferencesProvider);
    final entriesAsync = ref.watch(dayEntriesProvider(date));
    final entries = entriesAsync.value ?? const <FoodLogEntry>[];
    // Planned items still waiting for a tap; they sit in their meal section and
    // do not count toward the totals above.
    final planned =
        ref.watch(pendingScheduledProvider(date)).value ??
        const <PendingScheduledMeal>[];
    // On a wide screen Add Food is a pane beside the day, not a sheet.
    final wide = isWideLayout(context);
    final day = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TourAnchor(
            target: TourTargets.date,
            child: DateHeader(date: date),
          ),
        ),
        SliverToBoxAdapter(
          child: TourAnchor(
            target: TourTargets.totals,
            child: MacroSummary(
              entries: entries,
              settings: settings,
              mindful: ref.watch(mindfulModeProvider),
              date: date,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: TrialEndedNotice()),
        SliverToBoxAdapter(child: WeighInRow(date: date)),
        SliverToBoxAdapter(child: WaterRow(date: date)),
        SliverToBoxAdapter(child: FastingRow(date: date)),
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
        else if (entries.isEmpty && planned.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyLogState(date: date),
          )
        else
          DayLogList(entries: entries, planned: planned, date: date),
      ],
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: const Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          child: StreakBadge(),
        ),
        middle: const Text('Food Log'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              key: const Key('copy-from-button'),
              padding: EdgeInsets.zero,
              onPressed: () => showCopyDaySheet(context, toDate: date),
              child: const Icon(CupertinoIcons.doc_on_doc),
            ),
            TourAnchor(
              target: TourTargets.settings,
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
            if (!wide)
              TourAnchor(
                target: TourTargets.addFood,
                child: CupertinoButton(
                  key: const Key('add-food-button'),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      fullscreenDialog: true,
                      // Logs go to the day shown here, which may not be
                      // today.
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
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: day),
                  Container(
                    width: 1,
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                  Expanded(
                    flex: 4,
                    child: TourAnchor(
                      target: TourTargets.addFood,
                      child: const _AddFoodPane(),
                    ),
                  ),
                ],
              )
            : day,
      ),
    );
  }
}

/// Add Food beside the day on a wide screen. It has its own navigator, so
/// the servings screen and the food form open inside the pane, and logging
/// returns to the catalog here. It follows the day Home shows.
class _AddFoodPane extends ConsumerStatefulWidget {
  const _AddFoodPane();

  @override
  ConsumerState<_AddFoodPane> createState() => _AddFoodPaneState();
}

class _AddFoodPaneState extends ConsumerState<_AddFoodPane> {
  final _navigator = GlobalKey<NavigatorState>();

  /// Bumped when something is logged, which starts Add Food afresh, as
  /// closing the sheet does on a phone: a form that was just logged from
  /// must not sit there ready to log again.
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen(
      dayEntriesProvider(
        ref.watch(selectedDateProvider),
      ).select((entries) => entries.value?.length),
      (before, after) {
        if (before != null && after != null && after > before) {
          setState(() => _generation++);
        }
      },
    );
    return NavigatorPopHandler(
      // Android's back button goes back inside the pane first.
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: ClipRect(
        child: Navigator(
          key: _navigator,
          onGenerateRoute: (_) => CupertinoPageRoute<void>(
            builder: (_) => Consumer(
              builder: (context, ref, _) => AddFoodView(
                key: ValueKey(_generation),
                logDate: ref.watch(selectedDateProvider),
                embedded: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
