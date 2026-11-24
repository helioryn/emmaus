#!/bin/bash
# Build Emmaus.app.
#
#   bash build_app.sh            # full build, bundles Resources/bible.db
#   bash build_app.sh --no-db    # build without the library (CI, UI work)
#   EMMAUS_SDK=/path/to/SDK.sdk bash build_app.sh   # force an SDK
set -euo pipefail
cd "$(dirname "$0")"

NO_DB=0
for arg in "$@"; do
  case "$arg" in
    --no-db) NO_DB=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Pick an SDK that can actually expand SwiftUI's macros. On a CLT-only machine
# the newest installed SDK can ship a SwiftUI whose macros the installed
# toolchain cannot load ("plugin for module 'SwiftUIMacros' not found"), so probe
# each candidate with a tiny typecheck instead of guessing.
usable_sdk() {
  local sdk="$1" dir probe
  dir="$(mktemp -d)"
  probe="$dir/probe.swift"
  printf 'import SwiftUI\nstruct P: View { @State var x = 0\n var body: some View { Text("\\(x)") } }\n' > "$probe"
  if swiftc -typecheck -sdk "$sdk" "$probe" >/dev/null 2>&1; then rm -rf "$dir"; return 0; fi
  rm -rf "$dir"
  return 1
}

SDK="${EMMAUS_SDK:-}"
if [ -n "$SDK" ]; then
  [ -d "$SDK" ] || { echo "EMMAUS_SDK not found: $SDK" >&2; exit 1; }
  echo "Using SDK (forced): $SDK"
else
  candidates=()
  if [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]; then
    while IFS= read -r s; do candidates+=("$s"); done < <(
      ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null \
        | grep -v '/MacOSX\.sdk$' | sort -Vr
    )
  fi
  candidates+=("$(xcrun --sdk macosx --show-sdk-path)")

  for s in "${candidates[@]}"; do
    if usable_sdk "$s"; then SDK="$s"; break; fi
    echo "Skipping SDK (SwiftUI macros unavailable): $s"
  done
  [ -n "${SDK:-}" ] || { echo "No usable macOS SDK found. Set EMMAUS_SDK." >&2; exit 1; }
  echo "Using SDK: $SDK"
fi
SDKROOT="$SDK" swift build -c release

APP="dist/Emmaus.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
rm -f "$APP/Contents/Resources/bible.db"
cp .build/release/Emmaus "$APP/Contents/MacOS/Emmaus"
if [ "$NO_DB" = "1" ]; then
  echo "Skipping bible.db (--no-db). The app will not start without it."
else
  cp Resources/bible.db "$APP/Contents/Resources/bible.db"
fi

if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Emmaus</string>
  <key>CFBundleDisplayName</key><string>Emmaus</string>
  <key>CFBundleIdentifier</key><string>com.btaylor.emmaus</string>
  <key>CFBundleExecutable</key><string>Emmaus</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.reference</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict>
</plist>
PLIST

# Write the personal API configuration without echoing the secret.
python3 - <<'PY'
import re, json, os
from pathlib import Path
env = Path('.env')
support = Path.home() / 'Library' / 'Application Support' / 'Emmaus'
support.mkdir(parents=True, exist_ok=True)
if env.exists():
    s = env.read_text()
    key = re.search(r'API KEY\s*-\s*(\S+)', s)
    endpoint = re.search(r'API ENDPOINT\s*-\s*(\S+)', s)
    if key:
        cfg = {
            "endpoint": endpoint.group(1) if endpoint else "https://rest.api.bible",
            "key": key.group(1),
            "bibles": {
                "NIV": "78a9f6124f344018-01",
                "NASB": "a761ca71e0b3ddcf-01",
                "NKJV": "63097d2a0a2f7db3-01"
            }
        }
        p = support / 'config.json'
        p.write_text(json.dumps(cfg, indent=2))
        os.chmod(p, 0o600)
PY

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
