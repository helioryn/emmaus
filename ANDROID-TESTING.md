# Emmaus for Android — test build

A standalone APK you can sideload on a phone. Everything below is offline except the
three licensed translations, which use your own API.Bible key.

## The file

```
dist/Emmaus-android-test.apk      ~140 MB, release build, signed with a local test key
```

- Package: `com.btaylor.emmaus`
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
adb uninstall com.btaylor.emmaus      # only needed if a differently-signed build is installed
adb install -r dist/Emmaus-android-test.apk
```

The test key is different from the debug key Gradle uses, so if you already have a
debug build installed you must uninstall it first.

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
# then align + sign:
BT=/opt/homebrew/share/android-commandlinetools/build-tools/36.0.0
$BT/zipalign -f -p 4 app/build/outputs/apk/release/app-release-unsigned.apk /tmp/emmaus-aligned.apk
$BT/apksigner sign --ks emmaus-testing.jks --ks-key-alias emmaus \
  --ks-pass pass:emmaus-testing --key-pass pass:emmaus-testing \
  --out ../dist/Emmaus-android-test.apk /tmp/emmaus-aligned.apk
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
keytool -genkeypair -keystore android/my-release.jks -alias emmaus \
  -keyalg RSA -keysize 2048 -validity 10000
```

Use the same key for every build you install, or Android will refuse to update over
the previous one. Play distribution uses Play App Signing, not this key.

## Known limits in this build

- Only the 11 originally bundled Bibles are in the FTS index; the eBible additions use a
  LIKE fallback. Fast enough for one translation at a time.
- The macOS app reads the same `Resources/bible.db`, so rebuilding it now produces a
  larger bundle (~440 MB) with the same 41 translations. Its search is FTS-only, so the
  new translations are readable but not searchable there until the index is rebuilt.
