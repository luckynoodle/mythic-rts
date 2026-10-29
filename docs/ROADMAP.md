# Roadmap

## v0.1 — Playable prototype ✅
- Humans vs. Orcs skirmish on one map
- Gathering (gold / wood / stone), construction, training queues, supply
- Melee, ranged, heavy and siege units; attack-move
- Touch controls, HUD and a simple AI opponent
- Automated tests and CI

## v0.2 — 3D view ✅
- 3D renderer (WorldView) mirroring the 2D simulation; Warcraft-style fixed RTS camera
- Heroic placeholder models for every unit, building, resource and projectile
- Drop-in model pipeline with team colour, animation mapping and attachment points (docs/ART_GUIDE.md)
- Screen-space tap picking (tap a unit's body or a building's roof), 3D placement ghost
- Construction rise, damage smoke, hit flash, death animations, projectile arcs

## v0.3 — Feels like a real RTS
- [ ] **Pathfinding**: replace straight-line steering with `NavigationServer2D`, rebaking the nav mesh when buildings are placed or destroyed
- [ ] **Spatial hash** for unit separation and target queries, to support 150+ units on older iPhones
- [ ] **Fog of war** using each entity's `sight` radius
- [ ] **Minimap**: tap it to jump the camera there
- [ ] Defensive building: a **guard tower** for each faction
- [ ] Builders can **repair** damaged buildings
- [ ] Control groups, or saved selections shown as HUD buttons

## v0.4 — Look & sound
- [ ] Real 3D models: start with free CC0 packs, then custom heroic models (docs/ART_GUIDE.md)
- [ ] Rigged animations (idle / walk / attack / work / die) with retargeting shared across humanoids
- [ ] Terrain texture painting (dirt paths, cliffs, water) and decals under buildings
- [ ] Spell, impact and death VFX
- [ ] Sound effects and music
- [ ] App icon and launch screen

## v0.5 — More factions
Each faction gets its JSON file plus one or two unique mechanics:
- [ ] **Elves**: units regenerate near trees; archers outrange others
- [ ] **Vampires**: life-steal on attacks; strong at night (needs a day/night cycle)
- [ ] **Fairies**: most units are flyers that ignore terrain (needs `flyer` movement rules)
- [ ] Faction abilities system: data-driven special abilities with cooldowns

## v0.6 — Game structure
- [ ] Main menu, faction select and AI difficulty settings
- [ ] Multiple maps, defined as data or tilemaps
- [ ] Pause menu, settings and save/resume for mobile interruptions
- [ ] Campaign missions

## Later
- [ ] Multiplayer. This needs deterministic simulation and command-based networking, so keep game logic driven only by `command_*` calls and seeded RNG.
- [ ] Game Center achievements and leaderboards
- [ ] Android export, which Godot supports with minimal changes
