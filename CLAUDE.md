# Context for AI assistants

**Read `README.md` first** — it has the full project overview, architecture, current state, and (most importantly) **how to work with the project owner**, who is a complete beginner learning Godot.

Quick rules:
- **Reply in Romanian.** The owner is a beginner; teach in small, testable steps and be concrete about the Godot UI.
- **Godot 4.7 + GDScript.** Indentation is **TABS** — never mix tabs/spaces (Godot errors out). When code is involved, prefer writing `.gd` files directly to avoid copy-paste/tab problems.
- **Node lookups use groups:** `"player"` and `"enemy"` (via `get_tree().get_first_node_in_group(...)` / `get_nodes_in_group(...)`); cast results with `as Node2D` before using `global_position`.
- This is a **survivors-like / bullet-heaven** game (Vampire Survivors style), cyberpunk theme, for Android. See the roadmap in `README.md`.

---

## Session log — 2026-07-07 (biome desert random + props/rocks hitbox + bullets spre inamic + lumină normală)

**Done:**
- **Revenit la copacii ORIGINALI** (`harta/trees/spr_tree_*`): pachetul „fancy" de copaci (folderul `trees/`) și pachetul vechi de pietre (`stones/PNG/...`) au fost **șterse**. `props.gd` restaurat din git la sistemul `spr_tree` cu hitbox dreptunghiular reglabil.
- **Hitbox copaci pe 4 laturi:** pe lângă `hitbox_south`/`hitbox_west` am adăugat `hitbox_north`/`hitbox_east` — fiecare mișcă DOAR marginea ei (pozitiv extinde, negativ trage înăuntru). `sort_anchor` (0.35) re-aplicat la toți copacii.
- **Densitate + distanță copaci:** `trees_per_chunk` 2→1. Nou `min_gap_hitboxes` (=2) = distanța minimă între copaci, în „hitbox-uri". Se verifică și copacii din cele 8 chunk-uri vecine, determinist (`_chunk_trees_raw` recalculează pozițiile brute din seed, cu departajare stabilă pe cheia chunk-ului) → fără „clipiri" la revenire.
- **Pietre ca props de mediu** (`rocks.gd` nou + nod `Rocks` sub `World` în `main.tscn`): copie a sistemului de copaci, INDEPENDENT — hitbox dreptunghi cu N/S/E/V, `rocks_per_chunk`, `min_gap_hitboxes`, `sort_anchor`. Încarcă imaginile la RULARE din `stones/` (nu `preload`, ca să nu crape la PNG neimportat). `SEED_SALT` diferit → pietrele nu urmează tiparul copacilor.
- **Gloanțele se întorc spre inamic:** sprite-ul e desenat spre NORD; `bullet.gd` are acum `set_direction()` care setează direcția ȘI `rotation = dir.angle() + PI/2`. `player.gd _fire()` îl folosește. Merge pentru toate cele 3 gloanțe (același `bullet.gd`).
- **Biom deșert RANDOM** (`biome_map.gd` nou, `class_name BiomeMap`): lumea e împărțită în macro-celule de 20×20 chunk-uri; fiecare poate avea UN petic de deșert pătrat cu latura RANDOM 6..20 chunk-uri, plasat aleator (hash pe 32 de biți, determinist). În deșert NU se generează copaci/pietre (`props.gd`/`rocks.gd` cheamă `BiomeMap.is_desert_chunk`). `biome.gdshader` rescris să deseneze peticele cu margini soft (smootherstep).
- **Un singur loc de reglat biomul:** parametrii (`MACRO`, `MIN_SIZE`, `MAX_SIZE`, `DESERT_PERCENT`) sunt trimiși din `biome_map.gd` către shader ca uniforme (prin `ground.gd`). Editezi doar `biome_map.gd`.
- **Lumină normală** (`atmosphere.gd`): comentat `_setup_night()` (CanvasModulate) + `_setup_light()` (PointLight2D de pe player). Rămân vignette + glow.

**Gotchas:**
- **Matematica biomului trebuie IDENTICĂ** între `biome_map.gd` și `biome.gdshader` (hash + extragere mărime/poziție). GDScript folosește aritmetică mascată pe 32 de biți (`& 0xFFFFFFFF`) ca să dea EXACT ca `uint`-ul din GLSL. Verificat că laturile peticelor cad în 6..20.
- **Textura de deșert = `harta/desert-tile.png`** (cu CRATIMĂ). Numele din `load()` trebuie să fie identic; când era `desert_tile.png` (underscore) încărcarea pica → `ground.gd` ieșea fără să aplice shaderul → doar iarbă (deșertul „dispărea").
- Icoanele de upgrade (`Upgrades/upgrade_*.png`) se încarcă cu `load()` la rulare → poți înlocui un PNG cu același nume fără să schimbi codul (doar reimport în Godot).

---

## Session log — 2026-07-06 (Răzvan + assistant: XP drops, difficulty, thematic items, Game Over, atmosphere)

**Done:**
- **XP now drops on the ground** as animated pickups: `xp.gd` + `xp1.tscn` (value 1) / `xp2.tscn` (value 10 = 10× XP1; rare, 5% chance at higher difficulty). Art in `xp/`. Gems pulse+bob, have a **magnet** toward the player, and a collect "pop". Enemies no longer grant XP instantly — `enemy.gd _drop_xp()` instantiates a gem (value = base × `Difficulty.xp_mult()`).
- **Difficulty scaling** via new autoload **`Difficulty`** (`difficulty.gd`, registered in `project.godot [autoload]`). Time-based `stage()` every 30s → multipliers for enemy HP/speed, spawn rate, XP. `xp_mult()` is doubled (+100% XP, per request). `spawner.gd` resets `Difficulty.time` on `_ready` and shortens the spawn interval over time.
- **Thematic upgrades** (`levelup.gd`): 9 distinct, substance-themed effects (Cocaină, Iarbă, Seringă, Bere, Vodcă, Stroh, Foițe OCB, Grinder, Bere doză). Each button now shows **name + stat text under the icon**. Two switch the bullet: **Cocaină→`bullet2.tscn`**, **Stroh→`bullet3.tscn`**.
- **Player** (`player.gd`): added `bullet_speed`, `hp_regen` (+ 1s regen timer); `BULLET` const → **`bullet_scene` var** so upgrades can swap the projectile; `die()` now opens the Game Over screen; `dead` guard.
- **Bullets**: `bullet1.png` is the default (`bullet.tscn`); new `bullet2.tscn`/`bullet3.tscn`. Art in `bullets/`.
- **Enemy juice** (`enemy.gd`): white hit-flash on damage, "pop" (scale+fade) death, `remove_from_group("enemy")` on death.
- **Game Over screen** (`gameover.gd`, `Gameover` CanvasLayer in `main.tscn`): pauses, shows survival time (`Difficulty.time`) + level + "JOACĂ DIN NOU" restart.
- **Atmosphere pass** (`atmosphere.gd`, `Atmosphere` Node in `main.tscn`): CanvasModulate night tint + a PointLight2D that follows the player + vignette (CanvasLayer + radial GradientTexture2D) + WorldEnvironment glow. Tunables are `@export` (edit on the Atmosphere node in the Inspector).

**Gotchas:**
- New UI/logic scripts must be **attached to a node in `main.tscn`** — repeatedly a node was added but the script not attached (HUD/GameOver/Atmosphere) → nothing ran and "no difference" in-game. When this happens, wire the script directly in `main.tscn`.
- Autoload changes to `project.godot` need a **project reload** (Project → Quit to Project List → reopen), else "Identifier Difficulty not declared".
- Hand-written `.tscn` files reference textures/scripts by uid (pulled from the `.import` / `.uid` files).

**Next ideas:** Android export + on-screen touch joystick; sound/music; glowing bullets & XP (per-object lights); cyberpunk ground/prop art; meta-progression between runs.

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
