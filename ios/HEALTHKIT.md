# Apple Health (iOS)

The app writes daily nutrition to Apple Health and reads body weight from it, through the `health` package. Both are opt-in switches under Settings > Apple Health, and both are Logbite Pro features: without Pro the switches are lock badges, and no sync runs (what was already written to Health, or read from it, stays).

## What is already in the repo

- `Runner/Info.plist`: `NSHealthShareUsageDescription` (read) and `NSHealthUpdateUsageDescription` (write).
- `Runner/Runner.entitlements`: `com.apple.developer.healthkit` (true) and `com.apple.developer.healthkit.access` (empty array; no clinical records).

Runner's `CODE_SIGN_ENTITLEMENTS` is `Runner/Runner.entitlements` (set in October 2026), and the free personal team provisions HealthKit: a signed release build carries `com.apple.developer.healthkit`. Free-team builds still expire after 7 days.

## Checking it on a device

1. Install with the `install-iphone` skill (it unlocks Pro in its builds).
2. In the app: Settings > Apple Health, switch on "Write nutrition" or "Read body weight". iOS shows its permission sheet for just that data.
3. In the Health app: Browse > Nutrition shows Logbite's samples; Sharing > Apps > Logbite shows the permissions.

## How it behaves

- **Write nutrition.** One sample per nutrient per day (energy, protein, carbs, fat, and fiber, sugar and sodium when recorded), spanning the day. Sodium goes in as grams (the app's mg divided by 1000), because HealthKit has no milligram option in the plugin. Editing, adding or deleting an entry deletes the app's own samples for that day and writes fresh totals; other apps' samples are never touched. Switching on writes the last 30 days; at launch only today is rewritten, then any day that changes while the app runs. Switching off leaves what was already written.
- **Read body weight.** The latest weight of each day over the last 90 days fills days with no weight of your own, marked "from Health" on Home. A weight you typed is never overwritten; editing a "from Health" weight makes it yours. Weights are never written back to Health. Runs at launch, on switching on, and at midnight rollover.
- Android (Health Connect) is not supported: the section is hidden and nothing is called.
