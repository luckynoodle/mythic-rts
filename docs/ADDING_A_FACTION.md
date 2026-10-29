# Adding a faction

Every faction is one JSON file in `data/factions/`. The game picks it up automatically,
and no code changes are needed for the basics.

## 1. Copy an existing faction

```bash
cp data/factions/humans.json data/factions/elves.json
```

## 2. Edit the top-level fields

| Field | Meaning |
|---|---|
| `id` | Unique id, e.g. `"elves"` |
| `name`, `description` | Shown in the UI |
| `color` | Team colour, e.g. `"#2ecc71"` |
| `hq` | Building id of the headquarters (must train the builder and accept all resources) |
| `builder` | Unit id of the worker |
| `supply_building` | Building id the game suggests when you're out of supply |
| `starting_resources` | `{ "gold": 300, "wood": 200, "stone": 0 }` |
| `starting_units` | Unit ids spawned next to the HQ |

## 3. Units

```json
"ranger": {
  "name": "Ranger",
  "role": "ranged",
  "hp": 70, "armor": 0, "speed": 95, "radius": 10, "sight": 340, "supply": 1,
  "cost": { "gold": 70, "wood": 40 },
  "train_time": 15,
  "requires": ["moonwell"],
  "attack": { "damage": 10, "range": 190, "cooldown": 1.4, "projectile": true, "projectile_speed": 560 }
}
```

- **`role`** is one of `builder`, `melee`, `ranged`, `heavy`, `vehicle` or `flyer`. It controls the placeholder shape, and builders gather and build.
- **Builders** also need `carry_capacity`, `gather_time` and `build_rate`.
- **`requires`** lists buildings that must be *completed* before this unit can be trained.
- **`attack.splash`** (optional) adds area damage around the impact point.

## 4. Buildings

```json
"moonwell": {
  "name": "Moonwell",
  "hp": 600, "armor": 1, "size": [80, 80],
  "cost": { "gold": 100, "wood": 60 },
  "build_time": 30,
  "requires": [],
  "trains": [],
  "drop_off": ["wood"],
  "supply": 6
}
```

- **`trains`** lists the units this building can produce. Every unit must be trained somewhere.
- **`drop_off`** lists the resources builders can deliver here.
- **`supply`** is how much it raises the supply cap once complete.
- Set **`"buildable": false`** to hide a building from the build menu.

## 5. AI

```json
"ai": {
  "target_workers": 12,
  "gather_ratio": { "gold": 0.5, "wood": 0.35, "stone": 0.15 },
  "stockpile_cap": 400,
  "build_order": ["moonwell", "ancient_of_war", "..."],
  "army": ["ranger", "ranger", "dryad", "..."]
}
```

The AI builds the `build_order` list in sequence, rebuilding anything that gets destroyed. It trains
units from `army` in rotation at whichever building can produce them.

## 6. Check it

```bash
python3 tools/validate_data.py
```

The validator catches typos in ids, missing requirements, unknown resources and similar
mistakes. To play the new faction, set `player_faction` or `ai_faction` on the
`Main` node in `scenes/main.tscn`. A faction-select menu is on the roadmap.

## Unique mechanics

Anything beyond stats, such as life-steal, flying or regeneration, needs code. The plan is
to add an `abilities` list to units, backed by small scripts in `scripts/abilities/`.
See docs/ROADMAP.md (v0.4).
