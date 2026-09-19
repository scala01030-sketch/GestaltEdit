#!/bin/bash
set -euo pipefail
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/gestalt-safety.XXXXXX")"
# Deliberately retain host test logs/binaries in the runner's temporary directory.
for mode in readonly writepolicy; do
  if [[ "$mode" == readonly ]]; then probe=1; writes=0; else probe=0; writes=1; fi
  xcrun clang -fobjc-arc -fblocks -framework Foundation \
    -DGESTALT_READ_ONLY_PROBE="$probe" -DGESTALT_ENABLE_WRITES="$writes" \
    tests/SafetyTests.m -o "$test_dir/$mode"
  "$test_dir/$mode"
done
for config in '1 1' '0 0' '2 0' '0 2' '-1 0'; do
  read -r probe writes <<< "$config"
  if xcrun clang -fsyntax-only -fobjc-arc -fblocks \
    -DGESTALT_READ_ONLY_PROBE="$probe" -DGESTALT_ENABLE_WRITES="$writes" \
    tests/SafetyTests.m > "$test_dir/invalid.log" 2>&1; then
    echo "FAIL: unsafe config accepted: $config" >&2
    exit 1
  fi
  grep -E 'must not be built|Select exactly one mode' "$test_dir/invalid.log"
  echo "PASS: compiler rejects $config"
done
