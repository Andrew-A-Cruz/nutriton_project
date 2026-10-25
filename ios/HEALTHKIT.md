# Apple Health (iOS)

The app writes daily nutrition to Apple Health and reads body weight from it, through the `health` package. Both are opt-in switches under Settings > Apple Health. Nothing here has been compiled or run: it was written without Xcode.

## What is already in the repo

- `Runner/Info.plist`: `NSHealthShareUsageDescription` (read) and `NSHealthUpdateUsageDescription` (write).
- `Runner/Runner.entitlements`: `com.apple.developer.healthkit` (true) and `com.apple.developer.healthkit.access` (empty array; no clinical records).

The entitlements file is **not yet referenced by `Runner.xcodeproj`**, so HealthKit does nothing until the steps below are done.

## Steps (Mac, Xcode)

1. Open `ios/Runner.xcworkspace`.
2. Target `Runner` > **Build Settings**: set `CODE_SIGN_ENTITLEMENTS` to `Runner/Runner.entitlements`, if the Today widget steps did not already (`TodayWidget/README.md`, step 6).
3. Target `Runner` > **Signing & Capabilities** > **+ Capability** > **HealthKit**. Leave "Clinical Health Records" and "Background Delivery" unticked. Xcode may rewrite `Runner.entitlements`; the HealthKit keys should stay as they are.
4. Run `cd ios && pod install`, then build and run on a **device** (Health is not available in every simulator setup).
5. In the app: Settings > Apple Health, switch on "Write nutrition" or "Read body weight". iOS shows its permission sheet for just that data.

## Free Apple team warning

The team is a free personal team. Free teams may not be able to provision the **HealthKit** capability (and the **App Groups** one the widget uses). Xcode then reports a provisioning-profile error such as "Personal development teams do not support the HealthKit capability", and the Runner target will not build while the entitlement is set. If so:

- Remove the HealthKit capability (and the two HealthKit keys from `Runner.entitlements`) to get a building app again. The Dart code is harmless without it: the switches' permission requests fail, so they stay off.
- A paid Apple Developer Program membership is the fix. Free-team builds also expire after 7 days.

This has not been verified against the real team.

## How it behaves

- **Write nutrition.** One sample per nutrient per day (energy, protein, carbs, fat, and fiber, sugar and sodium when recorded), spanning the day. Sodium goes in as grams (the app's mg divided by 1000), because HealthKit has no milligram option in the plugin. Editing, adding or deleting an entry deletes the app's own samples for that day and writes fresh totals; other apps' samples are never touched. Switching on writes the last 30 days; at launch only today is rewritten, then any day that changes while the app runs. Switching off leaves what was already written.
- **Read body weight.** The latest weight of each day over the last 90 days fills days with no weight of your own, marked "from Health" on Home. A weight you typed is never overwritten; editing a "from Health" weight makes it yours. Weights are never written back to Health. Runs at launch, on switching on, and at midnight rollover.
- Android (Health Connect) is not supported: the section is hidden and nothing is called.
