import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/health_providers.dart';
import 'providers/preferences_providers.dart';
import 'providers/reminder_providers.dart';
import 'providers/widget_providers.dart';
import 'views/catalog/catalog_view.dart';
import 'views/home/home_view.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/summary/summary_view.dart';
import 'views/tour/app_tour.dart';

/// Root widget.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(title: 'Nutriton', home: _RootGate());
  }
}

/// Onboarding until `onboarding_complete` is saved, then the tabs.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps reminder notifications planned while the app is open.
    ref.watch(reminderPlanProvider);
    // Keeps the home screen widget's figures current.
    ref.watch(widgetPlanProvider);
    // Keeps Apple Health in line with the log and body weight, when opted in.
    ref.watch(healthNutritionPlanProvider);
    ref.watch(healthWeightPlanProvider);
    final onboarded = ref.watch(
      preferencesProvider.select((s) => s.onboardingComplete),
    );
    return onboarded ? const _HomeTabs() : const OnboardingView();
  }
}

class _HomeTabs extends StatelessWidget {
  const _HomeTabs();

  static final List<({String label, IconData icon, GlobalKey? tourTarget})>
  _tabs = [
    (label: 'Today', icon: CupertinoIcons.today_fill, tourTarget: null),
    (
      label: 'Catalog',
      icon: CupertinoIcons.book_fill,
      tourTarget: TourTargets.catalogTab,
    ),
    (
      label: 'Summary',
      icon: CupertinoIcons.chart_bar_fill,
      tourTarget: TourTargets.summaryTab,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Each tab gets its own CupertinoTabView, so it keeps its own stack.
        CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: [
              for (final tab in _tabs)
                BottomNavigationBarItem(
                  icon: KeyedSubtree(
                    key: tab.tourTarget,
                    child: Icon(tab.icon),
                  ),
                  label: tab.label,
                ),
            ],
          ),
          tabBuilder: (context, index) => CupertinoTabView(
            builder: (context) => switch (index) {
              0 => const HomeView(),
              1 => const CatalogView(),
              _ => const SummaryView(),
            },
          ),
        ),
        // Above the tab bar too, so the tour can point at the tabs.
        const Positioned.fill(child: AppTourOverlay()),
      ],
    );
  }
}
