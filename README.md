# Weakness Chart

A gen1recomp mod for Pokémon Emerald, FireRed and LeafGreen. In a battle, press **R** while choosing a
command to open a chart of every Pokémon on the field:

- its name, level and types, in a header window;
- below, every attacking type that hits it for **4×**, **2×**, **1/2×**,
  **1/4×** or **0×** damage, as the game's own type badges.

Types that deal normal damage (1×) are left out, and so are the groups no type
falls in. **Up** and **down** go through the Pokémon on the field, foes first;
**R** closes the chart. While it is open, the battle waits. It sounds like the
PC's storage screens: the log-in sound opening it, the menu blip turning a
page, the log-off sound closing it.

Foes are named as the battle text names them, "Foe GEODUDE" against a trainer
and "Wild GEODUDE" in the grass; your own Pokémon carry no prefix. The chart
follows the battle as the damage calculation does: a Pokémon that changed type
(Color Change, Conversion, Camouflage) or Transformed shows the types it has
now, and after Foresight a Ghost no longer lists Normal and Fighting as 0×.

Everything on screen comes from **your own imported ROM**: the window frame you
chose in OPTIONS, the text font, the summary screen's type badges, the list
menu's scroll arrows, and the footer's button hints, which join the words of
two of the game's own ("✥PICK ⒶOK" and "ⒶEXIT"). Each game draws with its own
pieces, so the chart in FireRed has FireRed's font and its smaller badges.

## Requirements

| | |
|---|---|
| Game | Pokémon Emerald, FireRed or LeafGreen (played on Emerald and FireRed; LeafGreen shares FireRed's code and is untested) |
| Engine | gen1recomp 0.3.85 or newer (the version it was validated on) |
| Mod API | 2 |
| Permissions | `engine_internals` |

The mod reaches engine modules that are not on the Gen 3 mod facade list, so it
declares the `engine_internals` permission. The Mod Manager flags that with a
`!` badge reading *PATCHES ENGINE CODE*; it is expected.

## Installing

gen1recomp loads mods from a `mods` folder. On a portable install — one with a
`portable.txt` next to the application — that folder sits beside the app:

```
gen1recomp/
├── portable.txt
├── gen1recomp.app
└── mods/
    └── weakness_chart/
        ├── main.lua
        ├── manifest.json
        └── lib/
```

1. Copy the `weakness_chart` folder into `mods/`, keeping the folder name.
2. Start gen1recomp and open the Mod Manager.
3. Enable **Weakness Chart** and accept the `engine_internals` prompt.
4. Load an Emerald, FireRed or LeafGreen save.

Mods are loaded when gen1recomp starts. After enabling or disabling the mod,
quit the game and start it again from gen1recomp; going back to the title
screen is not enough.

## Updating

The manifest names this repository (`github`), so gen1recomp's Mod Manager
checks its [releases](https://github.com/samuelpietra/weakness_chart/releases)
and offers a newer one with an **Update** button; **Check for updates** asks
again right away instead of waiting for the six-hour cache.

## Using it

The chart opens over the action menu (FIGHT, BAG, POKéMON, RUN), the move list
and the choice of a target in a double battle. Elsewhere — while a message
runs, in the bag or the party screen — R does what it did before, which in a
battle is nothing. It stays shut while the game plays a battle for you: the old
man's and Wally's catching tutorials, and the Pokédude's lessons. The chart
opens on the first foe.

In FireRed and LeafGreen, L and R open the Help System when OPTIONS has the
button mode on HELP. In the command screens R opens the chart instead; L still
opens the help there, unless the chart is open, and R does everywhere else.

R is the game's R button: on a keyboard, E or right Ctrl unless you changed the
controls. On a gamepad, gen1recomp leaves the shoulder buttons out of gameplay
unless you bind them yourself.

## Contributing

### Commit messages

[Conventional Commits](https://www.conventionalcommits.org), with a scope when
it carries signal:

```
feat(chart): R opens a weakness chart of the battlers on the field
fix(layout): keep six rows of badges inside the window
```

Types in use: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`.

### Versioning

[Semantic Versioning](https://semver.org), one release per commit, tagged
`vMAJOR.MINOR.PATCH`:

| Change | Bump |
|---|---|
| Incompatible change | major |
| Backward compatible functionality | minor |
| Backward compatible bug fix | patch |

**A local convention worth stating, because it departs from the spec:**
`refactor`, `docs`, `test`, `chore` and `ci` also bump the patch version here.
SemVer versions releases rather than commits, so a pure refactor normally waits
for the next release instead of earning a version of its own. In this
repository every commit is a build that gets installed and played, and two
different builds must never both claim the same version — otherwise there is no
way to tell which one is running.

Keep `manifest.json`'s `version` field in step with the tag.

A release players can update to is a GitHub release of that tag with the zip
from `package.sh` attached; pushing a commit updates no one. GitHub Actions
does both checks and the publishing:

| Workflow | When | What |
|---|---|---|
| `ci.yml` | every push to `main` and pull request | `tests/ci.sh` (lint, engine and integration); every pushed commit raises the version and carries its tag |
| `release.yml` | a pushed tag `v*` | the tests again, then a GitHub release of the tag with the zip attached and the commit message as its notes |

Tag each commit with an annotated tag, `git tag -a vX.Y.Z -m vX.Y.Z`, and push
commits with their tags: `git push --follow-tags`, which sends annotated tags
only. GitHub sends no tag events for a push of more than three tags; release
such a push by hand from **Actions → Release → Run workflow**, naming the
newest tag.

### Packaging

`./package.sh` writes the install zip of the release `manifest.json` names to
`~/Desktop/weakness_chart-<version>.zip`: the files of its tag, in a
`weakness_chart` folder, without the tests and tooling (`.gitattributes` marks
them `export-ignore`). It stops if that version has no tag yet.

### Code

- English only, in comments as well as identifiers.
- Names carry the meaning. A comment earns its place when it records something
  that reading this file cannot reveal: engine behaviour, or a rule this mod
  imposes. A comment that restates the next line does not.
- Engine modules are reached through `engineModule` and changed only through
  `wrap`, so a renamed or missing engine function switches the chart off and is
  named in the log, instead of breaking the game. An error while the chart is
  open closes it and is logged; the battle goes on.

### Layout

| File | What |
|---|---|
| `main.lua` | Wiring: the engine hooks, when R opens and closes the chart, the pages. |
| `lib/chart.lua` | What a page says: the battler's name, level and types, and its matchups, from the engine's own damage calculation. |
| `lib/layout.lua` | Where everything goes on screen, and the drawing; the pieces that differ between Emerald and FireRed/LeafGreen. |
| `tests/` | Offline tests, run with `tests/run.sh`; `tests/ci.sh` runs the ROM-free ones in CI (see `tests/README.md`). |
| `.github/` | The CI and release workflows, and the check that every commit is a tagged release. |
