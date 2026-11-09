/// Logbite Pro: the one-time unlock, its trial, and which features it covers.
/// Pure Dart, so the rules are tested without a store. See
/// `PRODUCT.md`.
library;

/// App Store product ids. They must match App Store Connect and RevenueCat.
abstract final class ProProducts {
  /// The Pro unlock (non-consumable). The only product that grants the `pro`
  /// entitlement in RevenueCat.
  static const pro = 'com.nutriton.app.pro';

  /// The free "14-day Trial" (non-consumable, $0). Not attached to the
  /// entitlement: a non-consumable never expires, so the app times the trial
  /// from its purchase date instead.
  static const trial = 'com.nutriton.app.trial14';

  /// Tip jar (consumables), smallest first. They unlock nothing.
  static const tips = [
    'com.nutriton.app.tip.small',
    'com.nutriton.app.tip.medium',
    'com.nutriton.app.tip.large',
  ];
}

/// The RevenueCat entitlement that [ProProducts.pro] grants.
const proEntitlementId = 'pro';

/// How long the trial lasts from the moment it is started.
const proTrialDays = 14;

/// Users whose original App Store install has a build number below this get
/// Pro free (Apple's `originalApplicationVersion` is the build number on iOS).
/// Null turns grandfathering off. Leave it null unless a free version ships
/// to the App Store before Pro: until then nobody qualifies, and Apple's
/// sandbox reports every tester's original build as "1.0".
const int? grandfatherBeforeBuild = null;

/// The privacy policy, linked from the paywall (GitHub Pages, from
/// docs/privacy.md).
const privacyPolicyUrl =
    'https://andrew-a-cruz.github.io/nutriton_project/privacy';

/// Apple's standard licence agreement, used as the terms of use.
const termsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// What the store says this person owns, cached on the device so Pro works
/// offline and at launch before the store answers.
class ProStatus {
  const ProStatus({
    this.purchased = false,
    this.trialStartedAt,
    this.grandfathered = false,
  });

  /// Bought [ProProducts.pro] (or got it through Family Sharing).
  final bool purchased;

  /// When [ProProducts.trial] was taken, or null if never.
  final DateTime? trialStartedAt;

  /// Installed before Pro existed; see [grandfatherBeforeBuild].
  final bool grandfathered;

  static const none = ProStatus();

  @override
  bool operator ==(Object other) =>
      other is ProStatus &&
      other.purchased == purchased &&
      other.trialStartedAt == trialStartedAt &&
      other.grandfathered == grandfathered;

  @override
  int get hashCode => Object.hash(purchased, trialStartedAt, grandfathered);

  @override
  String toString() =>
      'ProStatus(purchased: $purchased, trialStartedAt: $trialStartedAt, '
      'grandfathered: $grandfathered)';
}

/// How someone has Pro right now.
enum ProAccess {
  /// No Pro. Every free feature still works.
  free,

  /// Inside the [proTrialDays] trial.
  trial,

  /// Bought, shared by family, or grandfathered. Never expires.
  owned;

  bool get isPro => this != free;
}

/// When a trial started at [startedAt] ends.
DateTime trialEndsAt(DateTime startedAt) =>
    startedAt.add(const Duration(days: proTrialDays));

/// The access [status] gives at [now].
ProAccess proAccess(ProStatus status, DateTime now) {
  if (status.purchased || status.grandfathered) return ProAccess.owned;
  final started = status.trialStartedAt;
  if (started != null && now.isBefore(trialEndsAt(started))) {
    return ProAccess.trial;
  }
  return ProAccess.free;
}

/// Whole days left in the trial at [now], counting a part day as a day, or
/// null when [status] is not in its trial.
int? trialDaysLeft(ProStatus status, DateTime now) {
  if (proAccess(status, now) != ProAccess.trial) return null;
  final left = trialEndsAt(status.trialStartedAt!).difference(now);
  return (left.inMinutes / Duration.minutesPerDay).ceil();
}

/// Whether [status] had a trial that is over, without owning Pro. The app
/// shows "Your trial ended" once when this turns true.
bool trialHasEnded(ProStatus status, DateTime now) =>
    status.trialStartedAt != null && proAccess(status, now) == ProAccess.free;

/// Whether an original install of build [originalAppVersion] predates Pro.
/// Only a whole build number qualifies ("41", or "41.0" as the sandbox
/// writes it); anything unreadable does not.
bool isGrandfathered(String? originalAppVersion, {int? beforeBuild}) {
  if (beforeBuild == null || originalAppVersion == null) return false;
  final build = double.tryParse(originalAppVersion.trim());
  return build != null &&
      build == build.truncateToDouble() &&
      build < beforeBuild;
}

/// The extras Pro unlocks. Everything not listed here is free.
enum ProFeature {
  widget(
    'Home Screen Widget',
    'Calories left today, at a glance.',
    available: true,
  ),
  appleHealth(
    'Apple Health',
    'Send nutrition to Health and read your weight from it.',
    available: true,
  ),
  iCloudSync(
    'iCloud Sync',
    'Your log on iPhone, iPad and Mac.',
    available: false,
  ),
  reports(
    'Shareable Reports',
    'A PDF of any date range, for a dietitian or doctor.',
    available: true,
  ),
  themes(
    'Themes and App Icons',
    'Make Logbite look the way you like.',
    available: false,
  );

  const ProFeature(this.title, this.description, {required this.available});

  final String title;
  final String description;

  /// Whether it is built. The paywall lists only these, so Pro never sells
  /// something that does not exist yet.
  final bool available;

  static List<ProFeature> get shipped => [
    for (final f in values)
      if (f.available) f,
  ];
}
