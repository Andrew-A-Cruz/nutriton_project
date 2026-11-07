# Food Log App — Monetization Plan (M21)

How the app makes money once the features in [`FEATURE_PLAN.md`](./FEATURE_PLAN.md) are built. M21 builds the purchase machinery and gates the Pro features that exist (M18 widget, M19 Apple Health); M20 iCloud sync, M22 shareable reports and M23 themes and icons ship behind the same gate later. The paywall lists only Pro features that are built.

**Status (October 2026):** M21 is built in code and tested. Nothing can be sold until the [prerequisites](#prerequisites) are done; until then builds without a RevenueCat key show "Purchases are not available" on the paywall.

> Related docs: [`GAME_PLAN.md`](./GAME_PLAN.md) · [`DATA_MODEL.md`](./DATA_MODEL.md) · [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) · [`FEATURE_PLAN.md`](./FEATURE_PLAN.md)

---

## Model at a Glance

**Most of the app is free. Pro is a short list of extras.**

| Tier | Price (proposed) | Type | What it covers |
|---|---|---|---|
| Free | $0 | — | Nearly everything: logging, catalog, meals, barcode scan, planned meals, all history and charts, goals, backup |
| Pro | $9.99 at launch, then $14.99, once | Non-consumable IAP | Five extras: home screen widget, Apple Health, iCloud sync, shareable reports, themes and icons |
| Pro+ (later, optional) | ~$2.99/mo or $19.99/yr | Auto-renewing subscription | Only features with a running cost to us (server sync, AI logging) |
| Tip jar | $1.99 / $4.99 / $9.99 | Consumable IAP | Unlocks nothing; a thank-you |

**Why this shape:**
- **The app is local-first and has no servers.** A one-time unlock matches what it costs to run: nothing per user. A subscription is only fair when a feature costs money every month.
- **Privacy is the selling point.** No account, no tracking, no ads. Most food loggers can't say that.
- **A generous free app sells itself.** People who log every day for free leave reviews and tell friends. Pro is for those who want more, plus the tip jar for those who just want to say thanks.

---

## Principles

1. **Never charge for safety of data.** Export and import (M11) stay free. A free user must never lose history because they didn't pay.
2. **Never lock data already created.** If a Pro feature is lost (refund, lapsed Pro+), the data it made stays visible and editable. A shared report stays wherever it was saved; foods synced from another device stay in the catalog. Only the *action* (sync, export a report, AI) is gated.
3. **Everything a user needs to log food and understand their own data is free.** That includes faster ways to log (barcode scan, recent foods, log again, planned meals) and all of their history (every Summary range, the weight chart).
4. **Pro is for extras.** Something belongs in Pro only if the app is complete without it: it connects the app to something else (widget, Health, sync, a report for someone else) or is cosmetic (themes, icons).
5. **Never move a free feature behind Pro.** Once a feature ships free, it stays free for everyone, new users included.
6. **One paywall screen, asked for, not pushed.** The paywall appears when a user taps a Pro feature, and from Settings. No pop-ups on launch, no nag counters.
7. **Onboarding never sells.** The welcome pages and the app tour show only free features and never mention Pro.

---

## Free vs Pro

| Free forever | Pro (one-time) | Pro+ (subscription, only if built) |
|---|---|---|
| Logging, catalog, meals (v1) | M18 home screen widget | Supabase sync, incl. Android (only if ever wanted) |
| M16 barcode scan and online lookup | M19 Apple Health | AI logging: photo or text ("two eggs and toast") via an LLM API |
| M17 planned meals | M20 iCloud sync across iPhone, iPad, Mac (CloudKit) | |
| Summary, every range from a day to a year | M22 shareable reports: a PDF of a date range to send a dietitian or doctor | |
| Goals for calories and macros | M23 alternate app icons and themes | |
| M9 recent and frequent foods | | |
| M10 log again and copy day | | |
| M11 export and import (JSON backup) | | |
| M12 meal sections | | |
| M13 fiber, sugar, sodium | | |
| M14 streaks and reminders | | |
| M15 weigh-ins and the weight trend chart | | |
| Welcome pages and app tour | | |
| Enhancement backlog items marked Free in FEATURE_PLAN (quick add, recipes, favorites, automatic backups, goal options, water and more) | | |

**Rule of thumb for new features:** if a new user would want it in their first week, it's free. If it's something only some people want, beyond logging and looking at their own data, it can be Pro.

Shareable reports and the JSON backup aren't the same thing. The backup is for the user's own safety and is always free. A report is a formatted summary meant for someone else, so it's an extra.

---

## Sync and Pricing

How M20 is built decides which tier sync lives in:

| Approach | Cost per user to us | Platforms | Tier |
|---|---|---|---|
| CloudKit private database | ~$0 (uses the user's iCloud quota) | Apple only | Pro |
| Supabase | Ongoing (database, auth, bandwidth) | Any, incl. Android and web | Pro+ |

CloudKit has no first-class Flutter package, so it means a small Swift layer behind a platform channel. It avoids running a server and keeps sync in the one-time tier. *Decided (October 2026):* M20 uses CloudKit. It needs a paid Apple Developer account, since free teams cannot provision iCloud.

Note that iOS device backups already include the database (it lives in the app's Documents directory), so "backup" alone is not a selling point. *Sync between devices* is.

---

## Growing Without Nagging

Ways to bring in users and revenue that fit the principles:

- **Ask for one App Store review.** Use the system prompt (`in_app_review`, which uses `SKStoreReviewController`) once, after the user has logged food on 7 different days. Never after an error, and never more than once per version. iOS also caps it at 3 times a year.
- **Family Sharing on for Pro.** One purchase covers the household. It's a checkbox in App Store Connect.
- **Launch pricing.** $9.99 for the first few months, then $14.99. Early buyers get a good deal, and the price change is a reason to mention the app again.
- **Tip jar in Settings.** For people who use only the free features and want to support the app.

---

## Ads: Not Planned

Considered and rejected:
- **Low revenue.** Sessions are about 10 seconds, several times a day. Banner revenue per user is cents per month.
- **Slower logging.** Speed is the product.
- **Health data and ad SDKs.** Requires the App Tracking Transparency prompt, worsens the App Store privacy label, and carries regulatory risk (the FTC acted against GoodRx and BetterHelp over health data shared with ad networks).

If revisited, the only acceptable form is opt-in: "watch an ad to unlock Pro for 7 days."

---

## Prerequisites

Do these before writing code:

- [ ] Paid Apple Developer account ($99/yr). Required to sell anything, and for iCloud (M20). (M18 and M19 turned out to provision on the free team.)
- [ ] Join the App Store Small Business Program (15% commission instead of 30%)
- [ ] App Store Connect: Paid Applications agreement, tax and banking forms
- [ ] Privacy policy URL (required for IAP and the App Store listing). Short: data stays on device; list any network calls (Open Food Facts, sync, AI)
- [ ] RevenueCat project with the App Store app, and its public iOS SDK key. Builds read it from `--dart-define=REVENUECAT_IOS_KEY=...`; without it the store is off
- [ ] Set `privacyPolicyUrl` in `lib/core/pro.dart` (the paywall hides the link while it is null). Terms of use use Apple's standard licence agreement
- [ ] Create products in App Store Connect, with Family Sharing turned on for the Pro product:

| Product ID | Type | Notes |
|---|---|---|
| `com.nutriton.app.pro` | Non-consumable | The Pro unlock |
| `com.nutriton.app.trial14` | Non-consumable, $0 | Named "14-day Trial", as App Review Guideline 3.1.1 allows for non-subscription apps |
| `com.nutriton.app.tip.small` / `.medium` / `.large` | Consumable | Tip jar |
| `com.nutriton.app.proplus.monthly` / `.yearly` | Auto-renewing subscription | Only when Pro+ ships |

---

## Milestone M21 — Pro unlock

Built in October 2026. Notes in *italics* are where the build differs from the first plan.

- [x] Add `purchases_flutter` (RevenueCat). It handles StoreKit and Play Billing, receipt validation and restore; free under $2.5k monthly revenue. *`lib/data/store/`: a `StoreService` interface, `RevenueCatStoreService` and a no-op default that `main` replaces, as for Health and the widget. The key comes from a dart-define*
- [ ] RevenueCat dashboard: one entitlement `pro`, granted by `com.nutriton.app.pro` **only**. *Do not attach the trial product: a non-consumable never expires, so RevenueCat would grant Pro forever. The app times the trial itself from the trial's purchase date.* Later, an entitlement `pro_plus` for the subscriptions
- [x] `lib/providers/entitlement_providers.dart`: a `proProvider` (`bool`) fed by RevenueCat's customer-info stream, cached in `shared_preferences` so the app works offline and starts without a network call. *`proStatusProvider` holds what is owned; `proAccessProvider` turns it into free, trial or owned; `proProvider` is the bool*
- [x] A `ProGate` widget in `lib/views/common/`: shows its child when Pro, otherwise a lock badge that opens the paywall. Only the Pro features' entry points use it; repositories and DAOs stay unaware of Pro. *Used on the two Apple Health switches. The widget has no in-app entry point, so without Pro the app publishes a locked snapshot and the widget shows "Pro · Unlock in Nutriton"*
- [x] Trial: when the trial product's purchase date is under 14 days old, `proProvider` is true. After it expires, show one "Your trial ended" notice and fall back to free (Principle 2 applies). *The notice is a card on Home with "See Pro" and "OK", never a pop-up. Expiry is re-checked at each day change and launch*
- [x] `lib/views/paywall/paywall_view.dart`: a Cupertino sheet listing the Pro features, a line saying everything else stays free, the price from the store (never hard-coded), Start trial, Buy, Restore Purchases, and links to the privacy policy and terms. *Lists only `ProFeature.shipped`, so it never sells a feature that is not built. Pushed on the tab's navigator, not the root one, so the root's sync plans keep running underneath*
- [x] Settings: a "Nutriton Pro" row (status, or opens the paywall), Restore Purchases, and the tip jar. *Tip rows appear only when the store returns their prices*
- [x] Check that the welcome pages and app tour (`lib/views/onboarding/`, `lib/views/tour/`) mention no Pro features (Principle 7). *Checked: they don't*
- [x] Review prompt: `in_app_review`, asked once after logs on 7 distinct days. The day count is a pure function in `core/`. *`core/review_prompt.dart`. Asked once ever, right after something is logged for today, never at launch*
- [x] Grandfather early users: anyone whose original install predates M21 (`AppTransaction.originalAppVersion`, exposed by RevenueCat) gets Pro free. *Built but off (`grandfatherBeforeBuild = null` in `core/pro.dart`): the app is not on the App Store yet, so nobody qualifies, and the sandbox reports every tester's original build as "1.0". Set it only if a free version ships before Pro*
- [ ] Sandbox testing: buy, restore on a reinstall, refund (Pro features lock, data remains), offline launch, trial expiry, Family Sharing on a second account. Use a StoreKit configuration file in Xcode for local runs. *`ios/Runner/Nutriton.storekit` holds all five products; pick it under the Runner scheme's Run > Options > StoreKit Configuration. Waits on the prerequisites*
- [x] Tests: `proProvider` overridden in widget tests for both states; `ProGate` shows the lock and opens the paywall; every free feature works with `proProvider` false; trial-expiry and review-prompt date logic as pure functions in `core/`. *`test/core/pro_test.dart`, `test/views/pro_test.dart` (fake store: buy, cancel, failure, trial, tip, restore, offline cache, refund, trial notice, locked widget, Health paused, review prompt). The rest of the suite runs with Pro off, so it covers the free app*

Development builds installed outside the App Store cannot buy anything. `--dart-define=PRO_UNLOCKED=true` unlocks Pro for them; the `install-iphone` skill passes it by default.

**Done when:** a sandbox account can start the trial, buy Pro, delete and reinstall the app, restore, and have every Pro feature unlocked with no data lost at any step. A free account can use every feature in the Free column without seeing a paywall. *The second half is met and tested; the first needs the prerequisites and a sandbox account.*

### Later: Pro+

Only start when a feature with a running cost exists (Supabase sync or AI logging). Plan it separately, including usage limits for AI requests, and keep Pro owners' features unchanged.

---

## Decided

- **Most features are free; Pro is five extras.** Barcode scan, planned meals, every Summary range and the weight chart are free (they were Pro in an earlier draft).
- **Family Sharing is on** for the Pro purchase.
- **Sync is CloudKit, in Pro** (October 2026). Supabase and Pro+ only if Android or web sync is ever wanted.
- **Pro features ship behind the gate one by one.** M21 came before M20, M22 and M23; the paywall lists only what is built.

## Open Questions

1. **Price.** $9.99 at launch, then $14.99, is still a guess. Comparable apps: MacroFactor ~$72/yr, Cronometer Gold ~$55/yr, MyFitnessPal Premium ~$80/yr. A one-time price can be much lower and still be good value.
2. **Is Pro enough to sell?** With most of the app free, fewer people will buy. Watch the purchase rate and tips after launch. If revenue is too low, add new extras to Pro rather than taking anything away from free (Principle 5).
3. ~~**CloudKit or Supabase (M20).**~~ Decided: CloudKit, in Pro.
4. **Android.** Play Billing works through RevenueCat with the same entitlements, but CloudKit sync doesn't exist there, and Apple Health becomes Health Connect.
5. **Is Pro ready to sell with two features?** At launch the paywall lists only the widget and Apple Health. Consider waiting for M22 or M20 before turning on sales, or launching at a lower price.
