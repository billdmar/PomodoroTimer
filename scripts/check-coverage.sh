#!/usr/bin/env bash
# Enforces a line-coverage floor on the app's pure-logic files.
#
# SwiftUI view code is intentionally excluded — it is verified by build + UI
# smoke tests, not unit coverage, so a global threshold would be meaningless.
# This gate guards the testable business logic.
#
# Logic files are DISCOVERED by naming convention rather than hardcoded, so a
# new logic file can't silently bypass the gate. A file is gated when its name
# ends in one of the logic suffixes below AND it contains no opt-out marker.
# To exclude a file (e.g. a thin wrapper that legitimately can't be unit-tested),
# add a line containing:  // coverage:ignore-file
#
# Usage: check-coverage.sh <path-to-.xcresult> [min-percent]
set -euo pipefail

XCRESULT="${1:?usage: check-coverage.sh <xcresult> [min-percent]}"
MIN="${2:-80}"
SRC_DIR="${SRC_DIR:-pomadoro2}"

# A file is logic (and thus gated) when its name ends in one of these.
LOGIC_SUFFIXES='(Math|Calculator|Store|State|Content|Evaluator|Recovery|Policy|Achievements|Settings|Engine)\.swift$'

# Discover the gated files from the source tree.
gated=()
while IFS= read -r path; do
  base="$(basename "$path")"
  # Skip view-ish names that happen to match (none today, but future-proof).
  if grep -q "coverage:ignore-file" "$path"; then
    echo "➖ $base excluded (coverage:ignore-file)"
    continue
  fi
  gated+=("$base")
done < <(find "$SRC_DIR" -name '*.swift' | grep -E "$LOGIC_SUFFIXES" | sort)

if [ "${#gated[@]}" -eq 0 ]; then
  echo "❌ No logic files discovered under $SRC_DIR — check the gate configuration."
  exit 1
fi

report="$(xcrun xccov view --report --json "$XCRESULT")"

fail=0
for file in "${gated[@]}"; do
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
    # A discovered logic file that never appeared in the report means it has no
    # tests at all — that's a gate failure, not a skip.
    echo "❌ $file: not exercised by any test (0 coverage rows)"
    fail=1
    continue
  fi

  awk -v p="$pct" -v m="$MIN" 'BEGIN { exit !(p+0 >= m+0) }' \
    && echo "✅ $file: ${pct}% (>= ${MIN}%)" \
    || { echo "❌ $file: ${pct}% (< ${MIN}%)"; fail=1; }
done

exit "$fail"
