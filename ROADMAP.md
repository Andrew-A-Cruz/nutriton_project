# Logbite — Roadmap

Every open item in one place. Items are listed in order of impact, most important first; what blocks each one is noted beside it, and does not change its place. The rules for what is free or Pro, the technical decisions and what's already built are in [`PRODUCT.md`](./PRODUCT.md); the schema is in [`DATA_MODEL.md`](./DATA_MODEL.md).

**Sizes:** **S** = about a day or less · **M** = 2–5 days · **L** = 1–2 weeks · **XL** = needs its own detailed plan first.

When an item is finished, delete it here and add a line to [What's Built](./PRODUCT.md#whats-built). When a new idea comes up, give it a size and a blocker and place it by impact. A schema change takes the next version number when work starts (v14 is next).

---

## Blockers

| ID | Blocker | What clears it | Waiting on it |
|---|---|---|---|
| **B1** | Paid Apple Developer account ($99/yr) | Buy it; then App Store Connect agreements, tax and banking | [Sell Pro on iOS](#sell-pro-on-ios-m21-launch), [M20 iCloud sync](#m20--icloud-sync) |
| **B2** | Google Play developer account ($25, once) and a 14-day closed test with 12+ testers | Create the account; recruit testers as soon as [A2](#a2--check-the-free-app-on-android) is done | [A3](#a3--pro-purchase-on-google-play), [A6](#a6--play-store-release) |
| **B3** | A phone in hand for manual testing | Install a build (`install-iphone` skill) and work through the checklist | [iPhone checks](#iphone-checks), part of [A2](#a2--check-the-free-app-on-android) |
| **D1–D8** | A decision that is yours to make | Accept the proposed answer, or choose another | See [Decisions](#decisions) |
| **Dep** | Another roadmap item has to come first | Finish that item | [Adaptive goals](#adaptive-goals), [A4](#a4--health-connect), [A5](#a5--android-home-screen-widget) |

The privacy policy is live ([`docs/privacy.md`](./docs/privacy.md), contact logbite.app@gmail.com), so it no longer blocks selling Pro, Health Connect or the Play listing. A new network call or Health type means a policy update.

---

## At a Glance

In order of impact.

| # | Item | Size | Tier | Blocked by | Why it ranks here |
|---|---|---|---|---|---|
| 1 | [iPhone checks](#iphone-checks) | S | — | B3 | Much of what is built, including everything added this month, has never run on a real phone, and every release depends on it |
| 2 | [Sell Pro on iOS (M21 launch)](#sell-pro-on-ios-m21-launch) | M | Pro | B1, D6 | Nothing earns money until this is done, and the App Store release has no plan yet |
| 3 | [A2 — Check the free app on Android](#a2--check-the-free-app-on-android) | S | — | — (an API 35+ emulator image; a physical phone for the last checks) | The last step before Android can be released |
| 4 | [A6 — Play Store release](#a6--play-store-release) | M + 14 days | — | B2, A2 | Puts the free app in front of Android users; the 14-day closed test is the long wait |
| 5 | [M25 — Target weight guide](#m25--target-weight-guide) | M | Free | D4 | A first-week feature for new users, and adaptive goals needs it |
| 6 | [M24 — Fast food menus](#m24--fast-food-menus) | L | Free | D3 | Everyday logging value; the bundled-food reader it needs is built |
| 7 | [Adaptive goals](#adaptive-goals) | L | Free | Dep: M25 | The main thing competitors charge for, offered free |
| 8 | [CSV export of the log](#csv-export-of-the-log) | S | Free (proposed) | D1 | Small, and part of the promise that data is portable |
| 9 | [A3 — Pro purchase on Google Play](#a3--pro-purchase-on-google-play) | M | Pro | B2, D5 | Android revenue; only matters once A6 is out |
| 10 | [A4 — Health Connect](#a4--health-connect) | M | Pro | Dep: A3 | A Pro extra on Android |
| 11 | [A5 — Android home screen widget](#a5--android-home-screen-widget) | M | Pro | Dep: A3 | A Pro extra on Android |
| 12 | [Siri Shortcuts / App Intents](#siri-shortcuts--app-intents) | L | ? | D2 | A faster way to log for some users |
| 13 | [A1 — Android native config leftovers](#a1--android-native-config-leftovers) | S | — | D8 | Only affects the Play download size |
| 14 | [M20 — iCloud sync](#m20--icloud-sync) | XL | Pro | B1, D7 | The largest job, for a second device that may never exist; D7 may cut it |

**Can start now:** A2 (rank 3). **Cheapest to unblock:** accepting the proposed answers to D1, D4 and D3 opens CSV export, M25 and M24 at no cost, and installing a build on the iPhone opens rank 1.

---

## Decisions

Each decision is yours to make. Most have a proposed answer; accepting it unblocks the item.

| ID | Decision | Proposed | Unblocks |
|---|---|---|---|
| **D1** | Is a CSV export of the log free or Pro? | Free: it is data portability (Principle 1). Pro keeps the formatted PDF report | CSV export |
| **D2** | Is Siri Shortcuts free (a faster way to log, Principle 3) or Pro (connects the app to something else)? | No proposal yet | Siri Shortcuts |
| **D3** | Where fast food menu values come from, and whether the license lets them ship in the app | Hand-entered from each chain's published nutrition info for a short list of US chains, USDA FoodData Central where it covers an item, and the source and date stored on each item. Open Food Facts (ODbL share-alike) and paid APIs are out | M24 |
| **D4** | Target weight guide defaults and wording | Steady pace by default, the calorie floor rule, the screen's text reviewed by someone outside the project before release. Decide too whether to offer the WHO's lower BMI cutoffs for Asian populations | M25, and then adaptive goals |
| **D5** | Trial on Android (Play has no $0 one-time products) | No trial on Android for the first release, just Buy; a trial kept on the device if purchase rates are low. (A Play subscription trial would change the model) | A3 |
| **D6** | Pro price | $9.99 launch then $14.99 is a guess (MacroFactor ~$72/yr, Cronometer Gold ~$55/yr). Pro now has four features (widget, Apple Health, reports, themes and icons) | Selling Pro |
| **D7** | Is a second device actually planned? If not, M20 can be cut | No proposal yet | M20 |
| **D8** | Bundle ML Kit's models in the Android app, or let Google Play services download them? Bundled: works offline at once, but the label scan's text model adds about 11 MB per ABI and the barcode model a few more. Unbundled: a much smaller download, but the first scan waits for the model and needs Play services | Bundled, as built, until the Play listing's size matters | A1 |

---

## Items, by Impact

### iPhone checks
**S · B3**

Built but never tried on a real iPhone:

- [ ] Reminders and their permission prompt (M14), camera barcode scanning (M16), the live Open Food Facts lookup
- [ ] Add the "Today" widget and check it follows the log (M18)
- [ ] Turn on both Apple Health options and check the data in the Health app (M19)
- [ ] Automatic backups: the Backups folder shows under On My iPhone > Logbite in Files
- [ ] The Done bar sits flush on the number keyboard (onboarding goals, a food form, the servings dialog) and closes it
- [ ] With the phone set to a comma-decimal region (e.g. Germany), decimals show with a comma and typed commas still work
- [ ] Log a food by a portion (e.g. 1.5 cups) and check the servings
- [ ] Haptics: a light tap on logging, a firmer one on swipe-delete
- [ ] Water: + and − on Today; Fasting: start a fast, lock the phone, and check the time on return
- [ ] Appearance: change the accent colour, and change the app icon (iOS shows its own "You have changed the icon" alert) and back
- [ ] Scan a real nutrition label with the camera and from a photo: a US label, an EU table, a curved or glossy package. Check each value read
- [ ] Search Add Food for a starter food ("banana"), log it, and find it in the Catalog with its portions
- [ ] On an iPad or with the phone on its side: Add Food sits beside the day and logs to it; Summary's charts get their own column
- [ ] Share a month's report from Summary (the share sheet, then open the PDF in Files or Mail) and read it as a dietitian would (M22)

Pro features are unlocked in `install-iphone` builds. The Android phone checks are part of [A2](#a2--check-the-free-app-on-android).

### Sell Pro on iOS (M21 launch)
**M · B1, D6**

M21 is built and tested in code. To sell it:

- [ ] Paid Apple Developer account; App Store Small Business Program (15%); Paid Applications agreement, tax and banking
- [ ] Create the [store products](./PRODUCT.md#store-products) in App Store Connect, Family Sharing on for Pro
- [ ] RevenueCat project with the App Store app; entitlement `pro` granted by `com.nutriton.app.pro` **only**. Builds read the key from `--dart-define=REVENUECAT_IOS_KEY=...`
- [ ] On the first archive, check Xcode's privacy report (Organizer > Generate Privacy Report). The app and widget manifests are in place; health, home_widget, purchases_flutter and sqlite3 ship none of their own, and the app manifest covers their UserDefaults and file timestamp use
- [ ] Sandbox testing (StoreKit config `ios/Runner/Nutriton.storekit` for local runs): buy, restore after reinstall, refund (Pro locks, data stays), offline launch, trial expiry, Family Sharing on a second account
- [ ] Decide grandfathering: it stays off unless a free version ships before Pro (`grandfatherBeforeBuild` in `core/pro.dart`)

**Done when:** a sandbox account can start the trial, buy Pro, delete and reinstall, restore, and have every Pro feature unlocked with no data lost.

### A2 — Check the free app on Android
Checked on an API 33 emulator (the separate "Logbite Test API 33" AVD, which has room to install the app): onboarding, saving, the keyboard resizing forms and dialogs, dark mode, system back on pushed pages, sheets, dialogs and the app tour, a backup import from Downloads, starter foods and the nutrition label scan from a chosen photo. Pro is hidden on Android until A3. Still to check:

- [ ] **Predictive back** (on by default at SDK 36) and **edge-to-edge** (enforced from SDK 35): status bar icons readable in light and dark; the tab bar and bottom buttons clear the gesture bar and the 3-button bar. Needs an API 35 or 36 system image; only API 33 is installed
- [ ] Back at the root of the Catalog or Summary tab leaves the app. Decide whether it should go to Today first
- [ ] The largest font size and a small screen (Roboto widths differ from SF Pro)
- [ ] Backup import from Drive
- [ ] On a physical phone: decode a real barcode; reminders after an app update; the label scan from the camera

**Done when:** every free feature works on an Android phone and nothing on screen offers Pro. Recruit closed testers for [A6](#a6--play-store-release) at this point.

### A6 — Play Store release
**M + at least 14 days · B2, after A2**

- [ ] Developer account with identity verification
- [ ] Upload keystore and `android/key.properties` (see README), backed up outside the repo; opt in to Play App Signing
- [ ] `flutter build appbundle`; check 16 KB page support for `sqlite3` and ML Kit in the App bundle explorer
- [ ] Listing: description, screenshots, 512 px icon, feature graphic, Health & Fitness
- [ ] App content: privacy policy, **Data safety** form, content rating, target audience, health apps declaration
- [ ] **Closed test:** 12+ testers opted in for 14 days in a row before production can be requested (personal accounts after November 2023)
- [ ] Optional: an `install-android` skill (`flutter build apk --release` + `adb install`)

**Done when:** the app is live on Google Play. Recommended order: release the free app first, then A3, A4 and A5 as updates.

### M25 — Target weight guide
**M · Free · preferences only · blocked by D4**

Helps the user pick a reasonable target weight and pace from height, weight, age, sex and activity. It suggests; the user decides.

- [ ] **Profile inputs** in a new Settings section ("Body and activity") and an optional onboarding step: `height_cm` (entered in cm or ft/in to match `body_weight_unit`), `birth_year`, `sex_for_bmr` (female, male or skip), `activity_level` (sedentary to very active). Current weight is the latest weigh-in, or entered here and saved as today's. Inputs stay on the device; say so. Include them in the backup preferences, optional on read
- [ ] **Pure math in `core/body_goal.dart`:** BMI and the 18.5–24.9 band at the user's height; Mifflin-St Jeor times the activity factor (1.2 / 1.375 / 1.55 / 1.725 / 1.9), and no calories without age or sex; pace of about 0.25–1% of body weight per week for loss (gentle, steady, faster; steady by default), smaller for gain, using ~7,700 kcal per kg, with a target date; **a floor**: never suggest a goal below resting energy or ~1,200 kcal, and offer the fastest pace that stays above it
- [ ] **The screen:** current BMI and band, a suggested target (nearest edge of the band, or current weight if inside it), the pace choice, the daily calorie goal and the date
- [ ] **Saving:** "Use this plan" saves `goal_weight_kg` and, after a confirm, the calorie goal. Protein, carbs and fat goals are left alone
- [ ] **Where it shows:** a dashed target line on the Summary weight chart and "n kg to go" on Home's weigh-in row. When the 7-day average reaches the target, offer a maintenance goal
- [ ] **Limits, stated on screen:** BMI doesn't tell muscle from fat and reads differently for athletes, older adults and some ethnic groups. Under 18, show only a note to talk to a doctor. A line that this isn't medical advice, with a professional suggested for pregnancy, medical conditions or a history of disordered eating. Neutral wording, no "ideal body" language
- [ ] Tests: BMI at metric and imperial heights, Mifflin-St Jeor against worked examples, each activity factor, the floor, no calories without age or sex, under 18, the target date, saving only after the confirm, the chart line

**Done when:** a user can see their healthy band, pick a target and pace, and save a target weight and calorie goal that show on Home and Summary.

### M24 — Fast food menus
**L · Free · schema v14 (`food_items.menu_item_id`, `menu_version`) · blocked by D3**

**Detailed plan:** [`M24_FAST_FOOD_MENUS_PLAN.md`](./M24_FAST_FOOD_MENUS_PLAN.md). It wins where it differs from the list below.

Log a menu item from a common chain in a few taps. Most of the work is gathering and checking the data, not the code. The starter foods already built the bundled-file reader and search (`core/bundled_foods.dart`) and the copy into the catalog (`CatalogRepository.adoptBundledFood`, which matches by name; `menu_item_id` replaces that here).

- [ ] **Data:** the 15–20 largest US chains, each item with its source and the date checked, re-checked a few times a year
- [ ] **Bundled, offline:** `assets/menus/menus.json` (`version`, `checkedAt`, `chains[]` → `items[]` with category, the seven nutrients and `servingWeightG`). Values per item as served; each size is its own item. Updated with app releases
- [ ] `MenuRepository` with a pure parser in `core/`; reject items with negative values or no calories
- [ ] **Add Food:** a "Restaurants" entry → chains (names only, no logos) → items by category, with search within a chain and across all
- [ ] **Logging:** the normal servings flow. The first log saves the item as a catalog food (so it shows in Recent and can go in meals and plans); `menu_item_id` stops a second copy
- [ ] **Edits stay the user's:** an edited menu food is no longer updated. An unedited one takes newer values from a new release; past entries keep their snapshot
- [ ] "Values from <chain>, checked <month year>. Recipes change." with a link to report a wrong value (`url_launcher`)
- [ ] Backup: `menu_item_id` optional on read. Migration test v13 → v14
- [ ] Tests: the parser (valid, bad rows skipped, newer version), search across chains, first log makes one catalog food and the second reuses it, an edited food isn't updated, the Add sheet flow

**Done when:** a medium fries from a listed chain can be logged in under five taps, with no typing except the search.

### Adaptive goals
**L · Free · no schema change · after M25**

MacroFactor's main paid feature, and the app already stores intake and body weight. M25 gives the starting estimate; this re-estimates energy use weekly from average intake and the weight trend, and suggests a goal change. Runs on the device. Suggest only; never change a goal without a confirm.

### CSV export of the log
**S · Free (if D1 is accepted) · no schema change**

One row per entry (date, name, type, macros), readable in a spreadsheet, from the Backup section in Settings.

### A3 — Pro purchase on Google Play
**M · B2, D5**

RevenueCat handles Play Billing with the same entitlements.

- [ ] Play Console payments profile and merchant account; the 15% fee tier
- [ ] Products with the same IDs as iOS (`com.nutriton.app.pro` and the tips); attach them to `pro` in RevenueCat with a Play service account
- [ ] `RevenueCatStoreService`: read `REVENUECAT_ANDROID_KEY`, pick the key by platform, allow Android in `isSupported`
- [ ] Trial per D5 (it fits behind `StoreService`). Grandfathering needs nothing: `isGrandfathered` is false on Android
- [ ] Store-neutral wording in `pro_section.dart`, `paywall_view.dart` (two) and `revenuecat_store_service.dart` (two)
- [ ] Test with license testers on the internal track: buy, reinstall and restore, refund, offline launch, and the review prompt (it only shows in Play-installed builds)

**Done when:** the iOS "Done when" above passes with a Play test account.

### A4 — Health Connect
**M · Pro · after A3** (until Android can sell Pro, it would be locked for everyone). Also needs the privacy policy and Play's health permission review, which can take days.

The `health` plugin talks to Health Connect, so `HealthService`, `HealthSync`, the providers and the Settings switches stay. What changes:

- [ ] Manifest: `health.WRITE_NUTRITION` and `health.READ_WEIGHT`; the permissions-rationale intent filter and `VIEW_PERMISSION_USAGE` alias (both open the privacy policy); a `<queries>` entry for Health Connect. Follow the plugin's setup for its version
- [ ] Availability: built into Android 14+, a separate app on 9–13. Offer to install it when missing; hide the section where unavailable
- [ ] **Nutrition is one `NutritionRecord` per time range**, not one sample per nutrient. Write one record per day from the same totals as `nutritionSamples`. Delete-then-write stays idempotent
- [ ] Confirm the sodium unit the plugin expects on Android
- [ ] **History limit:** by default only ~30 days before permission was granted can be read. Decide whether to request `READ_HEALTH_DATA_HISTORY` for the 90-day weight read
- [ ] Health Connect reports refused reads, so "Read body weight" can show a real refusal
- [ ] Say "Health Connect" on Android: the Settings section, `ProFeature.appleHealth`'s text, the "from Health" label, the trial notice, and the denied-access hint
- [ ] Play Console: the Health Connect permissions declaration
- [ ] Tests: the record mapping as a pure function; platform labels

**Done when:** "Write nutrition" puts the last 30 days into Health Connect, an edit rewrites that day, and "Read body weight" fills `body_weights` without touching manual readings, on Android 14 and on Android 13 with the Health Connect app.

### A5 — Android home screen widget
**M · Pro · after A3**

`buildWidgetSnapshot` and `widgetPlanProvider` are reused; the native widget is new.

- [ ] A Kotlin widget under `android/app/src/main/` (Jetpack Glance, or `RemoteViews` with a circular `ProgressBar`), its `appwidget-provider` XML and the manifest `<receiver>`
- [ ] It reads the keys `WidgetSnapshot.toMap()` writes and draws remaining calories, the ring, the over-goal colour and the locked state, like `TodayWidget.swift`
- [ ] Midnight: no timelines on Android. Compare the snapshot's `dateKey` with today on every update; add an inexact midnight alarm or accept the 30-minute minimum period
- [ ] `HomeWidgetPublisher`: allow Android, call `setAppGroupId` only on iOS, pass the receiver's qualified name to `updateWidget`
- [ ] Light and dark, Android 12+ rounded corners and sizing

**Done when:** logging updates the widget within seconds, it shows an empty day after midnight without opening the app, and it shows "Pro" when Pro is off.

### Siri Shortcuts / App Intents
**L · tier set by D2 · no schema change**

"Log my usual breakfast" or "How many calories are left?" from Siri, Spotlight or the Action button. Needs a Swift App Intents target and a platform channel, like the widget.

### A1 — Android native config leftovers
**S · blocked by D8**

The application ID is `com.andrewcruz.logbite` (permanent after the first Play upload) and `minSdk` is 26. Builds use Homebrew's `openjdk@17` (`flutter config --jdk-dir`); Android Studio's bundled Java 11 is too old. What's left:

- [ ] Model size: `mobile_scanner` bundles ML Kit's barcode model and the label scan bundles its text model (`com.google.mlkit:text-recognition` in `android/app/build.gradle.kts`). Keep them, or switch each to the unbundled model (`mobile_scanner`'s Gradle property; `play-services-mlkit-text-recognition`)

### M20 — iCloud sync
**XL · Pro · B1, D7**

Free personal teams can't provision iCloud. Plan this one in detail before starting. Outline: the CloudKit private database (the user's own iCloud quota, no account), one record type per table, `updated_at` and `deleted` on every table, last-write-wins per row, a Swift layer behind a platform channel. The sync action goes behind `ProGate`; records already synced stay without Pro. Set `ProFeature.iCloudSync.available` when it ships. On Android, hide the feature rather than rename it.

---

## Other Open Questions

Not blocking any item yet:

- **Meal slot times.** The 10:30 / 15:00 / 20:00 cutoffs are fixed. Make them adjustable in Settings if anyone asks.
- **Pro across platforms.** A purchase on iOS doesn't unlock Android, because there are no accounts. Proposed: keep them separate and say so on the paywall.
- **Is Pro enough to sell?** Watch the purchase rate and tips after launch. If revenue is too low, add new extras to Pro; never take anything away from free.
- **App Store release.** Not planned anywhere yet: listing, screenshots, privacy label, review. It needs B1.
