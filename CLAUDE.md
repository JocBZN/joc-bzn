# Context for AI assistants

**Read `README.md` first** — it has the full project overview, architecture, current state, and (most importantly) **how to work with the project owner**, who is a complete beginner learning Godot.

Quick rules:
- **Reply in Romanian.** The owner is a beginner; teach in small, testable steps and be concrete about the Godot UI.
- **Godot 4.7 + GDScript.** Indentation is **TABS** — never mix tabs/spaces (Godot errors out). When code is involved, prefer writing `.gd` files directly to avoid copy-paste/tab problems.
- **Node lookups use groups:** `"player"` and `"enemy"` (via `get_tree().get_first_node_in_group(...)` / `get_nodes_in_group(...)`); cast results with `as Node2D` before using `global_position`.
- This is a **survivors-like / bullet-heaven** game (Vampire Survivors style), cyberpunk theme, for Android. See the roadmap in `README.md`.

---

## Session log — 2026-07-06 (Y-sort depth + hitbox tuning + XP system)

**Done today:**
- **Y-sort depth ("3D" behind trees):** new `World` `Node2D` (`y_sort_enabled=true`) in `main.tscn` now holds `Props` (trees), `Player`, and — via the spawner — the enemies. Each tree's chunk container also has `y_sort_enabled`. Things lower on screen draw in front, so trees cover the player/enemies when they walk behind them. Enemies are now added into `World` (spawner uses `player.get_parent()`), not into `Spawner`, so they join the sort.
- **Tree sort line at 35%:** `props.gd` raises each tree's Y-sort origin to `sort_anchor` (0.35) of its height above the base (via `sprite.offset`), and compensates the node position so the tree stays visually planted. Fixes the bug where the player got covered / head-clipped at the very bottom of a tree.
- **Tree hitbox is now a `RectangleShape2D`** (was a circle). A non-uniform *scaled* circle becomes an ellipse that GodotPhysics2D mishandles → the player got **teleported** at the north/south extremes. Rectangle gives reliable, independent width/height. Tunables on `Props` (Inspector): `hitbox_factor` (width), `hitbox_vertical` (height vs width), `hitbox_south` (moves ONLY the bottom edge), `hitbox_west` (moves ONLY the left edge), `sort_anchor`.
- **XP system (roadmap steps 5–6), all built in code:**
  - `player.gd`: `xp` / `level` / `xp_to_next` (export, 20) + `gain_xp()` (uses a `while`, so a big XP gain can level up multiple times). `_level_up()` grows the threshold ×1.2 and opens the level-up menu. New `bullet_damage` stat is copied onto each bullet in `_fire()`. `fire_timer` is now a member var; `upgrade_max_hp()` / `upgrade_fire_rate()` are called by upgrades.
  - `enemy.gd`: `xp_value` (export, 5) → grants XP to the player on death.
  - `hud.gd`: rebuilt fully in code (no scene UI) — red **HealthBar** (top-left), cyan **XPBar** (bottom, full width), "Nivel N" label. `HUD` `CanvasLayer` added to `main.tscn`. Reads the player via group.
  - `levelup.gd`: new `LevelUp` `CanvasLayer` (`PROCESS_MODE_ALWAYS`, so it works while `get_tree().paused = true`). On level up it shows **3 random of 9** upgrades as **icon buttons**; `_pending` queues extra choices if you gain several levels at once. Effects in `_apply()` are **placeholders** (to be themed later).
- **Upgrade icons:** a 3×3 sprite sheet in `Upgrades/` was sliced into `Upgrades/upgrade_1.png … upgrade_9.png` (drug/drink themed: cocaine, weed, syringes, beer, vodka, whiskey, OCB papers, grinder, energy drink). Icons are loaded at runtime with `load()`.
- **Git:** the default branch is now **`main`** (renamed from `master`, force-pushed; `master` deleted).

**Notes / gotchas:**
- The **PowerShell *tool* is unavailable** in this environment; call `powershell.exe` from the **Bash** tool instead (used `System.Drawing` to slice the sheet). `python`/ImageMagick/ffmpeg aren't usable (`convert` on PATH is the Windows one, not ImageMagick).
- New PNGs must be **imported by opening Godot** before they render; `levelup.gd` uses `load()` (runtime), so a missing import just shows no icon rather than crashing.
- **Two copies of the project existed** (`Documents\joc-bzn-main` = old, no git; `Downloads\joc-bzn-main` = the real git repo). The old one was renamed `joc-bzn-VECHI-nu-folosi`. Always work in **`Downloads\joc-bzn-main`**.

**Where we left off / next ideas:**
- Theme the 9 upgrade effects to fit the drug/drink icons (and allow some to stack/repeat).
- Polish the level-up UI (panel background, hover, bigger icons, short descriptions).
- Upgrade icons still have a faint non-transparent background; could be cleaned.
- Still pending: time-based difficulty scaling, cyberpunk art/sound, Android export + on-screen touch joystick, a real Game Over screen.

---

## Session log — 2026-07-05 (visual + world pass)

**Done today:**
- **Player art:** now an `AnimatedSprite2D` (was a static `Sprite2D`). Running animations for 4 directions + `idle_*` frames for standing. Frames are in `grasu directii/running/frames/` (running) and `grasu directii/rotations/` (idle poses). Animations resource: `player_frames.tres`. Logic in `player.gd`: picks direction by movement angle (4 quadrants), plays `idle_<dir>` when standing.
- **Enemy art:** now an `AnimatedSprite2D` too. Running animations for 7 directions from `homeless directii/running homeless/frames/` (`run_<dir>_*`). Animations resource: `enemy_frames.tres`. Enemy always faces the player (8-octant angle → animation). **North running GIF is missing** → the `north` animation falls back to the static pose `homeless directii/homeless directii pe loc/frames/enemy_north.png`. Static per-direction poses (`enemy_<dir>.png`) exist in that "pe loc" folder.
- **Infinite world:** grass ground via `ground.gd` on the `Ground` `Sprite2D` in `main.tscn` — a repeating (`texture_repeat`) tile (`harta/grass-alternative-3.png`, 64px) that follows the player snapped to 64px → looks infinite. The old neon `Grid` node + `grid.gd` were **removed**.
- **Camera:** the player's `Camera2D` is now `enabled`, `zoom = 0.7`, position smoothing on → locked on player, follows it.
- **Props (trees):** `props.gd` on the `Props` `Node2D` in `main.tscn` = **chunk-based procedural, deterministic** tree spawner (infinite; `hash(chunk)` seeds RNG so a spot always has the same trees; far chunks unload). Trees are 16 sprites in `harta/trees/spr_tree_*.png` (64px). Each tree is a `StaticBody2D` (default layer 1) with a big circle hitbox → blocks player AND enemies. Tunables (Inspector on `Props`): `tree_scale` (4.5), `trees_per_chunk` (2), `hitbox_factor` (0.35), `chunk_size`, `load_radius`.

**Where we left off / next ideas:**
- More prop variety so it's not just trees on grass (rocks, bushes, cyberpunk crates/barrels) — same `props.gd` chunk system can host them.
- **Y-sort** for nicer layering (player currently always drawn in front of trees).
- Get a **north running** GIF for the enemy to replace the static fallback.
- Possible polish: bullets fly over trees (Area2D doesn't stop); enemies can bump/stack on tree hitboxes.
- Still pending from `README.md` roadmap: **HUD health bar** (🚧), then XP → level up → item choice, difficulty scaling, Android + touch controls.
- **Sprite-splitting trick used:** GIFs → PNG frames via PowerShell + .NET `System.Drawing` (no ImageMagick/ffmpeg/Python available on this machine). New textures must be imported by opening Godot before scripts that `preload` them will run.
