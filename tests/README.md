# Offline tests

Most of this mod only runs inside a battle. These tests catch what can be
caught before a build is installed and played. Run them all with:

```sh
tests/run.sh
```

They need the gen1recomp install this mod sits in (macOS, portable) and an
imported Emerald ROM. The script extracts the newest engine payload and a copy
of the app's LÖVE into `$TMPDIR/weakness_chart-tests`.

| Test | Checks | Expected |
|---|---|---|
| `lint` | Every global each mod file reads or writes. A misspelt local shows up as an unexpected global. | `ok` for every file. |
| `render` | With the real engine modules and the imported ROM: the footer built from the ROM's button hints; every type combination a battler can have (each species' pair and each single type, with and without Foresight) laid out and checked to stay inside the window and clear of the footer; known matchups, Grass on Rock included, which the engine's other type chart lacks; four pages drawn; both wraps installed on the real modules. | `ALL PASS`, and `render.png` in the work folder to look at. |
| `integration` | The battle paths on stand-ins for the wrapped engine modules, with the engine's own type chart: an engine lacking one of the wrapped functions left untouched, where R opens and closes the chart, keys never reaching the battle while it is open, the PC sounds, page order and arrows in single and double battles, foe/wild prefixes, absent and fainted battlers skipped, Foresight, Transform, the chart closing when its command screen or the battle ends, and an error closing it instead of stopping the battle. | `ALL PASS`. |
