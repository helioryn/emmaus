# Emmaus — Startup Cost Plan (macOS + Android)

> Working notes on launch costs. Saved 2026-11-23.
> Archive that this is not a product/business model yet — it's a cost breakdown of getting to first release.

## Project state (as assessed)

- **macOS:** native SwiftUI app. Ad-hoc signed, no paid developer account, no notarization.
  - `dist/Emmaus.app` = 285 MB, contains `Resources/bible.db` (291 MB).
  - Built via `build_app.sh` (SwiftPM, `MacOSX26.5.sdk`, ad-hoc sign).
  - Only platform calling API.Bible (NIV / NASB / NKJV), key written into
    `~/Library/Application Support/Emmaus/config.json` (0600) at build time.
- **Android:** Kotlin/Compose, `com.btaylor.emmaus`, minSdk 26, targetSdk 36.
  - Fully offline. **`bible.db` is not bundled yet** — debug APK is 17 MB.
  - No API.Bible integration.
- Data footprint: `data/` 353 MB, `Resources/` 289 MB, DB 291 MB.

## Unavoidable platform fees

| Item | Cost | Why |
|---|---|---|
| Apple Developer Program | **$99 / year** | Only route to Developer ID + notarization (avoids "unidentified developer"), Mac App Store, TestFlight. |
| Google Play Console | **$25 one-time** | No renewal. Personal accounts created after 2023-11-13 need **12 testers opted in for 14 continuous days** before production access. |
| Domain + hosting | **~$12–20 / year** | Cloudflare Pages / Vercel free tier; GitHub Releases hosts a 285 MB DMG free (2 GB/file limit). |
| **Year 1** | **≈ $140** | **≈ $115 / year thereafter.** |

Everything else at this stage is $0: notarization, Play Asset Delivery, Apple/Android
on-device TTS, local-only storage.

## API.Bible — the real cost driver

Current published terms (checked 2026-11):

| Plan | Cost | Notes |
|---|---|---|
| Starter | **$0** | Non-commercial only. Up to **3** copyrighted Bibles + all open-access. **5,000 calls/month**, hard stop, no overage. |
| Pro | **$29 / month** | Commercial use allowed. 150,000 calls/month. Per-translation licensing added on top, priced by monthly user tier. |
| Overage | $0.50–1.00 per 1,000 calls | Sources disagree ($1/1,000 in the docs, $0.50/1,000 in the FAQ); billed in 1,000-call increments. |

Translation licensing examples:

- **Lockman bundle** (NASB, NASB20, AMP): **$25/mo at 0–1K monthly users** (50% off the
  $50 à-la-carte price).
- **NIV cannot be licensed commercially through API.Bible at all.** Biblica controls it;
  commercial use requires a direct agreement (terms unknown — typically advance and/or
  revenue share).
- NKJV / other Thomas Nelson titles: per-translation monthly fee, tiered by users.

So a paid app shipping the same three translations ≈ **$55–100/month = $660–1,200/year**,
and loses the NIV unless Biblica is negotiated separately.

### Two gotchas

1. **Key sharing.** The API key is baked into `config.json` on every install, so it is
   extractable and all users share one 5,000-call quota — roughly 40–60 users max, and a
   single heavy reader could exhaust it. Options:
   - proxy through a Cloudflare Worker ($0–5/mo),
   - let users supply their own key ("bring your own key"),
   - make online Bibles opt-in and ship only open-access texts by default.
2. **Free → paid flips the license.** Monetizing moves you from Starter to Pro **and**
   triggers per-translation fees. A $4.99 one-time sale nets ~$4.24 after Apple's 15%,
   so ~15–25 sales/month is needed just to cover licensing.

## Optional but realistic

| Item | Cost |
|---|---|
| LLC (varies by state) | $50–500 one-time; $0–150/yr registered agent |
| D-U-N-S number (needed for *organization* Apple/Google accounts) | free, up to 30 days |
| Lawyer review: EULA + privacy policy | $0 (templates) – $1,500 |
| Physical Android test device | $150–400 (emulator works, but Play requires a verified device) |
| Accounting / tax prep | $0–500 |

An LLC also sidesteps Google's 12-tester gate (org accounts aren't subject to it) and
keeps a personal name off the store listing.

## Three realistic budgets

| Scenario | Year 1 | Recurring |
|---|---|---|
| **A. Free, personal accounts, direct DMG + Play** | **~$140** | ~$115/yr |
| **B. Free but professional (LLC, legal, test device)** | ~$800–1,100 | ~$115 + $100–300/yr |
| **C. Paid app with NIV/NASB/NKJV** | ~$1,200–2,500 | $700–1,300/yr API + legal |

## Store commissions (not startup cost, but unit economics)

- **Apple:** 30%; **15%** under the App Store Small Business Program (<$1M/yr).
  Subscriptions 15%.
- **Google:** 15% on the first $1M/yr, then 30%.
- **Direct sales:** Stripe ~2.9% + $0.30; Paddle ~5% + $0.50 (merchant of record —
  handles EU VAT for you, which matters if selling to Europe).

## Technical work that costs $0 but needs doing

- **Android DB delivery.** 291 MB can't go in a normal APK. Google limits: base module
  500 MB, individual asset pack 1.5 GB, 4 GB cumulative install-time. An install-time
  Play Asset Delivery pack works — free, but real work. Pruning/compressing the SQLite
  file is worth it regardless (text compresses well; likely 80–120 MB), and Android warns
  users about data usage above 200 MB.
- **Mac App Store path (if chosen).** Requires App Sandbox plus the
  `com.apple.security.network.client` entitlement for API calls.
- **KJV note.** Public domain in the US, but still under Crown copyright / letters patent
  in the UK. Fine in practice; just not a rights problem to be surprised by later.

## Timeline gates (not money, but time)

- Google personal account: 14-day closed test with 12 continuous testers, then a production
  access application (review ~7 days or less).
- Apple review: typically 1–3 days for a first submission.

## Open decision

**Free or paid?** That fork sets the budget:

- **Free:** ~$140 up front, ~$115/year. Keep API.Bible on Starter, or drop the online
  Bibles to $0 forever and ship only open-access texts.
- **Paid:** platform fees are noise; translation licensing is the real business cost, and
  **NIV is the hard blocker**.
