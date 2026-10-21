# Food Log App — Monetization Plan (M21)

How the app makes money once the features in [`FEATURE_PLAN.md`](./FEATURE_PLAN.md) are built. This is the last milestone: Pro is worth paying for only after the features it unlocks exist.

> Related docs: [`GAME_PLAN.md`](./GAME_PLAN.md) · [`DATA_MODEL.md`](./DATA_MODEL.md) · [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) · [`FEATURE_PLAN.md`](./FEATURE_PLAN.md)

---

## Model at a Glance

| Tier | Price (proposed) | Type | What it covers |
|---|---|---|---|
| Free | $0 | — | Everything needed to log food and keep your data |
| Pro | $14.99 once | Non-consumable IAP | Convenience and polish features, plus CloudKit sync if built |
| Pro+ (later, optional) | ~$2.99/mo or $19.99/yr | Auto-renewing subscription | Only features with a running cost to us (server sync, AI logging) |
| Tip jar | $1.99 / $4.99 / $9.99 | Consumable IAP | Unlocks nothing; a thank-you |

**Why this shape:**
- **The app is local-first and has no servers.** A one-time unlock matches what it costs to run: nothing per user. A subscription is only fair when a feature costs money every month.
- **Privacy is the selling point.** No account, no tracking, no ads. Most food loggers can't say that.
- **Free stays genuinely useful.** A free version people like brings reviews and word of mouth, and that is what sells Pro.

---

## Principles

1. **Never charge for safety of data.** Export and import (M11) stay free. A free user must never lose history because they didn't pay.
2. **Never lock data already created.** If a Pro feature is lost (refund, lapsed Pro+), the data it made stays visible and editable. Foods added by barcode stay in the catalog; past weigh-ins stay in the chart. Only the *action* (scan, sync, AI) is gated.
3. **Gate convenience, not logging.** Logging, the catalog, meals, goals and the basic summary are free forever.
4. **One paywall screen, asked for, not pushed.** The paywall appears when a user taps a Pro feature, and from Settings. No pop-ups on launch, no nag counters.

---

## Free vs Pro

| Free forever | Pro (one-time) | Pro+ (subscription, only if built) |
|---|---|---|
| Logging, catalog, meals (v1) | M16 barcode scan and online lookup | Supabase sync, incl. Android (M20 server path) |
| Summary up to 30 days | Summary ranges past 30 days, M15 weight trend chart | AI logging: photo or text ("two eggs and toast") via an LLM API |
| Goals for calories and macros | M13 fiber, sugar, sodium | |
| M9 recent and frequent foods | M17 planned meals | |
| M10 log again and copy day | M18 home screen widget | |
| M11 export and import | M19 Apple Health | |
| M12 meal sections | CloudKit sync across iPhone, iPad, Mac (M20 Apple-only path) | |
| M14 streaks and reminders | Alternate app icons and themes | |
| M15 weigh-ins (entry only) | | |

The split is a starting point; revisit it with real usage (see Open Questions).

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
- [ ] Create products in App Store Connect:

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
- [ ] A `ProGate` widget in `lib/views/common/`: shows its child when Pro, otherwise a lock badge that opens the paywall. Each Pro feature's entry point uses it; repositories and DAOs stay unaware of Pro
- [ ] Trial: when the trial product's purchase date is under 14 days old, `proProvider` is true. After it expires, show one "Your trial ended" notice and fall back to free (Principle 2 applies)
- [ ] `lib/views/paywall/paywall_view.dart`: a Cupertino sheet listing Pro features, the price from the store (never hard-coded), Start trial, Buy, Restore Purchases, and links to the privacy policy and terms
- [ ] Settings: a "Nutriton Pro" row (status, or opens the paywall), Restore Purchases, and the tip jar
- [ ] Grandfather early users: anyone whose original install predates M21 (`AppTransaction.originalAppVersion`, exposed by RevenueCat) gets Pro free
- [ ] Sandbox testing: buy, restore on a reinstall, refund (Pro features lock, data remains), offline launch, trial expiry. Use a StoreKit configuration file in Xcode for local runs
- [ ] Tests: `proProvider` overridden in widget tests for both states; `ProGate` shows the lock and opens the paywall; trial-expiry date logic as a pure function in `core/`

**Done when:** a sandbox account can start the trial, buy Pro, delete and reinstall the app, restore, and have every Pro feature unlocked with no data lost at any step.

### Later: Pro+

Only start when a feature with a running cost exists (Supabase sync or AI logging). Plan it separately, including usage limits for AI requests, and keep Pro owners' features unchanged.

---

## Open Questions

1. **Price.** $14.99 once is a guess. Comparable apps: MacroFactor ~$72/yr, Cronometer Gold ~$55/yr, MyFitnessPal Premium ~$80/yr. A one-time price can be lower and still be good value; consider launch pricing.
2. **The 30-day Summary limit.** Is gating long ranges fair, or does it feel like holding history hostage? Alternative: keep all ranges free and gate only the weight trend chart.
3. **CloudKit or Supabase (M20).** Decides whether sync is in Pro or Pro+.
4. **Android.** Play Billing works through RevenueCat with the same entitlements, but CloudKit sync doesn't exist there.
5. **Family Sharing.** Allow it on the Pro non-consumable? It's a checkbox in App Store Connect and generous at little cost.
