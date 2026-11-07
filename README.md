# GunFare

An arcade multiplayer-style FPS built in **Godot 4.7**, played offline against bots, with a deep
rank / unlock / Ascension progression system in the style of the classic 2009-era shooters.

## Play

```
play.cmd
```
or `Godot_v4.7.1-stable_win64.exe --path .`

| Action | Key | Action | Key |
|---|---|---|---|
| Move | WASD | Aim down sights | Right mouse |
| Sprint (hold breath when scoped) | Shift | Fire | Left mouse |
| Crouch | C / Ctrl | Prone | Z |
| Jump / stand | Space | Reload | R |
| Swap weapon | 1 / mouse side | Knife | V / middle mouse |
| Lethal (hold to cook) | G | Tactical | Q |
| Use streak reward | 4 | Cycle streak rewards | 5 |
| Underbarrel attachment | B | Interact (crates, dropped guns) | F |
| Scoreboard | Tab | Pause / class change | Esc |

All bindings can be changed in Options.

## Content

- **Modes:** Team Deathmatch, Free-for-All, Domination, Kill Confirmed, Headquarters.
- **Maps (8):** Dustline, Coldharbor, Overpass, Refinery, Pinecrest, Hangar 9, Villa Marisol, Ashgrove.
- **Weapons (38):** assault rifles, SMGs, LMGs, snipers, pistols, machine pistols, shotguns, launchers.
  Each has its own attachment unlock track (kills) and camo track (headshots).
- **Perks (17)** across three slots, each with an *Elite* upgrade challenge. **Setback perks** (deathstreaks).
- **Streak rewards (13):** Pulse Scan, Supply Crate, Mortar Strike (player-guided), Jammer, Sentry Post,
  Strafing Run, Hunter Drone, Escort Chopper, Carpet Bomb, Deep Scan, Overwatch Gunship
  (player-controlled, three cannons), Blackout Pulse, Doomsday.
- **Progression:** 70 ranks, 10 Ascensions, 100+ tiered challenges, titles and emblems, career stats.

## Project layout

| Path | What |
|---|---|
| `scripts/autoload/` | Global systems: settings, content database, progression, challenges, audio, FX, scene flow |
| `scripts/game/` | Soldier, weapons, ballistics, equipment, models |
| `scripts/bots/` | Bot AI |
| `scripts/match/` | Match flow and game modes |
| `scripts/streaks/` | Streak rewards, aircraft, sentry, crate |
| `scripts/maps/` | Map builder and the maps |
| `scripts/player/` | Player controller, viewmodel, HUD |
| `scripts/ui/` | Menus |
| `tools/` | Asset generators: Blender models, synthesized audio, PBR textures, voice lines |
| `tests/` | Headless tests |

## Regenerating assets

```
python tools/gen_audio.py          # sound effects + music
python tools/gen_textures.py 1024  # world textures
python tools/gen_vo.py             # announcer (Windows TTS)
blender -b -P tools/blender/build_weapons.py
blender -b -P tools/blender/build_props.py
blender -b -P tools/blender/build_characters.py
```

## Updates

Extract the zip file to a folder before you start the game, for example `Documents\GunFare`. If you start the game from inside the zip file, Windows runs it from a temporary folder. Then an update installs into `%LOCALAPPDATA%\Programs\GunFare`, and the main menu shows that folder.

A release build checks GitHub for a newer version when the game starts. It checks again every 5 minutes and when the window gets the focus. A new version shows on the main menu without a restart.

Choose **Install Update** on the main menu. The game downloads the package and examines the size and the SHA-256 checksum. Then the game closes, installs the files, and starts again. If a step fails, the install script puts the old files back and starts the old version. The main menu then shows the reason.

A source build can show that a version is available. Install the package only from a release build.

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md). Do not push to `main`. Open a pull request. Write the pull request in ASD-STE100. Add a screenshot, a diagram, or a table when the change needs it.

## Tests

```
Godot_console.exe --headless --path . res://tests/test_progression.tscn
Godot_console.exe --headless --path . res://tests/smoke_match.tscn -- <map> <mode> <seconds>
```
The smoke test plays a full bot match (the player is bot-driven) and reports kills, score and progression.

## Notes

Real-world firearm designations are used for weapon names. Some are manufacturer trademarks; review
naming before any commercial release.
