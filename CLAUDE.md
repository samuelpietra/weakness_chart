# Weakness Chart — working notes for Claude

A gen1recomp mod for Pokémon Emerald, FireRed and LeafGreen: in a battle, R
over a command screen opens a chart of each battler on the field — its types
and the attacking types grouped by damage. The README is the spec.

Answer in the language the person is writing in. Everything committed —
code, comments, README, commit messages — is in English.

## How this mod is built

- `main.lua` wires the engine and the keys; `lib/chart.lua` says what a page
  holds; `lib/layout.lua` places and draws it.
- `resolveEngine` checks every module and function the chart needs; the
  wraps (`Ui.handleInput`, `Battle.draw`, `Help.update`) go in together or
  not at all, through `wrap`, which keeps the engine's originals for hot
  reloads. `guarded` closes the chart on an error instead of stopping the
  battle.
- Multipliers come from the engine's damage chart, `Types.typeCalc`, with the
  defender's types taken as the damage code takes them (Transform,
  Foresight). Not `Types.effectiveness`: that chart lacks Grass on Rock.
- What differs per game lives in one table, `GAMES` in `lib/layout.lua`,
  keyed by `Profile.family()`: badges and the button hints' ROM keys.
- R, not L: L doubles as A in the L=A button mode. In FireRed/LeafGreen, R
  over a command screen goes to the chart instead of the Help System; L still
  opens the help, except over the open chart.
- Authored on purpose: the labels 4×, 2×, 1/2×, 1/4×, 0× (ROM glyphs), the
  footer joining the ROM's PICK and EXIT with the R icon, hiding 1× and empty
  groups, the screen's composition. Everything drawn is the ROM's.

## Vanilla first

The mod adds what the game lacks with the game's own pieces, so a player
cannot tell where the game ends and the mod begins.

- **No new pixels, sounds, music or fonts.** Graphics, text, sounds and rules
  come from the player's imported ROM or from the engine. A mod may ship data
  about the ROM's assets (which tiles, which pixels belong, which palette
  colours to swap), never the assets themselves.
- **Text comes from the ROM when the ROM has it.** Search the script cache
  (`RomText`) before writing a string; join the ROM's own words before
  authoring new ones. Authored text is the last resort, and it follows the
  game's style (capitals, `{PKMN}`, line lengths).
- **Behaviour copies the original.** A piece, screen or sound that exists in
  the game behaves as it does there: same script, same collision, same
  sound, same cursor rules. Departures are the maintainer's call, made
  explicitly, and recorded in the README.
- **Find the engine's own function first.** Before drawing, measuring or
  computing something, look for the engine module that already does it (the
  summary screen's badges, the list menu's arrows, the damage code's type
  chart) and call it.
- At a visual impasse — alignment, layout, which sprite or colour — render
  the options from the real ROM into an image and show it before building
  one.

## Scope

- Build what was asked. No option, setting, flag, fallback path or
  abstraction nobody asked for: a value the spec fixes is a constant.
- Something out of scope that seems useful is offered as a suggestion, not
  built.
- When reporting, audit additions against the request and say plainly which
  parts were not in it.

## Code

- Match the surrounding code: its names, comment density and idioms.
- Names say what a thing means in the game ("choosingCommand", "footprintTop"),
  not how it is computed.
- Comment only what reading the file cannot reveal: engine behaviour this
  relies on (cite the engine file or the pret source), or a rule this mod
  imposes and why. Never restate the next line.
- Reuse before adding: a second copy of a pattern becomes one helper; a
  table of data beats parallel branches.
- Leave no leftovers: unused locals, dead branches, debug prints, stale
  comments and helpers whose last caller went away are deleted in the same
  change.
- Engine access goes through the mod's own helpers and patterns (*How this
  mod is built*); a new kind of access follows them, or says in a comment
  why it cannot.

## Before saying it is done

Run `tests/run.sh` (see `tests/README.md`) and read every result. `render`
runs once per imported game and checks every type combination fits the
window; a layout change must keep it passing in each game. A fix comes with
a test that fails before it and passes after; a new engine call gets its
entry in `engine`'s `CALLED`. Look at `render-<game>.png` after any visual
change. Then hand the build over for an in-game test in each supported game
the change touches, naming the cases to try.

## Releasing

Commit only when the maintainer says so, usually after playing the build.

- [Conventional Commits](https://www.conventionalcommits.org): `feat`, `fix`,
  `refactor`, `docs`, `chore`, with a scope when it carries signal.
- One SemVer tag per commit, `vMAJOR.MINOR.PATCH`: every commit is a build
  that gets installed, so `refactor`, `docs` and `chore` bump the patch too
  (README, *Versioning*). `manifest.json`'s `version` moves with the tag, in
  the same commit.
- End every commit message with the co-author trailer:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (or the model in
  use).
- Update the README in the same commit when behaviour, requirements or
  layout change.
- `./package.sh` writes the install zip of the tagged release to
  `~/Desktop/weakness_chart-<version>.zip`, leaving out what
  `.gitattributes` marks `export-ignore` (tests and tooling).
- Players get updates from GitHub releases (`github` in the manifest).
  `release.yml` publishes one, zip attached, for each pushed tag; push with
  `git push --follow-tags`. `ci.yml` fails a pushed commit that does not
  raise the version or lacks its tag (`.github/scripts/check_versions.sh`).
- CI runs only the ROM-free tests (`tests/ci.sh`); `tests/run.sh` with the
  render test stays the local check before every commit.
