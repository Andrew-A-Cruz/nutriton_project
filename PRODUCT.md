# Logbite — Product

What the app is, the rules that decide what goes in it and what it costs, the technical decisions, and what is already built. Open work lives in [`ROADMAP.md`](./ROADMAP.md); the schema is in [`DATA_MODEL.md`](./DATA_MODEL.md).

This file replaces `GAME_PLAN.md`, `IMPLEMENTATION_PLAN.md`, `MONETIZATION_PLAN.md` and the finished parts of `FEATURE_PLAN.md` and `ANDROID_PLAN.md`. Their full text is in git history (before November 2026).

---

## What the App Is

A calorie and macro tracker for iPhone (Android planned), built in Flutter. Local-first: data stays on the device in SQLite, with no account, no tracking and no ads.

**Positioning.** The loudest complaint in the category is paywall creep (MyFitnessPal moved barcode scanning to Premium in 2022; MacroFactor charges about $72 a year mainly for adaptive targets). The privacy-first apps are small and basic. Logbite's angle: the features people pay for elsewhere, free, with no account, and the data stays on the phone.

**Screens.** Three tabs, Today (Home), Catalog and Summary, plus onboarding and Settings.

- **Onboarding** (once): primary metric, secondary metrics, goals, g or oz, body weight unit. Settings reuses the same form.
- **Home:** a date header with ‹ › arrows, the day's totals against goals, a weigh-in row, the log grouped into Breakfast, Lunch, Dinner, Snack and Other, and planned items shown dimmed in their section. The `+` opens Add Food: from the catalog (by servings or weight), a one-off entry, quick add, a new catalog food, a meal (editable before logging), or a barcode scan.
- **Catalog:** foods and meals (including recipes with a cooked weight), search, favorites, archive, schedule.
- **Summary:** Day / Week / Month / 6M / Year, averages over logged days, a bar chart coloured by goal status, the body weight chart, and ‹ › to move the end date.

---

## Principles

1. **Never charge for safety of data.** Export, import and automatic backups stay free. A free user must never lose history because they didn't pay.
2. **Never lock data already created.** If a Pro feature is lost (refund, lapsed Pro+), the data it made stays visible and editable. Only the *action* (sync, export a report, AI) is gated.
3. **Everything a user needs to log food and understand their own data is free.** That includes faster ways to log (barcode scan, recent foods, log again, planned meals) and all of their history (every Summary range, the weight chart).
4. **Pro is for extras.** Something belongs in Pro only if the app is complete without it: it connects the app to something else (widget, Health, sync, a report for someone else) or is cosmetic (themes, icons).
5. **Never move a free feature behind Pro.** Once a feature ships free, it stays free for everyone.
6. **One paywall screen, asked for, not pushed.** It opens when a user taps a Pro feature, and from Settings. No pop-ups on launch, no nag counters.
7. **Onboarding never sells.** The welcome pages and the app tour show only free features.

**Rule of thumb for new features:** if a new user would want it in their first week, it's free. If only some people want it, beyond logging and looking at their own data, it can be Pro.

---

## Free vs Pro

| Tier | Price (proposed) | Type | Covers |
|---|---|---|---|
| Free | $0 | — | Nearly everything: logging, catalog, meals, recipes, barcode scan, planned meals, all history and charts, goals, backup |
| Pro | $9.99 at launch, then $14.99, once | Non-consumable IAP | Home screen widget, Apple Health, iCloud sync, shareable reports, themes and icons |
| Pro+ (only if ever built) | ~$2.99/mo or $19.99/yr | Subscription | Only features with a running cost to us (server sync) |
| Tip jar | $1.99 / $4.99 / $9.99 | Consumable IAP | Unlocks nothing |

**Why:** the app has no servers, so a one-time unlock matches its cost per user (nothing). A subscription is fair only for a feature that costs money every month. Pro features ship behind the gate one by one, and the paywall lists only what is built (`ProFeature.shipped`).

| Free forever | Pro (one-time) |
|---|---|
| Logging, catalog, meals, recipes, quick add, favorites | M18 home screen widget (built) |
| Barcode scan and Open Food Facts lookup | M19 Apple Health (built) |
| Planned meals | M20 iCloud sync (CloudKit) |
| Summary, every range; weight chart | M22 shareable PDF reports (built) |
| Goals for calories and macros | M23 themes and alternate icons |
| Recent and frequent foods, log again, copy day | |
| Backup: export, import, automatic backups | |
| Meal sections; fiber, sugar, sodium | |
| Streaks and reminders; weigh-ins | |
| Every backlog item marked Free in the roadmap | |

The JSON backup and a shareable report are different things: the backup is the user's own safety (free); a report is a formatted summary for someone else (Pro).

### Store products

`lib/core/pro.dart` must match these, App Store Connect and RevenueCat.

| Product ID | Type | Notes |
|---|---|---|
| `com.nutriton.app.pro` | Non-consumable | The Pro unlock. The **only** product that grants the RevenueCat `pro` entitlement |
| `com.nutriton.app.trial14` | Non-consumable, $0 | "14-day Trial" (App Review Guideline 3.1.1). Never attach it to the entitlement: a non-consumable never expires, so RevenueCat would grant Pro forever. The app times the trial from its purchase date |
| `com.nutriton.app.tip.small` / `.medium` / `.large` | Consumable | Tip jar |
| `com.nutriton.app.proplus.monthly` / `.yearly` | Subscription | Only if Pro+ ships |

Family Sharing is on for Pro. Development builds can't buy anything; `--dart-define=PRO_UNLOCKED=true` unlocks Pro for them, and the `install-iphone` skill passes it by default.

### Growing without nagging

- **One review prompt** (`in_app_review`), once ever, after something is logged on the 7th distinct day. Never after an error, never at launch.
- **Launch pricing:** $9.99 for the first few months, then $14.99.
- **Tip jar** in Settings for people who only use the free features.

### Not planned

- **Ads.** Low revenue (sessions are ~10 seconds), slower logging, and health data plus ad SDKs means the tracking prompt, a worse privacy label and regulatory risk (the FTC acted against GoodRx and BetterHelp). The only acceptable form would be opt-in: "watch an ad to unlock Pro for 7 days".
- **AI photo or voice logging.** It needs a cloud model, which breaks "stays on the device", and accuracy is poor (a 2026 study reported Cal AI underestimating meals by ~345 kcal). The on-device nutrition label scan in the roadmap covers the "fill the form for me" need. Revisit only as a clearly labelled opt-in.
- **Micronutrient depth.** Cronometer tracks 80+ nutrients from curated sources; Open Food Facts data for vitamins and minerals is uneven. Fiber, sugar and sodium are enough.

---

## Technical Decisions

- **Flutter, not React Native.** drift gives typed SQL, migrations and reactive `watch()` queries; nothing in the app needs React Native.
- **Cupertino everywhere, including Android.** Revisit only if Android reviews complain; adaptive widgets would touch about 46 files under `lib/views/`.
- **Layers:** views → Riverpod providers (no codegen) → repositories → drift DAOs / `shared_preferences`. DAOs hold SQL only; repositories own business rules and transactions; `lib/core/` is pure Dart with no Flutter or drift imports, so it is tested directly.
- **Log entries snapshot their macros.** Editing a catalog food never changes history. Catalog links on an entry are provenance only.
- **Weights in grams, body weight in kg, dates as `yyyy-MM-dd` text.** Units are for display only.
- **Null nutrient means "not recorded"**, different from 0. Sums treat null as 0 but show coverage ("sodium recorded for 3 of 5 entries").
- **Summary averages over days with at least one entry**, shown as "days logged: n of N".
- **Every native feature sits behind an interface with a no-op default** that `main` replaces: `NotificationScheduler`, `WidgetPublisher`, `HealthService`, `StoreService`. Tests override them with fakes, and an unsupported platform just runs without the feature.
- **Backup is versioned JSON** (`version` 1), readable across schema versions. New nullable columns and tables are optional on read, so the format version stays 1; `BackupCodec` has a step-by-step upgrade pipeline for when it must change. A newer file is refused.
- **Sync, if built, is CloudKit in Pro** (decided October 2026): no server, no running cost, Apple only. Supabase / Pro+ only if Android or web sync is ever wanted.
- **Android Auto Backup stays on**, so the database is in the user's Google backup, as iCloud backup does on iOS. The welcome page says so.

### Conventions

- Run `flutter analyze && flutter test` before each push (CI runs both and fails when committed drift code is stale).
- Schema change: bump `schemaVersion`, run `dart run drift_dev make-migrations` and `dart run build_runner build`, add a migration test, update `DATA_MODEL.md` and its schema history, and make the backup read old files.

---

## What's Built

As of November 2026, schema v11. Known gaps that are worth doing are in the roadmap.

| Milestone | What | Notes and known limits |
|---|---|---|
| v1 (M0–M8) | Onboarding, Home, Catalog, Add Food, meals, Summary, Settings, dark mode and 2x text, app icon, release build on iPhone | |
| Scheduling (v2, extended in M17) | Plan a meal or food for one day or weekly, with slot and servings; shown dimmed on Home, tap to log, swipe to skip. Settings > Planned meals lists every plan to edit or remove, and repeating plans can end on a date (v10) | Recipes can't be scheduled |
| M9 | Recent and frequent foods in Add Food, servings prefilled from last time | |
| M10 | Log again, copy day, Copy yesterday | |
| M11 | JSON backup: share-sheet export, import with a counts preview | |
| M12 | Meal sections (v3) | Fixed cutoffs 10:30 / 15:00 / 20:00 |
| M13 | Fiber, sugar, sodium (v4) | |
| M14 | Streak badge, up to three daily reminders (cancelled once the day has an entry) | Android scheduling is inexact. Not yet checked on an iPhone |
| M15 | Body weight (v5), kg or lb, weight chart with a 7-day average | |
| M16 | Barcode scan (v6), local match first, then Open Food Facts | A real barcode decode is untested on a physical device |
| M17 | Planned foods as well as meals, with slot and servings (v7) | A backup with a food-only plan reads as damaged in a pre-M17 app |
| M18 | iOS home screen widget (Pro) | The Swift is untested on a phone |
| M19 | Apple Health (Pro, iOS): writes nutrition, reads body weight (v8 `source`) | A weight deleted in Health is not removed here. Untested on a phone |
| M21 | Pro unlock in code: RevenueCat, cached status, 14-day trial, paywall, `ProGate`, tip jar, review prompt | Can't sell until the App Store setup is done. Grandfathering is built but off (`grandfatherBeforeBuild = null`) |
| October 2026 review | Stale "today" fix, undo on swipe-delete, edit any entry and move it to another day, backup upgrades, migration tooling, Copy yesterday double-tap, release signing, form overflow at 2x text | |
| November 2026 | Quick add, recipes with cooked weight, favorites, duplicate food (v9), movable Summary end date, bars coloured by goal, automatic weekly backups, VoiceOver labels, comma decimal input, error log, CI, stricter lints, scan from Add Food, brand, word search, log indexes | Comma decimals: input, and display since the locale item below |
| M22 | Shareable PDF report (Pro): the share button on Summary sends the range shown, with averages against goals, days on target, the weight change and daily totals (`core/report.dart`, `data/report/report_pdf.dart`) | No CSV yet (D1). Standard PDF fonts, so text is ASCII only. Untested on a phone |
| Macro split | Share of calories from protein, carbs and fat (4 / 4 / 9 kcal per g) as a stacked bar with a legend: the day on Home, the range's averages on Summary (`core/macro_split.dart`, `MacroSplitBar`) | Shown only to people tracking protein, carbs or fat. Uses the grams, so alcohol calories don't count |
| Macro goals as % | In the goals form, "% of calories" sets protein, carbs and fat as shares of the calorie goal (must add to 100), showing the grams live. The grams are derived and saved as ordinary goals, so they follow the calorie goal | Needs a calorie goal. Backups carry the percentages; older app versions read the grams |
| Copy an entry | Long-press an entry > "Copy to another day": a date picker (tomorrow by default) or a "Copy to tomorrow" shortcut, then an undo banner | |
| Mindful mode | Settings > Display: Today shows foods and goal progress bars with no calorie or macro numbers, the streak badge is hidden, and Summary bars are one colour with no legend | Device-local, not in backups. Summary averages and reports still show numbers |
| Locale decimals | Decimals display with the phone's separator (`12,5 g` in a comma region), read once at launch (`core/number_locale.dart`) | Separator only: no thousands grouping, and dates stay English |
| Search online | Typing in Add Food's catalog search shows "Search Open Food Facts for …"; it opens New Food with that search already run, and Save & Log logs the pick | Add Food only, not the Catalog tab |
| Privacy manifests | `ios/Runner/PrivacyInfo.xcprivacy` (no tracking, no collected data; UserDefaults CA92.1 and 1C8F.1, file timestamps C617.1) and one for the widget (1C8F.1), both in their Xcode targets | Xcode's archive privacy report not yet run |
| Android config | `MainActivity` is a `FlutterFragmentActivity` (for Health Connect); notifications use a white-on-transparent logo icon (`drawable/ic_stat_logbite`, kept from resource shrinking by `raw/keep.xml`) | Icon not yet seen on a physical phone |
| Calendar | Tapping the date on Today opens a month calendar: a dot on each logged day, coloured under / on / over the primary goal (neutral in mindful mode); tap a day to jump there, or Today | Weeks start on Sunday. The title no longer jumps straight to today |
| Top foods | A Summary card for the range: the five foods, meals and one-offs with the most of the primary metric (with their share), and the five logged most often. One grouped query (`SummaryDao.watchSourceTotals`) | Grouped per entry: a food eaten inside a meal counts toward the meal, not the food |
| Goals by weekday | Settings > Goals by weekday: any day can override goals (`goal_<metric>_<mon..sun>`), falling back to the daily goals; in % mode a day's macro grams follow its calorie goal. Today, the calendar and the widget use the day's goal; Summary's goal line is the range's average and days on target use each day's goal | In backups. Adaptive goals would need to respect it |
| Undo | The Undo banner now follows edits (servings, one-off changes, meal slot), moves, copy entry / day / yesterday and backup imports, as well as delete and log again. Edits snapshot the entry (`snapshotEntry` / `revertEntry`); an import keeps the replaced data in memory | Only the last change, for 4 seconds |
| Portions | Named portions per food ("cup = 80 g") in a Portions section of a saved food's form; the log screen offers them as chips beside servings and weight, and converts the count to servings. A looked-up food saves the portion its label names ("2/3 cup (60 g)" → cup = 90 g). New `food_servings` table (v11), in backups | Duplicating a food does not copy its portions. Meals log by weight only |
| Haptics | A light tap when something is logged (food, meal, quick add, plan, log again, copy day) and a firmer one on delete (`views/common/haptics.dart`) | The phone's haptics setting applies. Untested on a phone |
| Privacy policy | Hosted on GitHub Pages from `docs/privacy.md`, linked from the paywall, contact logbite.app@gmail.com | Update it with any new network call or Health type |
| Done key | A Done bar above the iOS number keyboard, app-wide (`KeyboardDoneBar` in `CupertinoApp.builder`) | iOS only; Done, no Next. Untested on a phone |
| Android | Release build runs on an API 36 emulator: onboarding, saving, reminders across reboots, camera opening, Open Food Facts lookup and backup sharing work. `minSdk` 26 and the `INTERNET` permission are set | No physical phone yet. Pro, the widget and Health are off on Android |
