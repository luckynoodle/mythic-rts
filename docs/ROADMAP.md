# Roadmap

## v0.1 — Playable prototype ✅
- Humans vs. Orcs skirmish on one map
- Gathering (gold / wood / stone), construction, training queues, supply
- Melee, ranged, heavy and siege units; attack-move
- Touch controls, HUD and a simple AI opponent
- Automated tests and CI

## v0.2 — Feels like a real RTS
- [ ] **Pathfinding**: replace straight-line steering with `NavigationServer2D`, rebaking the nav mesh when buildings are placed or destroyed
- [ ] **Spatial hash** for unit separation and target queries, to support 150+ units on older iPhones
- [ ] **Fog of war** using each entity's `sight` radius
- [ ] **Minimap**: tap it to jump the camera there
- [ ] Defensive building: a **guard tower** for each faction
- [ ] Builders can **repair** damaged buildings
- [ ] Control groups, or saved selections shown as HUD buttons

## v0.3 — Look & sound
- [ ] Sprite art per faction, with idle, walk, attack and death animations
- [ ] Building sprites and construction stages
- [ ] Hit effects, death effects and projectile sprites
- [ ] Sound effects and music
- [ ] App icon and launch screen

## v0.4 — More factions
Each faction gets its JSON file plus one or two unique mechanics:
- [ ] **Elves**: units regenerate near trees; archers outrange others
- [ ] **Vampires**: life-steal on attacks; strong at night (needs a day/night cycle)
- [ ] **Fairies**: most units are flyers that ignore terrain (needs `flyer` movement rules)
- [ ] Faction abilities system: data-driven special abilities with cooldowns

## v0.5 — Game structure
- [ ] Main menu, faction select and AI difficulty settings
- [ ] Multiple maps, defined as data or tilemaps
- [ ] Pause menu, settings and save/resume for mobile interruptions
- [ ] Campaign missions

## Later
- [ ] Multiplayer. This needs deterministic simulation and command-based networking, so keep game logic driven only by `command_*` calls and seeded RNG.
- [ ] Game Center achievements and leaderboards
- [ ] Android export, which Godot supports with minimal changes
