#!/usr/bin/env bash
# Copy the generated Bible library into the Android app, where it is bundled
# into the APK. Run this after building or refreshing Resources/bible.db.
#
#   ./sync_assets.sh            # copy (fails if the database is missing)
#   ./sync_assets.sh --fetch    # build the database first, if it is missing
#   ./sync_assets.sh --check    # report status, change nothing
set -euo pipefail
cd "$(dirname "$0")"

DB="Resources/bible.db"
DEST="android/app/src/main/assets/bible.db"
MODE="${1:-}"

have_db() { [ -s "$DB" ] && return 0 || return 1; }

if ! have_db; then
  case "$MODE" in
    --check)
      echo "missing: $DB (run ./sync_assets.sh --fetch)"
      exit 1
      ;;
    --fetch)
      echo "==> $DB not found; building it from upstream sources"
      echo "    this downloads roughly 1 GB and takes a few minutes"
      bash tools_download.sh
      python3 tools/import_bible.py
      python3 tools/import_free_bibles.py
      have_db || { echo "error: import finished but $DB is still missing" >&2; exit 1; }
      ;;
    *)
      cat >&2 <<'MSG'
error: Resources/bible.db is missing.

The Bible library is generated, not committed. Either:

  ./sync_assets.sh --fetch     # download sources and build it (~1 GB)
  cp /path/to/bible.db Resources/bible.db

MSG
      exit 1
      ;;
  esac
fi

DB_BYTES=$(wc -c < "$DB" | tr -d ' ')
DEST_BYTES=0
[ -f "$DEST" ] && DEST_BYTES=$(wc -c < "$DEST" | tr -d ' ')

if [ "$MODE" = "--check" ]; then
  printf 'source  %s  %s bytes\n' "$DB" "$DB_BYTES"
  if [ "$DB_BYTES" = "$DEST_BYTES" ]; then
    printf 'target  %s  up to date\n' "$DEST"
  else
    printf 'target  %s  %s bytes (out of date)\n' "$DEST" "$DEST_BYTES"
    exit 1
  fi
  exit 0
fi

if [ "$DB_BYTES" = "$DEST_BYTES" ]; then
  echo "assets already up to date ($((DB_BYTES / 1048576)) MB)"
  exit 0
fi

mkdir -p "$(dirname "$DEST")"
echo "==> copying $DB -> $DEST"
cp "$DB" "$DEST"

echo "==> verifying"
python3 - "$DEST" <<'PY'
import sqlite3, sys
path = sys.argv[1]
con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
check = con.execute("pragma quick_check").fetchone()[0]
verses = con.execute("select count(*) from verses").fetchone()[0]
trs = con.execute("select count(*) from translations where source='local'").fetchone()[0]
size = con.execute("pragma page_count").fetchone()[0] * con.execute("pragma page_size").fetchone()[0]
con.close()
if check != "ok":
    sys.exit(f"error: quick_check failed: {check}")
if size != __import__("os").path.getsize(path):
    sys.exit("error: database is truncated")
print(f"    ok: {trs} translations, {verses:,} verses, {size / 1048576:.0f} MB")
PY

echo
echo "Next:"
echo "  cd android && ./gradlew :app:assembleDebug"
echo "  adb install -r app/build/outputs/apk/debug/app-debug.apk"
