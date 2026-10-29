# Mythic RTS

A touch-first 2D real-time strategy game for **iPhone and iPad**, built with **Godot 4**.
Mythical factions — humans, orcs, and soon elves, vampires, fairies and more — gather
resources, raise bases and fight for control of the land.

> **Status: playable prototype (v0.1).** Humans vs. Orcs skirmish against an AI opponent,
> with placeholder shapes instead of art.

## What's in the game so far

- **Two factions**, defined entirely in data (`data/factions/*.json`). Each faction has:
  - 5 units: a builder, melee, ranged, heavy and siege (vehicle) unit
  - 6 buildings: an HQ, a supply farm, two production buildings, a drop-off mill and a siege workshop
- **Economy.** Builders gather gold, wood and stone and carry it back to the HQ or a mill. Farms raise your supply cap.
- **Construction.** Placing a building creates a construction site, and builders finish it over time.
- **Tech requirements.** For example, archers need a Lumber Mill and Stables need a Barracks.
- **Combat.** Melee and ranged units, splash-damage siege engines, auto-targeting and attack-move.
- **AI opponent.** It manages its economy, follows a build order from the faction file, trains an army and attacks in growing waves after a peaceful opening.
- **Touch controls and HUD**, built for phones and tablets and safe-area aware.

## Controls

| Gesture | What it does |
|---|---|
| Tap a unit or building | Select it |
| Double-tap a unit | Select all of that type on screen |
| Tap ground / enemy / resource | Move / attack / gather with the selection |
| Tap a building with nothing selected | Select it (trains units; tap the ground to set its rally point) |
| One-finger drag | Pan the camera |
| Pinch | Zoom |
| **Box Select** button, then drag | Draw a selection box |
| **Army** / **Idle Worker** buttons | Quick-select your army / cycle idle workers |
| **Attack-move**, then tap the ground | Advance and fight anything on the way |

When building, tap a building button and a ghost footprint appears. Tap or drag the ghost
to position it, then tap it again (or press **Place**) to start construction.

On desktop, the left mouse acts as touch, the wheel zooms and right-click issues commands.

## Getting started

### Requirements

- **Godot 4.3** or later (standard build): https://godotengine.org/download
- For iOS builds you also need:
  - a **Mac with Xcode**
  - the Godot **export templates**, installed from Godot under *Editor → Manage Export Templates*
  - an **Apple Developer** account. A free account works for running on your own device; a paid membership is needed for TestFlight and the App Store.

### Run it

1. Clone the repo, open Godot and **Import** `project.godot`.
2. Press **F5** to play. The game opens in a 1280×720 window. Mouse clicks emulate touch.

### Run it on an iPhone or iPad

1. In Godot, go to *Project → Export…* and select the **iOS** preset that ships with the project.
2. Fill in your **App Store Team ID**. The bundle identifier is set to `com.luckynoodle.mythicrts`; change it if you like.
3. Click **Export Project** and choose a folder. Godot generates an Xcode project there.
4. Open the `.xcodeproj` in Xcode, select your device, and press **Run**.

The preset targets iPhone and iPad, iOS 14+, landscape.

## Project layout

```
data/factions/        Faction definitions (units, buildings, costs, AI build orders)
scenes/main.tscn      The skirmish scene (everything else is built in code)
scripts/autoload/     GameData (loads JSON) and Game (match state, spawning, queries)
scripts/entities/     Entity base class, Unit, Building, ResourceNode, Projectile
scripts/input/        TouchInput (gestures → commands), placement ghost, markers
scripts/ui/           HUD (resource bar, selection panel, action buttons)
scripts/ai/           SimpleAI opponent
tests/                Automated touch-input tests
tools/                Data validator and test runner
docs/                 Roadmap and how to add a faction
```

### How it fits together

- **Data-driven factions.** `GameData` loads every JSON file in `data/factions/`.
  Units, buildings, costs, requirements and AI build orders all live in those files,
  so adding the elves is mostly writing `elves.json`. See [docs/ADDING_A_FACTION.md](docs/ADDING_A_FACTION.md).
- **`Game` autoload.** Owns the players, spawns entities and answers shared queries
  such as *nearest drop-off*, *nearest enemy*, *is this area free*, and *supply used*.
- **`Unit`.** A small state machine with the states `IDLE`, `MOVE`, `ATTACK`, `GATHER`, `RETURN` and `BUILD`.
  The player's `TouchInput` and the `SimpleAI` both drive units through the same `command_*` methods.
- **`Building`.** Handles construction progress, training queues, rally points, drop-off and supply.

## Testing

```bash
python3 tools/validate_data.py                               # check faction JSON
GODOT=/path/to/godot tools/run_tests.sh                      # everything below
godot --headless -- --run-input-tests                        # simulated touch tests
godot --headless --fixed-fps 30 -- --ai-vs-ai --quit-after-seconds=600   # AI vs AI match
```

GitHub Actions runs `tools/run_tests.sh` on every push and pull request.

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md). The next big items are:
- real pathfinding
- fog of war and a minimap
- art and sound
- more factions (elves, vampires, fairies)
- a main menu with faction select
