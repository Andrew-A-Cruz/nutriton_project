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

/// Mindful mode: Home shows foods and goal progress without calorie or macro
/// numbers, the streak badge is hidden and Summary bars are one color. Only
/// rendering changes; the log, goals and reminders stay as they are.
class MindfulModeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(userPreferencesProvider).readMindfulMode();

  Future<void> set(bool on) async {
    state = on;
    await ref.read(userPreferencesProvider).writeMindfulMode(on);
  }
}

final mindfulModeProvider = NotifierProvider<MindfulModeNotifier, bool>(
  MindfulModeNotifier.new,
);
