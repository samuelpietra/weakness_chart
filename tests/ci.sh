#!/bin/sh
# Runs the offline tests that need no ROM — lint and integration — on Linux,
# as GitHub Actions does: LÖVE from the system (apt), the engine from
# gen1recomp's release of the version this mod was validated on.  render needs
# an imported ROM, which never leaves the player's machine; it runs locally
# with tests/run.sh.
set -eu

ENGINE_VERSION=0.3.85
TESTS=$(cd "$(dirname "$0")" && pwd)
MOD=$(dirname "$TESTS")
WORK=${RUNNER_TEMP:-${TMPDIR:-/tmp}}/weakness_chart-ci

mkdir -p "$WORK"
if [ ! -f "$WORK/engine/main.lua" ]; then
  curl -fsSL -o "$WORK/engine.love" \
    "https://github.com/bryanthaboi/gen1recomp/releases/download/v$ENGINE_VERSION/gen1recomp-$ENGINE_VERSION.love"
  rm -rf "$WORK/engine" && unzip -q "$WORK/engine.love" -d "$WORK/engine"
fi

export WCH_MOD="$MOD" WCH_ENGINE="$WORK/engine" WCH_WORK="$WORK"
failed=0
for test in lint integration; do
  echo "== $test"
  love "$TESTS/$test" > "$WORK/$test.log" 2>&1 || true
  cat "$WORK/$test.log"
done
grep -q -e UNEXPECTED -e "COMPILE ERROR" "$WORK/lint.log" && failed=1
[ "$(grep -c '	ok$' "$WORK/lint.log")" -eq 3 ] || failed=1
grep -qx "ALL PASS" "$WORK/integration.log" || failed=1
exit "$failed"
