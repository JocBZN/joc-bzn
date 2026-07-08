# JOC-BZN-Mobile 🎮

A mobile **survivors-like** (bullet-heaven) game — think *Vampire Survivors* / *Brotato* with a **cyberpunk** theme. Built in **Godot 4.7** with GDScript, targeting **Android**.

> **AI assistant reading this (hi 👋):** the most important section is **"Working with the project owner"** at the bottom. The owner is a **complete beginner** being taught step by step, in Romanian.

## Game concept
- Top-down arena. The **player** appears centered (a `Camera2D` follows them) but moves freely across a large world.
- **Enemies** spawn continuously from off-screen and chase the player.
- The player **auto-fires** projectiles at the nearest enemy. Enemies have HP and die.
- Enemies touching the player deal **contact damage**; the player has HP + a health bar.
- **Roguelike core (planned):** dead enemies drop **XP** → XP bar fills → **level up** → choose **1 of 3 items/upgrades**. Difficulty ramps over time (enemies faster/tougher, drop more XP).

## Tech & conventions
- **Engine:** Godot 4.7 stable · 2D · "Mobile" renderer. Stretch mode `canvas_items`, aspect `expand` (scales to any phone screen).
- **Language:** GDScript.
- **Indentation: TABS.** Godot rejects mixed tabs/spaces — this is *the* most common error when pasting code. After any paste use **Edit → Convert Indent to Tabs**.
- **Groups** are used to find nodes across the tree: the player is in group `"player"`, enemies in group `"enemy"`. Look up with `get_tree().get_first_node_in_group("player")` and `get_nodes_in_group("enemy")`.
- `get_*_in_group` returns a generic `Node`, so **cast with `as Node2D`** before touching `global_position` (otherwise "cannot infer type" errors). Dynamic property access on such nodes yields harmless **yellow** warnings (yellow = warning/OK, red = error/must fix).

## Project structure
All scenes (`.tscn`) and scripts (`.gd`) live in the project root.

- **`main.tscn`** — the game world (root `Node2D` "Main"):
  - `Ground` (Sprite2D + `ground.gd`) — the infinite repeating grass that follows the player.
  - `World` (Node2D, `y_sort_enabled`) — depth-sorted container holding `Props` (trees), `Rocks` (stones), `Player`, and (added at runtime) the enemies, so they overlap correctly by depth.
  - `Props` (`props.gd`) / `Rocks` (`rocks.gd`) / `DesertStructures` (`desert_structures.gd`) — chunk-based procedural, deterministic spawners (infinite). Rectangle hitboxes with per-side tuning (`hitbox_north/south/east/west`), `sort_anchor`, `min_gap_hitboxes` (min spacing). **Biome rules:** trees avoid the desert *and* its soft gradient; rocks avoid only the hard desert (they may sit on the gradient); desert structures (cactus/house/monument) spawn *only* in the desert — see `BiomeMap.is_desert_chunk` / `desertness_at_chunk` / `desert_inset_chunk`.
  - `Spawner` (Node + `spawner.gd`) — a Timer that instances enemies around the player (into `World`).
  - `HUD` (CanvasLayer + `hud.gd`) — screen-fixed UI: health bar + XP bar + level, all built in code.
  - `LevelUp` (CanvasLayer + `levelup.gd`) — the level-up choice screen (3 random of 15 upgrades), styled like *Megabonk*: an ornate `Menu.png` panel with each choice framed by a **rarity border** (Common→Legendary) + matching colored text; pauses the game.
- **`player.tscn`** (`CharacterBody2D` + `player.gd`) — has an **AnimatedSprite2D** (8-directional run + idle poses, `player_frames.tres`), CollisionShape2D, Camera2D. Handles arrow-key movement, auto-fire at nearest enemy (Timer), HP + a contact-damage tick, the fire trail (Firewalker), and death (opens the Game Over screen).
- **`enemy.tscn`** (`CharacterBody2D` + `enemy.gd`) — chases the player, has HP, `take_damage()`, dies via `queue_free()`.
- **`bullet.tscn`** (`Area2D` + `bullet.gd`) — flies in a direction, on `body_entered` damages bodies in group `"enemy"`, self-destructs after `lifetime`. Supports **pierce**, **knockback**, **crit**, and **explosive AOE** (Jean's Bomb).
- **`firetrail.gd`** (script-only, instanced from `player.gd`) — a fire patch dropped at the player's feet while moving (**Firewalker** upgrade): plays the fire animation, burns enemies in range on a tick, rotates to the movement direction, renders **under** the actors (`z_index`), and fades after a per-stack duration.
- **`statue.tscn`** (`StaticBody2D` + `statue.gd`) — an interactive world statue with a **visually-editable** collision box. When the player is near, a small **"Summon"** button appears. Pressing it plays a one-shot sequence: alert symbol → statue **sinks into the ground** (its collision disables) → **screen shake** (camera-offset earthquake) → a **boss rises slowly from the ground**. All timings/offsets are `@export`.
- **`garda.tscn`** (`CharacterBody2D` + `garda.gd`) — the **"Garda" boss**, spawned *only* by the statue's Summon. Slower and much tankier than a normal enemy, walks toward the player using **8-directional** animations, and **throws lightning balls** from range on a cooldown. Static `garda_0.png` shows while it's rising; the walk animation kicks in once it moves.
- **`lightning.tscn`** (`Area2D` + `lightning.gd`) — the boss's ranged projectile: a violet lightning ball with a **circle hitbox**, flies toward the player, and only damages group `"player"` (`take_damage`). Made extra visible via slow frames + `modulate > 1` (glow).
- **Boss art** lives in `boss/` (walk GIFs split into `walk_<dir>_<i>.png` frames + the lightning-burst frames); the alert symbol in `Upgrades/symbol_alert_002_large_red/`. New GIFs are split to PNG with PowerShell + `System.Drawing`; **open the project in Godot once to import new PNGs** before they render (art is loaded at runtime with `load()`).

**Collision:** everything is on the default layer/mask (layer 1). Bullets (Area2D) detect enemies (CharacterBody2D) via `body_entered` and filter with `is_in_group("enemy")`, so no manual collision-layer setup is needed yet.

## Current state (2026-07-08)
- ✅ **Frostwalker** (Epic) — a **frost trail** at your feet that **slows** enemies (blue tint on them) and does light damage. Per stack: +0.5s slow duration & +0.3s trail; damage stays. Mirror of Firewalker (`icetrail.gd`), art desaturated at load.
- ✅ **Godwalker** — having **Firewalker + Frostwalker** replaces both trails with a single combined one (`godtrail.gd`): fire damage **and** frost slow, its own animation.
- ✅ **Biome-aware world gen refined:** trees no longer spawn on the desert **gradient** (only pure forest); rocks may sit on the gradient; new **desert structures** (`desert_structures.gd`, node `DesertStructures`): **cactus** scattered per-chunk (denser), **house** guaranteed 1–2 **per desert** (kept ≥20px inside, never on the gradient), **monument** ~once per 2 deserts (never on the gradient). Each structure has its own `scale` + hitbox via a `CONFIG` block.
- ✅ Smaller Jean's Bomb explosion animation (new frames + reduced on-screen scale).
- Trail spritesheets are sliced into frames **at runtime** (`AtlasTexture`), so dropping in a new PNG just needs a Godot import.

## Current state (2026-07-07)
- ✅ **Working:** player movement + follow camera · infinite world · procedural **trees + rocks** with collision (rectangle hitboxes, per-side tuning, min spacing) · **Y-sort depth** (props cover you when you walk behind them) · enemy chase AI · automatic spawner · player auto-fire + projectiles that **face the target** · enemy HP + death · player HP + contact damage.
- ✅ **Biomes:** grass + **desert**, generated as random square patches (side 6–20 chunks) via a shared deterministic map (`biome_map.gd` / `BiomeMap`), rendered with a soft-blend shader (`biome.gdshader`). Trees & rocks don't spawn in desert.
- ✅ **HUD** (`hud.gd`, built in code): red health bar (top-left) + cyan XP bar (bottom) + "Nivel N" label.
- ✅ **XP / leveling:** enemies grant XP on death → XP bar fills → **level up pauses the game and shows 3 random of 15 upgrades** (`levelup.gd`), styled like *Megabonk* (ornate panel + **rarity borders** + exact border-matched colors + 2px text outline), with thematic drug/drink effects. All in-game **UI text is in English**.
- ✅ **Signature items:** **Jean's Bomb** (Legendary) — +20 damage & bullets **explode (AOE)** on impact (explosion animation + knocks enemies back). **Firewalker** (Epic) — leaves a **burning fire trail** at your feet while moving that damages enemies; each stack lasts longer & grows +5px.
- ✅ **Interactive statue + boss summon:** a world statue with a **"Summon"** button → sink-into-ground animation + **screen shake** → the **"Garda" boss** rises from the ground (8-directional walk) and **throws lightning-ball projectiles** (circle hitbox, glow) at the player from range.
- ✅ **Sound:** a global audio manager (`audio.gd`, autoload **`Audio`**) with a pooled `Audio.play("name")` API + 6 code-generated retro SFX in `audio/` (shoot, hit, enemy death, XP pickup, level up, player hurt), wired into player/enemy/xp.
- ✅ **Weapon upgrades & juice:** an effects workshop (`fx.gd`, autoload **`Fx`**) — muzzle flash, impact sparks (`CPUParticles2D`), floating damage numbers (crit = big yellow), all code-generated. New weapon stats: **crit** (double damage), **pierce** (bullets pass through enemies), **bullet size**, **knockback** (pushes enemies back). Four new level-up choices (Foraj/Adrenalină/Doză dublă/Croșeu) drive them; works on all 3 bullets. **Screen shake** on crit (trauma-based camera shake in `player.gd`).
- ✅ **Waves + background music:** the `Spawner` is now a **wave manager** — each wave spawns normal enemies for a while, then a **boss** (`garda.tscn`); killing it starts the next, harder wave. On-screen banners announce "VALUL N" / "BOSS!" / "VALUL N TERMINAT" (`hud.announce`). Difficulty now scales by **wave** (`Difficulty.wave`), not time. Looping **background music** (`audio/music.wav`, code-generated) via `Audio.play_music()`.
- ⬜ **Next:** cyberpunk art polish · on-screen touch joystick · Android export.

## How to run
Open the project in **Godot 4.7**, press **Run Project** (▶ / F5). Main scene is `main.tscn`. Move with the **arrow keys**; the player auto-fires. Touch controls come in a later milestone — for now, test on desktop.

## Working with the project owner ⭐ (READ THIS)
The owner (**Răzvan**) is a **complete beginner** — first game ever, first time in Godot, learning by building this project one step at a time. If you're an AI assistant helping:

- **Reply in Romanian.**
- **Teach, don't just do.** Introduce each new concept simply (analogies help) before/while using it. Move **one small, testable step at a time** — every step should end with "press Run and see X".
- **Avoid copy-paste pain.** They've hit repeated *"mixed tabs and spaces"* errors and once pasted code into the wrong file. Prefer **writing `.gd` files directly** (with correct tab indentation) and letting them do only the editor/node parts. Always remind them: after any paste, **Edit → Convert Indent to Tabs**.
- **If code ends up misbehaving, check filenames first** — each script belongs to its node (`player.gd` → Player, `bullet.gd` → Bullet, etc.).
- **Be concrete about the Godot UI:** exact panels, buttons, and node names. They don't know the interface from memory yet.
- **Node names are load-bearing:** scripts reference children by exact name (e.g. `hud.gd` needs a child `ProgressBar` named `HealthBar`).

**Roadmap (survivors-like):** 1) movable player ✅ · 2) chasing enemy ✅ · 3) spawner ✅ · 4) auto-attack + enemy death ✅ · 5) HP + health bar ✅ · 6) XP + level up + item choice ✅ · 7) difficulty scaling ⬜ · 8) cyberpunk art/sound ⬜ · 9) Android export + touch controls ⬜.
