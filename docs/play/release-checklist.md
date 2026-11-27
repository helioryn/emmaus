# Play release checklist

The code side is done; what remains is Play Console work that needs the account.

## 1. Build the upload

```bash
cd android
./gradlew :app:bundleRelease
# android/app/build/outputs/bundle/release/app-release.aab
```

The bundle is signed with `android/emmaus-testing.jks` when that file is present.
For Play, use a real upload key and enroll in **Play App Signing**; the upload key
only proves the bundle came from you.

Version comes from `android/app/build.gradle.kts` (`versionCode` must increase on
every upload; it is currently 3 / 1.1.0).

## 2. Create the app

Console → Create app:

- Name: `Emmaus — Offline Study Bible`
- Default language: English (United States)
- App or game: App, Free
- Declarations: no ads, no in-app purchases

Then fill:

- **Store listing** — copy from `docs/play/listing.md`. Needs a 512×512 icon, a
  1024×500 feature graphic, and at least two phone screenshots (the repo's
  `docs/screenshots/android-*.jpg` work).
- **App content** — privacy policy URL (host `docs/play/privacy-policy.md`),
  data safety from `docs/play/data-safety.md`, content rating questionnaire,
  target audience, ads declaration.
- **Release → Production → Countries** can stay untouched until closed testing
  passes.

## 3. Closed testing (the calendar gate)

Personal developer accounts created after 13 Nov 2023 must run a closed test with
**at least 12 testers opted in for 14 continuous days** before production access.

- Create a closed track, upload the AAB, add testers by email list or Google Group.
- Testers install from the Play link, not from an APK. Ask them to keep it
  installed for the full two weeks.
- Start this before the feature work is finished; the 14 days run in parallel.

## 4. Production

After the closed test requirement is met:

- Promote the tested build (or upload a new one with a higher `versionCode`).
- Roll out to a small percentage first; watch Android vitals for crashes/ANRs.
- Keep the APK on GitHub Releases for people without Play.

## Known limits to disclose honestly

- The first launch unpacks ~475 MB and needs about 600 MB free.
- Licensed translations require the user's own API.Bible key.
- iOS is not available; macOS builds from source.
