# Contributing to Emmaus

Thank you for wanting to help. Emmaus is a free study Bible, maintained by one
person, and every useful contribution — a bug report with a reproduction, a
translation whose license checks out, a VoiceOver label, a typo fix — makes it
better for people who will never file an issue themselves.

This document is deliberately specific. A Bible app has failure modes that other
apps don't: copyright, doctrine, and data provenance. The rules below exist to
keep the project out of trouble, not to keep people out.

## The covenant (non-negotiable)

Emmaus is free software and a free app. Pull requests that do any of the following
will be closed without discussion:

- Add advertising, sponsorships, or affiliate links
- Add analytics, telemetry, crash reporting, or "anonymous usage statistics"
- Add a paywall, subscription, license check, or account requirement
- Add anything that sends reading activity, notes, or search queries off-device
- Bundle or redistribute a copyrighted Bible translation without a license

If you want to build a commercial product, the GPL lets you fork the code — but it
is not Emmaus, and it may not use the name or icon. See [Trademark](#trademark).

## Ways to contribute

| You have | Do this |
|---|---|
| A bug | Open a [bug report](../../issues/new?template=bug_report.yml) with steps, platform, and version |
| A translation to add | Read [Adding a Bible](#adding-a-bible) and open a translation request first |
| A feature idea | Open a [feature request](../../issues/new?template=feature_request.yml) before writing code |
| Code | Comment on an issue, then open a focused pull request |
| A security issue | **Do not open an issue.** Follow [SECURITY.md](SECURITY.md) |
| Time to triage | Reproduce other people's reports and say what you found |

**Open an issue before a large pull request.** It saves you from building
something that gets declined, and it lets the design get reviewed while it is
still cheap to change. Small fixes (typos, obvious bugs, docs) can go straight to
a PR.

## Development setup

The Bible library is not committed — it is 454 MB of public-domain text generated
from upstream sources. Build it once:

```bash
bash tools_download.sh          # ~1 GB of source texts
python3 tools/import_bible.py   # core library -> Resources/bible.db
python3 tools/import_free_bibles.py   # +30 public-domain translations
```

### macOS

```bash
bash build_app.sh
open dist/Emmaus.app
```

Swift 5.9+, macOS 14+. The build uses `swift build` against the locally installed
SDK; if your Xcode/Command Line Tools version differs from `SDK` in
`build_app.sh`, point it at yours.

### Android

```bash
cp Resources/bible.db android/app/src/main/assets/bible.db
cd android
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Kotlin 2.x, AGP 8.13, `compileSdk 36`, `minSdk 26`. See
[ANDROID-TESTING.md](ANDROID-TESTING.md) for release signing.

## Code standards

- **Match the file you are editing.** The Mac app is SwiftUI with observable
  state in `AppState`; the Android app is Compose with `AppViewModel`. Don't
  introduce a third pattern.
- **Keep state and view separate.** UI code renders; it does not query the
  database. Queries belong in `BibleStore`/`Database` (macOS) or `BibleDb`
  (Android).
- **Never block the main thread on SQLite.** Chapter loads, searches, and imports
  are background work.
- **No new dependencies** without discussing it first. Every dependency is a
  supply-chain and licensing decision, and this project ships to two stores.
- **Handle the empty case.** A chapter that is missing from a translation must
  show a clear message, not a blank screen.
- **Match the typography.** Serif for Scripture, system sans for UI, the existing
  theme tokens rather than hard-coded colours.

There is no formatter to argue about. Keep diffs small and readable.

### Tests

The project is thin on tests, which is a known weakness. Tests that would be
genuinely valuable:

- Chapter/navigation state (the class of bug where the header and the text
  disagree — see commit `feb3856`)
- Verse reference parsing (`John 3:16`, `1 Cor 13:4-7`, `Ps 23`)
- Import parsing for USFM, OSIS, and the eBible VPL format
- Search expression building

If you fix a bug, a regression test that fails before your fix is the best
possible pull request.

## Adding a Bible

This is the most valuable contribution and the easiest one to get wrong. A
translation can only be added if its license allows redistribution **and** its
provenance is documented.

Open a **translation request** issue first, with:

1. **Name, abbreviation, language, year.**
2. **Source URL** you downloaded from (not a random mirror).
3. **License** — the exact statement, from the publisher or host, and a link to
   it. "It's on a website" is not a license.
4. **Attribution string** that must be displayed, verbatim.
5. **Converter script** in `tools/` (USFM, OSIS, VPL, JSON — whatever the source
   uses), with the source URL as a constant in the script.
6. **Spot checks** — Genesis 1:1, Psalm 23:1, John 3:16, and Romans 8:28 from the
   new translation, plus verse counts per book, so the importer can be checked
   for off-by-one book mapping.

### What is acceptable

- Public domain (pre-1929 publications in the US, and many older works worldwide)
- CC0 / public-domain dedication
- CC BY (attribution required, and must be displayed in the app)
- CC BY-SA (attribution + share-alike; the app already displays these notices)
- CC BY-ND (verbatim bundling only — no modification of the text)

### What is not acceptable

- Anything requiring a license fee, a per-user royalty, or a contract
- Texts whose license is unclear or unstated
- Scraped text from Bible Gateway, YouVersion, or a publisher's site
- "Found on GitHub" without the upstream license
- Modern copyrighted translations (NIV, NASB, NKJV, ESV, NLT, CSB, …) — these
  stay behind the user's own API.Bible key and are never bundled

`DATA-LICENSES.md` must be updated in the same pull request.

## Doctrine

Emmaus ships historical commentary — Matthew Henry, Jamieson-Fausset-Brown,
Geneva, Scofield, Tyndale Open Study Notes — because those works are public
domain or openly licensed. Their presence is not an endorsement of every note.
They disagree with each other, and with the maintainer, and that is fine.

Therefore:

- **No new doctrinal notes, devotionals, or study material will be merged.**
- **No translation is preferred, ranked, or recommended over another.**
- **No denominational advocacy**, in code, copy, comments, or UI.
- **No "correcting" Scripture.** If a translation has a typo, fix it against that
  translation's own source; do not substitute wording from another.
- Debates about baptism, predestination, women's ordination, the age of the
  earth, or the canon are out of scope here. Take them somewhere built for it.

A bug about *data* (a mis-mapped book, a dropped verse, broken RTL) is always in
scope. A bug about *meaning* is not.

## Pull requests

1. Fork, branch from `main`, keep the branch focused (`fix/romans-navigation`,
   `feat/vpl-importer`).
2. Rebase rather than merge `main` into your branch.
3. Write a commit message that explains **why**, not just what. Include the
   reproduction for bug fixes.
4. Sign off your commits — we use the
   [Developer Certificate of Origin](https://developercertificate.org/):

   ```bash
   git commit -s -m "Fix chapter reload when the book changes"
   ```

   The sign-off certifies you wrote the code or have the right to submit it.
5. Fill in the pull request template, including how you tested it and which
   platforms you touched.
6. Expect review comments about scope and state handling. They are about the
   code.

By contributing, you agree your contribution is licensed under
[GPL-3.0](LICENSE), the same license as the project.

## What gets rejected

- Translating the UI into another language without a plan for the ~40 translation
  names and the RTL layout (it is welcome — just plan it)
- Bundling the database, screenshots of other apps, or any binary over 1 MB
  without prior discussion
- "Cleanup" pull requests that reformat whole files
- New dependencies for things the standard library already does
- Anything that breaks offline use, even when online features exist

## Trademark

The GPL covers the code. It does not cover the name **Emmaus** or the app icon.
Forks are welcome and encouraged; rename them. Nobody should install a fork
believing it is this project and finding ads or a paywall inside.

## Questions

Open a discussion or an issue with the `question` label. If you are unsure
whether your idea fits, ask before you build it — that is a feature of a
single-maintainer project, not a bug.
