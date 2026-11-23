#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
SDKROOT="$SDK" swift build -c release

APP="dist/Emmaus.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Emmaus "$APP/Contents/MacOS/Emmaus"
cp Resources/bible.db "$APP/Contents/Resources/bible.db"
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
