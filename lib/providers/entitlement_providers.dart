import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pro.dart';
import '../data/store/store_service.dart';
import 'preferences_providers.dart';
import 'today_providers.dart';

/// The App Store. A no-op until `main` overrides it with the real one, so
/// tests and builds without a store never touch the plugin.
final storeServiceProvider = Provider<StoreService>(
  (ref) => const NoopStoreService(),
);

/// Unlocks Pro with no purchase, for development builds installed outside the
/// App Store (`--dart-define=PRO_UNLOCKED=true`). `main` sets it.
final proUnlockedForDevelopmentProvider = Provider<bool>((ref) => false);

/// What the user owns. Starts from the copy cached on the device, so Pro
/// works offline and needs no network call at launch, then follows the store.
class ProStatusNotifier extends Notifier<ProStatus> {
  @override
  ProStatus build() {
    ref.keepAlive();
    final store = ref.watch(storeServiceProvider);
    final sub = store.statusUpdates.listen(_apply, onError: (Object _) {});
    ref.onDispose(sub.cancel);
    if (store.isAvailable) {
      // Offline, the cached copy stands until the store answers.
      unawaited(store.currentStatus().then(_apply).catchError((Object _) {}));
    }
    return ref.read(userPreferencesProvider).readProStatus();
  }

  void _apply(ProStatus status) {
    if (status == state) return;
    state = status;
    unawaited(ref.read(userPreferencesProvider).writeProStatus(status));
  }

  /// Buys product [id] (Pro, the trial or a tip). Returns false if the user
  /// cancelled. Throws [StoreException] when it fails.
  Future<bool> buy(String id) async {
    final status = await ref.read(storeServiceProvider).buy(id);
    if (status == null) return false;
    _apply(status);
    return true;
  }

  /// Restores earlier purchases. Throws [StoreException] when it fails.
  Future<void> restore() async =>
      _apply(await ref.read(storeServiceProvider).restore());
}

final proStatusProvider = NotifierProvider<ProStatusNotifier, ProStatus>(
  ProStatusNotifier.new,
);

/// How the user has Pro now. Re-checked when the day changes, so a trial
/// ends at the first midnight or app launch after its 14 days.
final proAccessProvider = Provider<ProAccess>((ref) {
  if (ref.watch(proUnlockedForDevelopmentProvider)) return ProAccess.owned;
  ref.watch(todayProvider);
  return proAccess(ref.watch(proStatusProvider), ref.read(clockProvider)());
});

/// Whether Pro features are unlocked. Only the Pro features' entry points
/// read this (through `ProGate`); repositories and DAOs know nothing of Pro.
final proProvider = Provider<bool>((ref) => ref.watch(proAccessProvider).isPro);

/// Products the paywall and the tip jar sell, with store prices. Empty when
/// the store is unavailable or unreachable.
final storeItemsProvider = FutureProvider<Map<String, StoreItem>>((ref) async {
  final store = ref.watch(storeServiceProvider);
  if (!store.isAvailable) return const {};
  final items = await store.products([
    ProProducts.pro,
    ProProducts.trial,
    ...ProProducts.tips,
  ]);
  return {for (final item in items) item.id: item};
});

/// Whether to show "Your trial ended". True once, from the day a trial runs
/// out without Pro being bought, until the user dismisses it.
class TrialEndedNoticeNotifier extends Notifier<bool> {
  @override
  bool build() {
    if (ref.read(userPreferencesProvider).readTrialEndedNoticeShown()) {
      return false;
    }
    if (ref.watch(proProvider)) return false;
    ref.watch(todayProvider);
    return trialHasEnded(
      ref.watch(proStatusProvider),
      ref.read(clockProvider)(),
    );
  }

  Future<void> dismiss() async {
    state = false;
    await ref.read(userPreferencesProvider).writeTrialEndedNoticeShown();
  }
}

final trialEndedNoticeProvider =
    NotifierProvider<TrialEndedNoticeNotifier, bool>(
      TrialEndedNoticeNotifier.new,
    );
