# Emmaus for Android — test build

A standalone APK you can sideload on a phone. Everything below is offline except the
three licensed translations, which use your own API.Bible key.

## The file

```
dist/Emmaus-android-test.apk      ~147 MB, release build, signed with a local test key
```

- Package: `com.btaylor.emmaus`, version 1.0.1 (versionCode 2)
- Minimum Android: 8.0 (API 26)
- First launch unpacks a 454 MB Bible library into app storage, so it shows a
  “Preparing the library…” screen for up to a minute. Later launches open instantly.
- Storage used on the phone: about 600 MB (APK + unpacked library).

## Install on a phone

1. Copy `Emmaus-android-test.apk` to the phone (USB, Google Drive, `adb push`, whatever).
2. Open it. Android will ask to allow installs from that app — allow it once.
3. Launch **Emmaus**.

With a cable instead:

```bash
adb install -r dist/Emmaus-android-test.apk
```

If Android refuses the file — "there was a problem parsing the package", "app not
installed", or "package conflicts with an existing package" — it is almost always one
of three things:

1. **A copy signed with a different key is already installed.** Uninstall it once:
   `adb uninstall com.btaylor.emmaus`, or Settings → Apps → Emmaus → Uninstall.
   Debug and release builds now share the test key, so this only bites against
   builds made before 1.0.1 or by another machine.
2. **The transfer truncated the file.** It is ~147 MB; some cloud apps stream it and
   save a partial copy. Verify before installing:

   ```bash
   shasum -a 256 Emmaus-android-test.apk
   ```

   Compare with `shasum -a 256 dist/Emmaus-android-test.apk` on the machine that built
   it. If they differ, copy again over USB or with `adb push`.
3. **The phone is older than Android 8.0.** The manifest requires API 26; older
   installers report it as an unreadable package.

## What is inside

41 offline Bibles, 1.19 M verses:

- **English (13):** KJV (Strong’s + red letters), BSB, WEB, ASV, YLT, BBE, Darby,
  Douay-Rheims, Geneva 1599, Majority Standard, Revised Version 1885, Webster,
  World Messianic.
- **Original languages (6):** Hebrew WLC, Greek New Testament, Textus Receptus,
  Byzantine Textform, Clementine Vulgate, Arabic Van Dyck.
- **Other languages (22):** Chinese Union Version (simplified and traditional),
  Reina Valera 1909, Louis Segond 1910, Luther 1912, World Portuguese, Riveduta 1927,
  Russian Synodal, Dutch 1917, Korean 1910, Japanese Freedom Bible, Vietnamese 1923,
  Thai Freedom Bible, Ukrainian Kulish, Romanian 1924, Czech Kralická, Serbian 1868,
  Burmese, Esperanto, Hawaiian 1868, Haitian Creole, Old Persian Version.

All public domain, courtesy of eBible.org. Full-text search works in every one of them.

## Licensed translations (NIV, NASB, NKJV)

Nothing copyrighted is bundled. To read them:

1. Get a free key at <https://api.bible/sign-up>.
2. In your api.bible dashboard, open the app’s **Plan** tab and add NIV, NASB and NKJV
   to the Bible list.
3. In Emmaus: **Settings → Online Bibles**, paste the key, tap **Save & test**.
4. Pick NIV/NASB/NKJV from the translation menu — they are marked “online”.

The free Starter plan allows 5,000 calls a month and three copyrighted translations.
Chapters are cached on the device for 30 days, matching the publisher terms, and the
required copyright notice is shown under each chapter.

## Rebuilding

```bash
cd android
./gradlew :app:assembleRelease
cp app/build/outputs/apk/release/app-release.apk ../dist/Emmaus-android-test.apk
```

Gradle signs the release APK itself. When `android/emmaus-testing.jks` is present it
uses that key for both debug and release, so `adb install -r` upgrades cleanly. Get a
keystore elsewhere (CI) and the release comes out unsigned; debug falls back to
Gradle's own debug key. Override the key material without editing the build file:

```bash
./gradlew :app:assembleRelease \
  -PEMMAUS_KEYSTORE_PASSWORD=... -PEMMAUS_KEY_ALIAS=... -PEMMAUS_KEY_PASSWORD=...
```

The database comes from `../Resources/bible.db`. One command copies it into the app
and verifies it:

```bash
./sync_assets.sh            # add --fetch to build the database if it is missing
```

Regenerate the translations themselves with:

```bash
python3 tools/import_free_bibles.py     # adds the eBible.org translations, idempotent
```

Signing uses a local keystore that is deliberately **not** in this repository
(`android/*.jks` is ignored). For your own builds, create one:

```bash
keytool -genkeypair -keystore android/emmaus-testing.jks -alias emmaus \
  -keyalg RSA -keysize 2048 -validity 10000
```

Use the same key for every build you install, or Android will refuse to update over
the previous one. Play distribution uses Play App Signing, not this key.

## Known limits in this build

- Only the 11 originally bundled Bibles are in the FTS index; the eBible additions use a
  LIKE fallback. Fast enough for one translation at a time.
- The macOS app reads the same `Resources/bible.db`, so rebuilding it now produces a
  larger bundle (~460 MB) with the same 41 translations. It searches all of them: FTS
  for the eight indexed translations, a literal scan for the rest, and normalised
  matching for pointed Hebrew, Greek and Arabic.
