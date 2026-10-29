# Notes for Claude

- Godot **4.3**, GDScript, iOS-first (touch). Mobile renderer. **2D simulation, 3D view.**
- The simulation (Game, Unit, Building, ResourceNode, Projectile) is 2D in pixels and must never
  depend on the view. `scripts/view3d/WorldView` mirrors it in 3D (16 px = 1 m, ViewSpace).
  Input converts screen<->world via `RTSCamera`; picking is screen-space (`TouchInput.pick_at`).
- Art: models come from `ModelLibrary` (JSON "model" path → `res://art/<faction>/<id>.glb` →
  `PlaceholderModels`). Follow docs/ART_GUIDE.md conventions; don't hard-code art in visuals.
- Everything is built in code from `scenes/main.tscn` → `scripts/game/main.gd`. Avoid adding
  hand-written `.tscn` files unless needed; prefer code-built nodes.
- **Game content is data**: `data/factions/*.json`. Add stats and units there, not in code.
  Run `python3 tools/validate_data.py` after editing.
- Units and the AI are driven only through `Unit.command_*` and `Building.enqueue`.
  Keep it that way, because a future multiplayer mode depends on it.
- Use `Entity.alive(x)` / `ResourceNode.alive(x)` before touching references that may be freed.
- `Game.units` / `Game.buildings` / `Game.resource_nodes` are per-frame snapshots; use them
  instead of `get_nodes_in_group` in hot loops.
- Headless runs print `Parameter "m" is null (mesh_storage)` once per mesh instance: that's Godot's
  dummy renderer, harmless, and absent with a real renderer. Real-renderer screenshots:
  `VK_ICD_FILENAMES=.../lvp_icd.json xvfb-run godot --rendering-method mobile -- --ai-vs-ai --screenshots=DIR`.
- Tests: `GODOT=<path> tools/run_tests.sh`. Input tests live in `tests/input_test.gd` and run via
  `godot --headless -- --run-input-tests` (so autoloads are available). Add a test for new controls.
- Commit messages: short imperative summary line, then details.
