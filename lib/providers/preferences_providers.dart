import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences/user_preferences.dart';
import 'infrastructure_providers.dart';

final userPreferencesProvider = Provider<UserPreferences>(
  (ref) => UserPreferences(ref.watch(sharedPreferencesProvider)),
);

/// Current settings. Reads from storage on first use. [save] updates state
/// first, so the UI reacts at once, then persists.
class PreferencesNotifier extends Notifier<UserSettings> {
  @override
  UserSettings build() {
    ref.keepAlive();
    return ref.watch(userPreferencesProvider).read();
  }

  Future<void> save(UserSettings settings) async {
    state = settings;
    await ref.read(userPreferencesProvider).write(settings);
  }
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, UserSettings>(
  PreferencesNotifier.new,
);
