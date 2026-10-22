# Food Log App — Monetization Plan (M21)

How the app makes money once the features in [`FEATURE_PLAN.md`](./FEATURE_PLAN.md) are built. This is the last milestone: Pro is worth paying for only after the features it unlocks exist.

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
| Logging, catalog, meals (v1) | M18 home screen widget | Supabase sync, incl. Android (M20 server path) |
| M16 barcode scan and online lookup | M19 Apple Health | AI logging: photo or text ("two eggs and toast") via an LLM API |
| M17 planned meals | iCloud sync across iPhone, iPad, Mac (M20 CloudKit path) | |
| Summary, every range from a day to a year | Shareable reports: a PDF or CSV of a date range to send a dietitian or doctor (new, not yet in FEATURE_PLAN) | |
| Goals for calories and macros | Alternate app icons and themes | |
| M9 recent and frequent foods | | |
| M10 log again and copy day | | |
| M11 export and import (JSON backup) | | |
| M12 meal sections | | |
| M13 fiber, sugar, sodium | | |
| M14 streaks and reminders | | |
| M15 weigh-ins and the weight trend chart | | |
| Welcome pages and app tour | | |

**Rule of thumb for new features:** if a new user would want it in their first week, it's free. If it's something only some people want, beyond logging and looking at their own data, it can be Pro.

Shareable reports and the JSON backup aren't the same thing. The backup is for the user's own safety and is always free. A report is a formatted summary meant for someone else, so it's an extra.

---

## Sync and Pricing

How M20 is built decides which tier sync lives in:

| Approach | Cost per user to us | Platforms | Tier |
|---|---|---|---|
| CloudKit private database | ~$0 (uses the user's iCloud quota) | Apple only | Pro |
| Supabase | Ongoing (database, auth, bandwidth) | Any, incl. Android and web | Pro+ |

CloudKit has no first-class Flutter package, so it means a small Swift layer behind a platform channel. It avoids running a server and keeps sync in the one-time tier.

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

- [ ] Paid Apple Developer account ($99/yr). Required to sell anything; also unblocks M18 and M19 (FEATURE_PLAN Open Question 4)
- [ ] Join the App Store Small Business Program (15% commission instead of 30%)
- [ ] App Store Connect: Paid Applications agreement, tax and banking forms
- [ ] Privacy policy URL (required for IAP and the App Store listing). Short: data stays on device; list any network calls (Open Food Facts, sync, AI)
- [ ] Create products in App Store Connect, with Family Sharing turned on for the Pro product:

| Product ID | Type | Notes |
|---|---|---|
| `com.nutriton.app.pro` | Non-consumable | The Pro unlock |
| `com.nutriton.app.trial14` | Non-consumable, $0 | Named "14-day Trial", as App Review Guideline 3.1.1 allows for non-subscription apps |
| `com.nutriton.app.tip.small` / `.medium` / `.large` | Consumable | Tip jar |
| `com.nutriton.app.proplus.monthly` / `.yearly` | Auto-renewing subscription | Only when Pro+ ships |

---

## Milestone M21 — Pro unlock

- [ ] Add `purchases_flutter` (RevenueCat). It handles StoreKit and Play Billing, receipt validation and restore; free under $2.5k monthly revenue. Fallback: the official `in_app_purchase` package with on-device StoreKit 2 verification
- [ ] RevenueCat dashboard: one entitlement `pro`, granted by `com.nutriton.app.pro` and (while active) the trial product. Later, an entitlement `pro_plus` for the subscriptions
- [ ] `lib/providers/entitlement_providers.dart`: a `proProvider` (`bool`) fed by RevenueCat's customer-info stream, cached in `shared_preferences` so the app works offline and starts without a network call
- [ ] A `ProGate` widget in `lib/views/common/`: shows its child when Pro, otherwise a lock badge that opens the paywall. Only the five Pro features' entry points use it; repositories and DAOs stay unaware of Pro
- [ ] Trial: when the trial product's purchase date is under 14 days old, `proProvider` is true. After it expires, show one "Your trial ended" notice and fall back to free (Principle 2 applies)
- [ ] `lib/views/paywall/paywall_view.dart`: a Cupertino sheet listing the five Pro features, a line saying everything else stays free, the price from the store (never hard-coded), Start trial, Buy, Restore Purchases, and links to the privacy policy and terms
- [ ] Settings: a "Nutriton Pro" row (status, or opens the paywall), Restore Purchases, and the tip jar
- [ ] Check that the welcome pages and app tour (`lib/views/onboarding/`, `lib/views/tour/`) mention no Pro features (Principle 7)
- [ ] Review prompt: `in_app_review`, asked once after logs on 7 distinct days. The day count is a pure function in `core/`
- [ ] Grandfather early users: anyone whose original install predates M21 (`AppTransaction.originalAppVersion`, exposed by RevenueCat) gets Pro free
- [ ] Sandbox testing: buy, restore on a reinstall, refund (Pro features lock, data remains), offline launch, trial expiry, Family Sharing on a second account. Use a StoreKit configuration file in Xcode for local runs
- [ ] Tests: `proProvider` overridden in widget tests for both states; `ProGate` shows the lock and opens the paywall; every free feature works with `proProvider` false; trial-expiry and review-prompt date logic as pure functions in `core/`

**Done when:** a sandbox account can start the trial, buy Pro, delete and reinstall the app, restore, and have every Pro feature unlocked with no data lost at any step. A free account can use every feature in the Free column without seeing a paywall.

### Later: Pro+

Only start when a feature with a running cost exists (Supabase sync or AI logging). Plan it separately, including usage limits for AI requests, and keep Pro owners' features unchanged.

---

## Decided

- **Most features are free; Pro is five extras.** Barcode scan, planned meals, every Summary range and the weight chart are free (they were Pro in an earlier draft).
- **Family Sharing is on** for the Pro purchase.

## Open Questions

1. **Price.** $9.99 at launch, then $14.99, is still a guess. Comparable apps: MacroFactor ~$72/yr, Cronometer Gold ~$55/yr, MyFitnessPal Premium ~$80/yr. A one-time price can be much lower and still be good value.
2. **Is Pro enough to sell?** With most of the app free, fewer people will buy. Watch the purchase rate and tips after launch. If revenue is too low, add new extras to Pro rather than taking anything away from free (Principle 5).
3. **CloudKit or Supabase (M20).** Decides whether sync is in Pro or Pro+.
4. **Android.** Play Billing works through RevenueCat with the same entitlements, but CloudKit sync doesn't exist there, and Apple Health becomes Health Connect.
