# Food Log App — Android Plan

What it takes to ship Nutriton on Google Play with the same features as iOS. The app is Flutter, so most of it already runs on Android. The remaining work is in the platform plugins, the store and the Play release process.

> Related docs: [`GAME_PLAN.md`](./GAME_PLAN.md) · [`DATA_MODEL.md`](./DATA_MODEL.md) · [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) · [`FEATURE_PLAN.md`](./FEATURE_PLAN.md) · [`MONETIZATION_PLAN.md`](./MONETIZATION_PLAN.md)

---

## How Hard Is It?

**Moderate. Most of the app ports with no changes; four features need Android-specific work.**

All of the data layer, the UI, the logic in `core/` and the tests are plain Dart. Every native feature already sits behind an interface with a no-op fallback that `main` swaps in (`NotificationScheduler`, `WidgetPublisher`, `HealthService`, `StoreService`). So an Android build today should run the whole free app, with Pro, the widget and Health turned off. Nothing has to be pulled apart first.

| Area | State on Android | Effort |
|---|---|---|
| Database, logging, catalog, meals, Summary, goals, backup, barcode scan, Open Food Facts | Should work as is (all Dart, or plugins that support Android) | Test only |
| Reminders (M14) | Manifest, receivers, desugaring and the Android 13 permission request are all written | Small fix (status bar icon) |
| UI | Cupertino everywhere, which runs on Android and looks like iOS ([IMPLEMENTATION_PLAN Open Question 4](./IMPLEMENTATION_PLAN.md#open-questions)) | Test back button and edge-to-edge |
| Pro purchase (M21) | `RevenueCatStoreService` is iOS only; the $0 trial product cannot be made on Play | 2–3 days, plus a decision about the trial |
| Apple Health (M19) → Health Connect | Not built | 3–5 days, plus Play's health permission review |
| Home screen widget (M18) | Not built; the SwiftUI widget has to be rewritten in Kotlin | 2–4 days |
| iCloud sync (M20) | CloudKit does not exist on Android | Hide it; only a Supabase sync would cover Android |
| Play release | Signing is wired (`android/key.properties`); nothing else is set up | 1–2 days of work, **plus at least 14 days of required closed testing** |

**Estimate:** 2–3 days for a Play build of the free app, about 2–3 weeks of work for full parity. Play's closed-testing rule for new personal developer accounts (A6) adds at least two weeks before the first production release, so start it early.

**Recommended order:** release the free core first (A0–A2 then A6), then add the Pro purchase, Health Connect and the widget in later updates. The no-op fallbacks make each phase shippable.

---

## Milestones

### A0 — Toolchain (this Mac)

A debug build attempt on 2026-10-25 failed before compiling anything: Android Studio still bundles Java 11, and only SDK platforms 32 and 33 are installed. Flutter 3.41 needs JDK 17+ and compiles against SDK 36.

- [ ] Update Android Studio (bundles a current JDK) or install JDK 17+ and run `flutter config --jdk-dir=<path>`
- [ ] SDK Manager: install Android SDK Platform 36, a current Build-Tools, and the **cmdline-tools** component
- [ ] `flutter doctor --android-licenses`, then confirm `flutter doctor` is clean
- [ ] Create an emulator (a recent Pixel image with Google Play, so Play Billing and Health Connect can run) and pair a physical Android phone if one is available

**Done when:** `flutter build apk --debug` succeeds.

### A1 — First build and native config

- [ ] Fix whatever the first build reports. Likely places: plugin `minSdk` requirements, Kotlin/AGP versions in `android/settings.gradle.kts`, and the core library desugaring from M14 (the open item in [FEATURE_PLAN "Manual Mac Steps"](./FEATURE_PLAN.md#manual-mac-steps-before-the-next-ios-build))
- [ ] Set `minSdk = 26` in `android/app/build.gradle.kts` now. The `health` plugin needs it for Health Connect (A4), and raising it before the first release means no users are dropped later
- [ ] Change `MainActivity` to extend `FlutterFragmentActivity`. Health Connect's permission flow needs it, and it is harmless otherwise
- [ ] Notification small icon: `AndroidInitializationSettings('@mipmap/ic_launcher')` in `local_notification_scheduler.dart` draws as a white square in the status bar. Add a monochrome `drawable/ic_stat_nutriton` (white on transparent) and use it
- [ ] Remove the leftover `TODO` comment on `applicationId` in `build.gradle.kts` (`com.nutriton.app` is final)
- [ ] Barcode scanner: `mobile_scanner` bundles ML Kit by default (a few MB per ABI). Keep it, or switch to the unbundled model through its Gradle property if APK size matters

**Done when:** a release build (`flutter run --release`) starts on the emulator and on a phone.

### A2 — Run the free app on Android

The UI stays Cupertino; that was decided for v1 and costs nothing here. What needs checking is Android behavior that iOS never exercises.

- [ ] **System back.** In each tab (`CupertinoTabView` in `app.dart`), back must pop that tab's stack before it leaves the app. Check pushed pages, `showCupertinoModalPopup` sheets, dialogs, the paywall, onboarding and the tour. Check the predictive back gesture too, which is on by default when targeting SDK 36. If a nested navigator doesn't get back presses, wrap it in `NavigatorPopHandler`
- [ ] **Edge-to-edge** (enforced when targeting SDK 35+): the status bar icons are readable in light and dark mode, and the `CupertinoTabBar` and bottom buttons clear the gesture bar and the 3-button navigation bar
- [ ] **Reminders:** the permission prompt on Android 13+, a reminder arrives (a few minutes late is expected, since scheduling is inexact), it still arrives after a reboot and after an app update, and it is cancelled once the day has an entry
- [ ] **Backup:** export through the share sheet (Drive, Gmail, Files), then import from Downloads and from Drive through `file_picker`; the counts preview appears and the restore works
- [ ] **Barcode scan:** the camera permission prompt, a scan, a denied permission, and the Open Food Facts lookup
- [ ] Keyboard: the Add Food sheet and forms resize correctly (`adjustResize` is set) and no field is hidden behind the keyboard
- [ ] Font scaling at the largest system size and a small-screen phone; text that assumed SF Pro widths may wrap differently in Roboto
- [ ] Pro with a no-op store: until A3 ships, check what the Pro row in Settings, the paywall and the trial-ended notice do when `NoopStoreService` is in use, and hide them on Android if they would offer a purchase that cannot go through
- [ ] Run `flutter test`; no test should depend on the host platform

**Done when:** every feature in the Free column of [MONETIZATION_PLAN](./MONETIZATION_PLAN.md#free-vs-pro) works on an Android phone, and nothing on screen offers Pro.

### A3 — Pro purchase on Google Play

RevenueCat already handles Play Billing with the same entitlements, so most of the work is setup.

- [ ] Google Play Console: a payments profile and merchant account; sign up for the 15% service fee tier for the first $1M (Play's counterpart to the Small Business Program)
- [ ] Create the products in Play Console with the same IDs as App Store Connect: `com.nutriton.app.pro` (one-time product) and the three tip consumables
- [ ] RevenueCat: add the Android app, link a Play service account, and attach the Play products to the `pro` entitlement
- [ ] `RevenueCatStoreService`: read a second key, `REVENUECAT_ANDROID_KEY`, choose the key by platform, and allow Android in `isSupported`
- [ ] **Trial:** Play does not allow $0 one-time products, so `com.nutriton.app.trial14` cannot exist there. See Open Question 1. The trial logic in `core/pro.dart` keys off the trial product's purchase date, so whichever option is chosen fits behind `StoreService`
- [ ] Grandfathering needs no work: `originalApplicationVersion` is iOS only, so `isGrandfathered` returns false on Android, which is correct for a platform with no early users
- [ ] Store-neutral wording. These strings name the App Store: `pro_section.dart`, `paywall_view.dart` (two) and `revenuecat_store_service.dart` (two). Say "the store", or name Google Play on Android
- [ ] Review prompt: `in_app_review` uses Play's in-app review API on Android. It shows nothing in builds that were not installed from Play, so test it through internal testing
- [ ] Test with Play license testers on the internal track: buy, reinstall and restore, refund (Pro locks, data stays), launch offline

**Done when:** the same "Done when" as M21 in [MONETIZATION_PLAN](./MONETIZATION_PLAN.md#milestone-m21--pro-unlock) passes with a Play test account.

### A4 — Health Connect (M19 on Android)

The `health` plugin talks to Health Connect on Android, so `HealthService`, `HealthSync`, the providers and the Settings switches stay. What changes is the platform setup and one Android branch in `PluginHealthService`.

- [ ] Manifest: `android.permission.health.WRITE_NUTRITION` and `android.permission.health.READ_WEIGHT`; the `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` intent filter on `MainActivity` and the `VIEW_PERMISSION_USAGE` activity alias (both open the privacy policy); a `<queries>` entry for the Health Connect package. Follow the `health` plugin's Android setup for its exact version
- [ ] Availability: Health Connect is built into Android 14+, but on Android 9–13 it is a separate app. Check the plugin's SDK status, offer to install it from Play when it is missing, and hide the section on devices where it is unavailable
- [ ] **Nutrition is one record, not one sample per nutrient.** Health Connect stores a `NutritionRecord` holding every nutrient for a time range. On Android, write one record per day from the same totals that `nutritionSamples` produces (the plugin's meal-writing call does this; confirm for the installed version). Delete-then-write stays idempotent because apps can only delete their own records
- [ ] Sodium: confirm the unit the plugin expects on Android before reusing the iOS mg → g conversion
- [ ] **History limit:** by default Health Connect lets an app read only about 30 days of data from before permission was first granted. The 90-day weight read gets less on first enable unless the app also requests `READ_HEALTH_DATA_HISTORY`. Decide whether 30 days is enough
- [ ] Unlike HealthKit, Health Connect reports whether read access was granted. Use that for weight, so "Read body weight" can show a real refusal instead of iOS's "the prompt was shown"
- [ ] Rename for Android: `isSupported` allows Android; the Settings section (`apple_health_section.dart`), `ProFeature.appleHealth`'s title and text, the "from Health" label and the trial-ended notice say "Health Connect" on Android; the denied-access hint points to Health Connect's settings instead of iOS Settings
- [ ] Play Console: fill in the Health Connect permissions declaration (why each permission is needed). Google reviews it, which can take days, and a privacy policy URL is required
- [ ] Tests: the record mapping as a pure function next to `nutritionSamples`, plus a platform-labels test

**Done when:** turning on "Write nutrition" puts the last 30 days into Health Connect, an edit rewrites that day, and "Read body weight" fills `body_weights` without touching manual readings, on Android 14 and on an Android 13 phone with the Health Connect app.

### A5 — Home screen widget (M18 on Android)

`buildWidgetSnapshot` and `widgetPlanProvider` are reused as they are. Only the native widget and the publish call are new.

- [ ] Write the widget in Kotlin under `android/app/src/main/`: an app widget receiver, its `appwidget-provider` XML (size, preview, update period) and the `<receiver>` in the manifest. Jetpack Glance (supported by `home_widget`) is closest to SwiftUI; plain `RemoteViews` with a circular `ProgressBar` is fewer dependencies
- [ ] It reads the same keys `WidgetSnapshot.toMap()` writes, through `home_widget`'s SharedPreferences, and draws remaining calories, a progress ring, the over-goal colour and the locked state, like `TodayWidget.swift`
- [ ] Midnight reset: Android widgets have no timeline. Compare the snapshot's `dateKey` with today's date on every update and show `emptyValueText` once the date has moved on. Add an inexact alarm at midnight, or accept the 30-minute minimum update period
- [ ] `HomeWidgetPublisher`: allow Android in `isSupported`, call `setAppGroupId` only on iOS, and pass the receiver's qualified Android name to `updateWidget`
- [ ] Light and dark themes, plus the Android 12+ rounded corners and dynamic sizing

**Done when:** logging food updates the widget within seconds, it shows an empty day after midnight without opening the app, and it shows "Pro" when Pro is off.

### A6 — Play Store release

- [ ] Google Play developer account ($25, once), with identity verification
- [ ] Upload keystore and `android/key.properties` (already read by `build.gradle.kts`; keep both backed up outside the repo). Opt in to Play App Signing
- [ ] Build an App Bundle: `flutter build appbundle`. Play requires 16 KB memory page support for apps targeting Android 15+; check the bundle's native libraries (`sqlite3`, ML Kit) in Play Console's App bundle explorer and update the plugins if any is flagged
- [ ] Listing: description, phone screenshots (Cupertino UI is fine), a 512 px icon, a feature graphic, and the category (Health & Fitness)
- [ ] App content: privacy policy URL (the same one as iOS, plus Health Connect), **Data safety** form (data stays on device; Open Food Facts lookups send barcodes; RevenueCat handles purchases), content rating, target audience, and the health apps declaration
- [ ] **Closed testing:** personal developer accounts created after November 2023 must run a closed test with at least 12 testers opted in for 14 days in a row before they can apply for production. Recruit testers when A2 is done, not at the end
- [ ] Internal testing track for day-to-day builds; optionally an `install-android` skill next to `install-iphone` (`flutter build apk --release` + `adb install`)

**Done when:** the app is live in production on Google Play.

---

## Open Questions

1. **Trial on Android.** Play has no free one-time products. Options: (a) no trial on Android, just Buy; (b) a trial kept on the device, started on first launch and reset by a reinstall; (c) a Play subscription with a 14-day free trial, which changes the model from a one-time purchase. Recommended: (a) for the first release, (b) if Android purchase rates are low.
2. **Sync.** M20's CloudKit option leaves Android users without sync. If Android gets real use, it favors Supabase (Pro+) in [MONETIZATION_PLAN Open Question 3](./MONETIZATION_PLAN.md#open-questions). On Android, the "iCloud Sync" Pro feature should be hidden rather than renamed.
3. **Material look.** Cupertino on Android was decided for v1 and works. Revisit only if Android reviews complain; adaptive widgets would touch about 46 files under `lib/views/`.
4. **Cross-platform Pro.** A Pro purchase on iOS does not unlock Android, and the reverse, because there are no accounts. RevenueCat can share entitlements only with a user ID, which conflicts with "no account". Recommended: keep the platforms separate and say so on the paywall.
