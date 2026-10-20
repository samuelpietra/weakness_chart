# Offline tests

Most of this mod only runs inside a battle. These tests catch what can be
caught before a build is installed and played. Run them all with:

```sh
tests/run.sh
```

`tests/ci.sh` runs `lint`, `engine` and `integration` — the tests that need no ROM — on
Linux with the system's LÖVE and the engine downloaded from gen1recomp's
release of the version this mod was validated on. GitHub Actions runs it on
every push and pull request, and before every release. `render` never runs
there: a ROM does not leave the player's machine.

`tests/run.sh` needs the gen1recomp install this mod sits in (macOS, portable). `render`
runs once for each of Emerald, FireRed and LeafGreen whose ROM is imported, and
says which it skipped. The script extracts the newest engine payload and a copy
of the app's LÖVE into `$TMPDIR/weakness_chart-tests`.

| Test | Checks | Expected |
|---|---|---|
| `lint` | Every global each mod file reads or writes. A misspelt local shows up as an unexpected global. | `ok` for every file. |
| `engine` | On the real engine, without a ROM: every module in `main.lua`'s `ENGINE` and every function `main.lua` and `lib/` call; the three PC sounds; known matchups from `Types.typeCalc`, Foresight included; the engine still having the command screens' `Ui._mode`s, leaving R free in them, setting `Ui._wally`, opening the Help System on L and R, taking Transform's types and Foresight in its damage code, and emitting `battle.started` and `battle.ended`; the three wraps going in on the real modules. A function renamed in an engine update fails here, in CI, instead of switching the chart off in the game. | `ALL PASS`. |
| `render` | For each imported game, with the real engine modules and that game's ROM: the footer built from the ROM's button hints; every type combination a battler can have (each species' pair and each single type, with and without Foresight) laid out and checked to stay inside the window and clear of the footer; known matchups, Grass on Rock included, which the engine's other type chart lacks; four pages drawn; both wraps installed on the real modules. | `ALL PASS` per game, and `render-<game>.png` in the work folder to look at. |
| `integration` | The battle paths on stand-ins for the wrapped engine modules, with the engine's own type chart: an engine lacking one of the wrapped functions left untouched, where R opens and closes the chart, keys never reaching the battle while it is open, the PC sounds, page order and arrows in single and double battles, foe/wild prefixes, absent and fainted battlers skipped, Foresight, Transform, the chart staying shut in the tutorials and the Pokédude's lessons, FireRed's own button hints and badges, R going to the chart instead of FireRed's Help System in the command screens while L and R elsewhere still open the help, but not over the open chart, the chart closing when its command screen or the battle ends, and an error closing it instead of stopping the battle. | `ALL PASS`. |
