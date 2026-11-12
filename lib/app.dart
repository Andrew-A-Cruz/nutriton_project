import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/appearance.dart';
import 'providers/appearance_providers.dart';
import 'providers/backup_providers.dart';
import 'providers/health_providers.dart';
import 'providers/menu_providers.dart';
import 'providers/preferences_providers.dart';
import 'providers/reminder_providers.dart';
import 'providers/review_providers.dart';
import 'providers/widget_providers.dart';
import 'views/catalog/catalog_view.dart';
import 'views/common/keyboard_done_bar.dart';
import 'views/home/home_view.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/summary/summary_view.dart';
import 'views/tour/app_tour.dart';

/// Root widget.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    return CupertinoApp(
      title: 'Logbite',
      // The standard theme is Cupertino's own, so nothing changes without
      // Pro; another accent colour keeps the system light and dark modes.
      theme: theme == AppTheme.standard
          ? null
          : CupertinoThemeData(
              primaryColor: CupertinoDynamicColor.withBrightness(
                color: Color(theme.light),
                darkColor: Color(theme.dark),
              ),
            ),
      home: const _RootGate(),
      builder: (context, child) => KeyboardDoneBar(child: child!),
    );
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
    // Asks for one App Store review after a week of logging.
    ref.watch(reviewPromptPlanProvider);
    // Writes the week's automatic backup after today's first entry.
    ref.watch(autoBackupPlanProvider);
    // Brings unedited restaurant foods up to this release's menus.
    ref.watch(menuRefreshPlanProvider);
    final onboarded = ref.watch(
      preferencesProvider.select((s) => s.onboardingComplete),
    );
    return onboarded ? const _HomeTabs() : const OnboardingView();
  }
}

class _HomeTabs extends StatelessWidget {
  const _HomeTabs();

  static final List<({String label, IconData icon, TourTarget? tourTarget})>
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
                  icon: switch (tab.tourTarget) {
                    null => Icon(tab.icon),
                    final target => TourAnchor(
                      target: target,
                      child: Icon(tab.icon),
                    ),
                  },
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
