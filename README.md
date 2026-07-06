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
  - `World` (Node2D, `y_sort_enabled`) — depth-sorted container holding `Props` (trees), `Player`, and (added at runtime) the enemies, so they overlap correctly by depth.
  - `Spawner` (Node + `spawner.gd`) — a Timer that instances enemies around the player (into `World`).
  - `HUD` (CanvasLayer + `hud.gd`) — screen-fixed UI: health bar + XP bar + level, all built in code.
  - `LevelUp` (CanvasLayer + `levelup.gd`) — the level-up choice screen (3-of-9 icon upgrades); pauses the game.
- **`player.tscn`** (`CharacterBody2D` + `player.gd`) — has Sprite2D, CollisionShape2D, Camera2D. Handles arrow-key movement, auto-fire at nearest enemy (Timer), HP + a contact-damage tick, and death (currently `reload_current_scene()`).
- **`enemy.tscn`** (`CharacterBody2D` + `enemy.gd`) — chases the player, has HP, `take_damage()`, dies via `queue_free()`.
- **`bullet.tscn`** (`Area2D` + `bullet.gd`) — flies in a direction, on `body_entered` damages bodies in group `"enemy"`, self-destructs after `lifetime`.

**Collision:** everything is on the default layer/mask (layer 1). Bullets (Area2D) detect enemies (CharacterBody2D) via `body_entered` and filter with `is_in_group("enemy")`, so no manual collision-layer setup is needed yet.

## Current state (2026-07-06)
- ✅ **Working:** player movement + follow camera · infinite grass world · procedural trees with collision · **Y-sort depth** (trees cover you when you walk behind them) · enemy chase AI · automatic spawner · player auto-fire + projectiles · enemy HP + death · player HP + contact damage.
- ✅ **HUD** (`hud.gd`, built in code): red health bar (top-left) + cyan XP bar (bottom) + "Nivel N" label.
- ✅ **XP / leveling:** enemies grant XP on death → XP bar fills → **level up pauses the game and shows a 3-of-9 upgrade choice** as icon buttons (`levelup.gd`). Upgrade *effects* are placeholders for now (to be themed to the drug/drink icons).
- ⬜ **Next:** theme the upgrade effects · time-based difficulty scaling · cyberpunk art & sound · on-screen touch joystick · Android export · a proper **Game Over** screen (death currently just reloads).

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
