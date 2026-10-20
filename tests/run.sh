#!/bin/sh
# Runs the offline tests against the gen1recomp install this mod sits in
# (mods/weakness_chart/tests -> the install is three levels up).
#
#   lint         every global a mod file touches; a misspelt local shows here
#   render       for each supported game with an imported ROM: draws chart
#                pages with the real engine into render-<game>.png, and checks
#                every type combination of the game fits the window
#   integration  the battle paths on stand-ins for the wrapped engine modules
#
# The engine is read from the newest update payload, and the tests run on a
# copy of the app's LÖVE without its game.love, which would otherwise start
# the game instead of the test.
set -eu

TESTS=$(cd "$(dirname "$0")" && pwd)
MOD=$(dirname "$TESTS")
INSTALL=$(cd "$MOD/../.." && pwd)
WORK=${TMPDIR:-/tmp}/weakness_chart-tests
PAYLOAD=$(ls -t "$HOME/Library/Application Support/pokemon-love2d/updates/"gen1recomp-*.love 2>/dev/null | head -1 || true)
[ -n "$PAYLOAD" ] || PAYLOAD="$INSTALL/gen1recomp.app/Contents/Resources/game.love"

mkdir -p "$WORK"
# macOS empties old files under $TMPDIR, so the extracted engine is checked too
if [ ! -f "$WORK/engine/main.lua" ] || [ "$(cat "$WORK/engine.from" 2>/dev/null)" != "$PAYLOAD" ]; then
  rm -rf "$WORK/engine" && mkdir -p "$WORK/engine"
  unzip -q -o "$PAYLOAD" -d "$WORK/engine"
  echo "$PAYLOAD" > "$WORK/engine.from"
fi
if [ ! -x "$WORK/love.app/Contents/MacOS/love" ]; then
  rm -rf "$WORK/love.app"
  cp -R "$INSTALL/gen1recomp.app" "$WORK/love.app"
  rm -f "$WORK/love.app/Contents/Resources/game.love"
fi

export WCH_MOD="$MOD" WCH_INSTALL="$INSTALL" WCH_ENGINE="$WORK/engine" WCH_WORK="$WORK"
run() { # test, log name
  "$WORK/love.app/Contents/MacOS/love" "$TESTS/$1" > "$WORK/$2.log" 2>&1 &
  pid=$!
  waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 60 ]; do sleep 1; waited=$((waited + 1)); done
  kill "$pid" 2>/dev/null || true
  cat "$WORK/$2.log"
}

echo "== lint"
run lint lint
for game in emerald firered leafgreen; do
  if [ -d "$INSTALL/$game/data/generated/gba" ]; then
    echo "== render ($game)"
    WCH_GAME=$game run render "render-$game"
  else
    echo "== render ($game): no imported ROM, skipped"
  fi
done
echo "== integration"
run integration integration
