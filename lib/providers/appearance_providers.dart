import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/appearance.dart';
import '../data/app_icon/app_icon_service.dart';
import 'entitlement_providers.dart';
import 'preferences_providers.dart';

/// The accent color the user picked. Kept without Pro, so it comes back
/// when Pro does. Device-local, like mindful mode.
class ThemeChoiceNotifier extends Notifier<AppTheme> {
  @override
  AppTheme build() => ref.watch(userPreferencesProvider).readTheme();

  Future<void> set(AppTheme theme) async {
    state = theme;
    await ref.read(userPreferencesProvider).writeTheme(theme);
  }
}

final themeChoiceProvider = NotifierProvider<ThemeChoiceNotifier, AppTheme>(
  ThemeChoiceNotifier.new,
);

/// The accent color in use: the picked one with Pro, the standard one
/// without.
final appThemeProvider = Provider<AppTheme>(
  (ref) => effectiveTheme(
    ref.watch(themeChoiceProvider),
    pro: ref.watch(proProvider),
  ),
);

/// A no-op until `main` overrides it on iOS.
final appIconServiceProvider = Provider<AppIconService>(
  (ref) => const NoopAppIconService(),
);

/// The app icon in use, as the system reports it. Losing Pro does not
/// change an icon already chosen.
class AppIconNotifier extends AsyncNotifier<AppIconChoice> {
  @override
  Future<AppIconChoice> build() async {
    final service = ref.watch(appIconServiceProvider);
    if (!service.isSupported) return AppIconChoice.standard;
    return AppIconChoice.fromIosName(await service.current());
  }

  /// Switches the icon. Throws when the system refuses.
  Future<void> choose(AppIconChoice choice) async {
    await ref.read(appIconServiceProvider).set(choice.iosName);
    state = AsyncData(choice);
  }
}

final appIconProvider = AsyncNotifierProvider<AppIconNotifier, AppIconChoice>(
  AppIconNotifier.new,
);
