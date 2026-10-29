# Notes for Claude

- Godot **4.3**, GDScript, 2D, iOS-first (touch). Mobile renderer.
- Everything is built in code from `scenes/main.tscn` → `scripts/game/main.gd`. Avoid adding
  hand-written `.tscn` files unless needed; prefer code-built nodes.
- **Game content is data**: `data/factions/*.json`. Add stats and units there, not in code.
  Run `python3 tools/validate_data.py` after editing.
- Units and the AI are driven only through `Unit.command_*` and `Building.enqueue`.
  Keep it that way, because a future multiplayer mode depends on it.
- Use `Entity.alive(x)` / `ResourceNode.alive(x)` before touching references that may be freed.
- `Game.units` / `Game.buildings` / `Game.resource_nodes` are per-frame snapshots; use them
  instead of `get_nodes_in_group` in hot loops.
- Tests: `GODOT=<path> tools/run_tests.sh`. Input tests live in `tests/input_test.gd` and run via
  `godot --headless -- --run-input-tests` (so autoloads are available). Add a test for new controls.
- Commit messages: short imperative summary line, then details.
