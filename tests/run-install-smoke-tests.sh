#!/bin/bash
set -euo pipefail
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/gestalt-installcheck.XXXXXX")"
xcrun clang -fobjc-arc -fblocks -framework Foundation \
  -DGESTALT_INSTALL_SMOKE_TEST=1 -DGESTALT_READ_ONLY_PROBE=1 -DGESTALT_ENABLE_WRITES=0 \
  GestaltEdit/GestaltAccess.m GestaltEdit/BadQueryBridge.m tests/InstallSmokeTests.m \
  -o "$test_dir/installcheck"
"$test_dir/installcheck"
for config in '1 0 1' '2 1 0'; do
  read -r smoke probe writes <<< "$config"
  if xcrun clang -fsyntax-only -fobjc-arc -fblocks \
    -DGESTALT_INSTALL_SMOKE_TEST="$smoke" -DGESTALT_READ_ONLY_PROBE="$probe" -DGESTALT_ENABLE_WRITES="$writes" \
    GestaltEdit/GestaltAccess.m > "$test_dir/invalid.log" 2>&1; then
    echo "FAIL: unsafe installation config accepted: $config" >&2
    exit 1
  fi
  grep -F 'Install smoke tests require read-only configuration' "$test_dir/invalid.log"
  echo "PASS: compiler rejects install configuration $config"
done
