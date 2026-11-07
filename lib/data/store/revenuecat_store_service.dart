import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/pro.dart';
import 'store_service.dart';

/// [StoreService] over RevenueCat, which handles StoreKit, receipt checks and
/// restores. Not covered by tests, which would need the store.
///
/// The public iOS SDK key comes from `--dart-define=REVENUECAT_IOS_KEY=...`.
/// Without it [isSupported] is false and `main` uses [NoopStoreService].
class RevenueCatStoreService implements StoreService {
  RevenueCatStoreService();

  static const _apiKey = String.fromEnvironment('REVENUECAT_IOS_KEY');

  /// Whether this build can sell anything: iOS, with a key configured.
  static bool get isSupported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      _apiKey.isNotEmpty;

  final _updates = StreamController<ProStatus>.broadcast();
  Future<void>? _configured;

  Future<void> _ready() => _configured ??= () async {
    await Purchases.configure(PurchasesConfiguration(_apiKey));
    Purchases.addCustomerInfoUpdateListener(
      (info) => _updates.add(_statusOf(info)),
    );
  }();

  @override
  bool get isAvailable => true;

  @override
  Stream<ProStatus> get statusUpdates {
    unawaited(_ready().catchError((Object _) {}));
    return _updates.stream;
  }

  @override
  Future<ProStatus> currentStatus() async {
    await _ready();
    return _statusOf(await Purchases.getCustomerInfo());
  }

  @override
  Future<List<StoreItem>> products(List<String> ids) async {
    await _ready();
    final found = await Purchases.getProducts(
      ids,
      productCategory: ProductCategory.nonSubscription,
    );
    final byId = {for (final p in found) p.identifier: p};
    return [
      for (final id in ids)
        if (byId[id] case final StoreProduct p)
          StoreItem(id: id, title: p.title, priceText: p.priceString),
    ];
  }

  @override
  Future<ProStatus?> buy(String id) async {
    await _ready();
    final found = await Purchases.getProducts([
      id,
    ], productCategory: ProductCategory.nonSubscription);
    if (found.isEmpty) {
      throw const StoreException('This item is not available right now.');
    }
    try {
      final result = await Purchases.purchase(
        PurchaseParams.storeProduct(found.first),
      );
      return _statusOf(result.customerInfo);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      throw StoreException(_message(e));
    }
  }

  @override
  Future<ProStatus> restore() async {
    await _ready();
    try {
      return _statusOf(await Purchases.restorePurchases());
    } on PlatformException catch (e) {
      throw StoreException(_message(e));
    }
  }

  static String _message(PlatformException e) =>
      switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.networkError =>
          'Could not reach the App Store. Check your connection.',
        PurchasesErrorCode.purchaseNotAllowedError =>
          'Purchases are turned off on this device.',
        PurchasesErrorCode.paymentPendingError =>
          'The purchase is waiting for approval.',
        _ => e.message ?? 'The App Store could not complete this.',
      };

  static ProStatus _statusOf(CustomerInfo info) {
    DateTime? trialStart;
    for (final t in info.nonSubscriptionTransactions) {
      if (t.productIdentifier != ProProducts.trial) continue;
      final at = DateTime.tryParse(t.purchaseDate)?.toLocal();
      if (at != null && (trialStart == null || at.isBefore(trialStart))) {
        trialStart = at;
      }
    }
    return ProStatus(
      purchased: info.entitlements.active.containsKey(proEntitlementId),
      trialStartedAt: trialStart,
      grandfathered: isGrandfathered(
        info.originalApplicationVersion,
        beforeBuild: grandfatherBeforeBuild,
      ),
    );
  }
}
