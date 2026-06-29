#!/usr/bin/env bash
# Enforces a line-coverage floor on the pure-logic files only.
#
# SwiftUI view code is intentionally excluded — it is verified by build + UI
# smoke tests, not unit coverage, so a global threshold would be meaningless.
# This gate guards the testable business logic (timer math, streak rules, and
# the persistence/engine stores added in later phases).
#
# Usage: check-coverage.sh <path-to-.xcresult> [min-percent]
set -euo pipefail

XCRESULT="${1:?usage: check-coverage.sh <xcresult> [min-percent]}"
MIN="${2:-80}"

# Files whose line coverage is enforced. Add new logic files here as they land.
GATED_FILES=(
  "TimerMath.swift"
  "StreakCalculator.swift"
  "SettingsStore.swift"
  "SessionStore.swift"
  "StatsStore.swift"
)

report="$(xcrun xccov view --report --json "$XCRESULT")"

fail=0
for file in "${GATED_FILES[@]}"; do
  pct="$(echo "$report" | python3 -c "
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
cov = None
for target in data.get('targets', []):
    for f in target.get('files', []):
        if f.get('name') == name:
            cov = f.get('lineCoverage', 0.0)
print('' if cov is None else round(cov * 100, 1))
" "$file")"

  if [ -z "$pct" ]; then
    echo "⚠️  $file not found in coverage report (skipped)"
    continue
  fi

  awk -v p="$pct" -v m="$MIN" 'BEGIN { exit !(p+0 >= m+0) }' \
    && echo "✅ $file: ${pct}% (>= ${MIN}%)" \
    || { echo "❌ $file: ${pct}% (< ${MIN}%)"; fail=1; }
done

exit "$fail"
