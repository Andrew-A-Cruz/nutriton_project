import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/preferences_providers.dart';
import 'views/catalog/catalog_view.dart';
import 'views/home/home_view.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/summary/summary_view.dart';

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
    final onboarded = ref.watch(
      preferencesProvider.select((s) => s.onboardingComplete),
    );
    return onboarded ? const _HomeTabs() : const OnboardingView();
  }
}

class _HomeTabs extends StatelessWidget {
  const _HomeTabs();

  static const _tabs = [
    (label: 'Today', icon: CupertinoIcons.today_fill),
    (label: 'Catalog', icon: CupertinoIcons.book_fill),
    (label: 'Summary', icon: CupertinoIcons.chart_bar_fill),
  ];

  @override
  Widget build(BuildContext context) {
    // Each tab gets its own CupertinoTabView, so it keeps its own stack.
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          for (final tab in _tabs)
            BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(
        builder: (context) => switch (index) {
          0 => const HomeView(),
          1 => const CatalogView(),
          _ => const SummaryView(),
        },
      ),
    );
  }
}
