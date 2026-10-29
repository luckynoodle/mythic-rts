# Art guide: 3D models

Mythic RTS uses a **stylised / heroic** look in the spirit of Warcraft III. Characters are
about **5 heads tall**, with big shoulders, hands and weapons and bold, readable silhouettes.

Every unit, building, resource and projectile currently uses a **placeholder** built in code
(`scripts/view3d/placeholder_models.gd`). **To upgrade any of them, drop in a model file.**
No code changes are needed.

## 1. Where files go

The game looks for a model in this order and uses the first one it finds:

1. The `"model"` path in the faction JSON, for example
   `"footman": { ..., "model": "res://art/humans/footman_v2.glb" }`
2. The conventional path `res://art/<faction>/<id>.glb`. `.gltf`, `.tscn` and `.scn` also work.
3. The code-built placeholder.

So `art/humans/footman.glb` automatically replaces the placeholder footman.

| Thing | Conventional path |
|---|---|
| Unit | `art/<faction>/<unit_id>.glb`, e.g. `art/orcs/grunt.glb` |
| Building | `art/<faction>/<building_id>.glb`, e.g. `art/humans/town_hall.glb` |
| Resource | `art/resources/<type>.glb`, with optional variants `<type>_0.glb` … `<type>_3.glb` (e.g. several tree shapes) |
| Projectile | `art/projectiles/<kind>.glb`: `arrow`, `axe`, `bolt`, `boulder`, or any name set as `projectile_visual` in the JSON |

## 2. Model conventions

| Convention | Rule |
|---|---|
| **Units** | **1 unit = 1 metre.** A footman is about 2.2 m tall. Ogres and knights are bigger. |
| **Origin** | Units: between the feet, on the ground. Buildings and resources: the centre of the footprint, on the ground. |
| **Facing** | **+Z forward.** This is the glTF standard; Blender's default export does this. |
| **Up** | +Y |
| **Building size** | The footprint should match the building's `"size"` in the JSON, divided by 16. A town hall of `[128, 96]` is 8 m × 6 m. |
| **Height (optional)** | Set `"model_height"` in the JSON if your model is taller or shorter than the default. Health bars and tap targets use it. |
| **Scale / rotation fixes** | `"model_scale": 1.2` and `"model_rotation_y": 180` in the JSON, if an imported model needs adjusting. |

### Team colour
Any material whose name contains **`team`** (e.g. `Team`, `TeamColor`, `banner_team`)
is recoloured to the owner's colour at runtime:
- **StandardMaterial3D**: `albedo_color` is replaced. Paint those parts white or light grey in the texture, so the tint comes through.
- **ShaderMaterial**: the game sets a `team_color` uniform.

Use it on tabards, banners, shields, roofs and pauldrons, as the placeholders do.

### Animations
If the model contains an **AnimationPlayer**, the game plays these clips. Names are matched
loosely and case-insensitively, so `Walk`, `walk_loop` and `Run` all work:

| State | Recognised names |
|---|---|
| idle | `idle`, `stand` |
| walk | `walk`, `run`, `move` |
| attack | `attack`, `slash`, `shoot`, `punch`, `throw`, `sword` |
| work (gather / build) | `work`, `gather`, `chop`, `mine`, `build`, `interact`, `hammer` |
| die | `die`, `death`, `dead` |

- Idle, walk and work are looped automatically.
- The attack clip plays once per hit.
- Missing clips fall back sensibly: work falls back to attack, then to idle.
- **Models without an AnimationPlayer** still move: they get procedural bob, lunge and chop motion.

Humanoid animations can be shared between models with Godot's retargeting
(Import dock → Skeleton → BoneMap with the `SkeletonProfileHumanoid`).

### Attachment points
Add an empty node or a `BoneAttachment3D` with one of these names:

| Name | Used for |
|---|---|
| `carry` | Where carried gold, wood or stone appears on workers. If it's missing, the item shows at the unit's back. |
| `hand_r`, `hand_l`, `head` | Reserved for weapon swaps and effects (the placeholders already have them). |

## 3. Budget for mobile

The game should hold 60 fps on older iPhones in a 100-unit battle:

| Asset | Target |
|---|---|
| Unit | 1,500–4,000 triangles, 1 material plus the team material, one 512–1024 px texture |
| Building | 3,000–10,000 triangles, one 1024–2048 px texture |
| Tree / rock | 300–1,500 triangles; provide 3–4 variants |
| Bones | ≤ 40 per character |

- Prefer **one texture atlas per faction**.
- Bake ambient occlusion into textures, and avoid transparency where possible.

## 4. Checking your model

1. Drop the file in `art/<faction>/` and open the project in Godot. It imports automatically.
2. Run the game. The unit uses your model the next time it appears.
3. Run the tests: `GODOT=<path> tools/run_tests.sh`.
4. For review screenshots of a live AI-vs-AI match (base, enemy base, battle, close-up), run
   `godot -- --ai-vs-ai --screenshots=/some/folder`.

## 5. Where to get models

- **Free (CC0):** Quaternius and Kenney publish low-poly fantasy packs, some with animated characters.
  Check each pack's licence before shipping.
- **Commissioned:** give the artist this guide. The conventions above are all they need.
- **DIY:** model in Blender and export glTF 2.0 (`.glb`) with +Y up. Blender's defaults are fine.
