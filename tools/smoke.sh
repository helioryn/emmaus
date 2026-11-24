#!/bin/bash
# Run the search smoke checks without XCTest (Command Line Tools only).
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

swiftc -O -parse-as-library \
  Sources/Emmaus/Database.swift \
  Sources/Emmaus/Models.swift \
  Sources/Emmaus/Plans.swift \
  Sources/Emmaus/SearchQuery.swift \
  Sources/Emmaus/BibleStore.swift \
  tools/smoke.swift \
  -lsqlite3 \
  -o "$OUT/emmaus-smoke"

"$OUT/emmaus-smoke"
