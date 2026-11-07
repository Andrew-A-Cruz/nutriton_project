import '../../core/pro.dart';

/// A product as the store sells it, with its price already formatted for the
/// user's storefront. Prices are never hard-coded in the app.
class StoreItem {
  const StoreItem({
    required this.id,
    required this.title,
    required this.priceText,
  });

  final String id;
  final String title;
  final String priceText;
}

/// Why a purchase or restore did not go through.
class StoreException implements Exception {
  const StoreException(this.message);

  final String message;

  @override
  String toString() => 'StoreException: $message';
}

/// What the app needs from the App Store. The real implementation wraps
/// RevenueCat (`RevenueCatStoreService`); tests use a fake.
abstract class StoreService {
  /// Whether purchases can be made at all. False when the store is not set up
  /// for this build or platform; the paywall then says so.
  bool get isAvailable;

  /// What the user owns, every time it changes (a purchase, a restore, a
  /// refund, Family Sharing). May start with the current value.
  Stream<ProStatus> get statusUpdates;

  /// What the user owns now, asking the store.
  Future<ProStatus> currentStatus();

  /// The products with these [ids] the store can sell, in [ids] order.
  /// Products the store does not know are left out.
  Future<List<StoreItem>> products(List<String> ids);

  /// Buys product [id] and returns what the user owns afterwards, or null if
  /// they cancelled. Throws [StoreException] when the purchase fails.
  Future<ProStatus?> buy(String id);

  /// Restores earlier purchases. Throws [StoreException] on failure.
  Future<ProStatus> restore();
}

/// For builds without a store (no RevenueCat key, unsupported platforms), and
/// the default until `main` installs the real one. Owns nothing, sells
/// nothing.
class NoopStoreService implements StoreService {
  const NoopStoreService();

  @override
  bool get isAvailable => false;

  @override
  Stream<ProStatus> get statusUpdates => const Stream.empty();

  @override
  Future<ProStatus> currentStatus() async => ProStatus.none;

  @override
  Future<List<StoreItem>> products(List<String> ids) async => const [];

  @override
  Future<ProStatus?> buy(String id) async =>
      throw const StoreException('Purchases are not available in this build.');

  @override
  Future<ProStatus> restore() async =>
      throw const StoreException('Purchases are not available in this build.');
}
