import 'dart:async';

import 'package:nutriton_project/core/pro.dart';
import 'package:nutriton_project/data/store/store_service.dart';

/// A store that sells the Pro, trial and tip products at fixed prices.
/// [owned] is what the store reports; [onBuy] decides each purchase.
class FakeStoreService implements StoreService {
  FakeStoreService({this.owned = ProStatus.none, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  ProStatus owned;
  final DateTime Function() _now;

  /// What buying returns; by default the purchase goes through.
  ProStatus? Function(String id)? onBuy;

  /// Thrown by [restore] when set.
  StoreException? restoreError;

  /// Whether [currentStatus] never answers, as when offline.
  bool offline = false;

  final List<String> bought = [];
  int restores = 0;

  final _updates = StreamController<ProStatus>.broadcast();

  /// Reports a change from the store, such as a refund.
  void push(ProStatus status) {
    owned = status;
    _updates.add(status);
  }

  @override
  bool get isAvailable => true;

  @override
  Stream<ProStatus> get statusUpdates => _updates.stream;

  @override
  Future<ProStatus> currentStatus() =>
      offline ? Completer<ProStatus>().future : Future.value(owned);

  @override
  Future<List<StoreItem>> products(List<String> ids) async => [
    for (final id in ids) ?_catalog[id],
  ];

  static const _catalog = {
    ProProducts.pro: StoreItem(
      id: ProProducts.pro,
      title: 'Logbite Pro',
      priceText: r'$9.99',
    ),
    ProProducts.trial: StoreItem(
      id: ProProducts.trial,
      title: '14-day Trial',
      priceText: r'$0.00',
    ),
    'com.nutriton.app.tip.small': StoreItem(
      id: 'com.nutriton.app.tip.small',
      title: 'Small Tip',
      priceText: r'$1.99',
    ),
  };

  @override
  Future<ProStatus?> buy(String id) async {
    bought.add(id);
    if (onBuy case final decide?) return decide(id);
    owned = switch (id) {
      ProProducts.pro => ProStatus(
        purchased: true,
        trialStartedAt: owned.trialStartedAt,
      ),
      ProProducts.trial => ProStatus(trialStartedAt: _now()),
      _ => owned,
    };
    return owned;
  }

  @override
  Future<ProStatus> restore() async {
    restores++;
    if (restoreError case final error?) throw error;
    return owned;
  }
}
