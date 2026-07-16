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
  - `LevelUp` (CanvasLayer + `levelup.gd`) — the level-up choice screen (3 random of **23** upgrades), styled like *Megabonk*: an ornate `Menu.png` panel with each choice framed by a **rarity border** (Common→Legendary) + matching colored text; pauses the game. Each entry is one dict in `UPGRADES` (id / name / icon / rarity / description) and its real effect is a `match` arm in `_apply()` — **the description text is not the source of truth, `_apply()` is.**
- **`player.tscn`** (`CharacterBody2D` + `player.gd`) — has an **AnimatedSprite2D** (8-directional run + idle poses, `player_frames.tres`), CollisionShape2D, Camera2D. Handles arrow-key movement, auto-fire at nearest enemy (Timer), HP + a contact-damage tick, the fire trail (Firewalker), and death (opens the Game Over screen).
- **`enemy.tscn`** (`CharacterBody2D` + `enemy.gd`) — chases the player, has HP, `take_damage()`, dies via `queue_free()`.
- **`bullet.tscn`** (`Area2D` + `bullet.gd`) — flies in a direction, on `body_entered` damages bodies in group `"enemy"`, self-destructs after `lifetime`. Supports **pierce**, **knockback**, **crit**, and **explosive AOE** (Jean's Bomb).
- **`firetrail.gd`** (script-only, instanced from `player.gd`) — a fire patch dropped at the player's feet while moving (**Firewalker** upgrade): plays the fire animation, burns enemies in range on a tick, rotates to the movement direction, renders **under** the actors (`z_index`), and fades after a per-stack duration.
- **`statue.tscn`** (`StaticBody2D` + `statue.gd`) — an interactive world statue with a **visually-editable** collision box. When the player is near, a small **"Summon"** button appears. Pressing it plays a one-shot sequence: alert symbol → statue **sinks into the ground** (its collision disables) → **screen shake** (camera-offset earthquake) → a **boss rises slowly from the ground**. All timings/offsets are `@export`.
- **`garda.tscn`** (`CharacterBody2D` + `garda.gd`) — the **"Garda" boss**, spawned *only* by the statue's Summon. Slower and much tankier than a normal enemy, walks toward the player using **8-directional** animations, and **throws lightning balls** from range on a cooldown. Static `garda_0.png` shows while it's rising; the walk animation kicks in once it moves.
- **`lightning.tscn`** (`Area2D` + `lightning.gd`) — the boss's ranged projectile: a violet lightning ball with a **circle hitbox**, flies toward the player, and only damages group `"player"` (`take_damage`). Made extra visible via slow frames + `modulate > 1` (glow).
- **Boss art** lives in `boss/` (walk GIFs split into `walk_<dir>_<i>.png` frames + the lightning-burst frames); the alert symbol in `Upgrades/symbol_alert_002_large_red/`. New GIFs are split to PNG with PowerShell + `System.Drawing`; **open the project in Godot once to import new PNGs** before they render (art is loaded at runtime with `load()`).

## Weapons
Picked in the main menu (`GameSettings.weapon_type`, read by `player.gd` on `_ready`). All four share the **same base stats** (`bullet_damage` 10, `fire_interval` 0.5, `bullet_speed` 700) — `weapon_type` only changes *behaviour*, in four places in `player.gd`:

| Weapon | How it fires |
|---|---|
| **Pistol** | One bullet at the nearest enemy. Nothing else. |
| **Mage Staff** | The same bullet, re-skinned as an animated orb, that **explodes on impact** (radius 110, damage = 60% of `bullet_damage`). |
| **Extinguisher** | No bullets at all — an **aura** pulses around you every `fire_interval`, hitting *every* enemy within `aura_base_radius + level × aura_growth`, for `aura_damage + 50% of bullet_damage` (15 at start). |
| **Cursed Sword** | No bullets — a **melee slash** in the direction you're **facing** (`_facing`), hitting *every* enemy inside a fixed rectangle that runs from the player out to the animation's furthest pixel, for `sword_base_damage + bullet_damage`. Built on the **Firewalker model**: `sword_size` is the width in px, and the rectangle is *measured from the art* at startup, so art and hitbox cannot drift apart. Starts **slow** (`fire_interval × sword_slow_start` when picked) and speeds up with attack-speed upgrades. The slash animation is a **child of the player**, so it follows you (feels like the sword is always in hand), and draws **under** him. Scales with damage / crit / knockback / instakill / weapon-size upgrades. |

**Collision:** everything is on the default layer/mask (layer 1). Bullets (Area2D) detect enemies (CharacterBody2D) via `body_entered` and filter with `is_in_group("enemy")`, so no manual collision-layer setup is needed yet.

## Current state (2026-07-16)
- ✅ **The slash tracks your facing while it swings (Megabonk-style).** It used to freeze its direction at spawn — start a slash facing west, turn east, and it stayed pointing west. `_update_slashes()` (from `_process`) now rewrites its position/rotation/scale every frame from the *current* facing. The **damage follows too**: the slash stays live for the animation, re-testing its disc each frame, so you can't swing at someone and have the hit land where you used to be looking. Each enemy is hit **once per slash** (tracked by instance ID, since enemies can die mid-swing) — the next slash can hit them again. Small deliberate buff: enemies that *walk into* the slash while it sweeps now get hit too.
- ✅ **Cursed Sword rebuilt on the Firewalker model** (`firetrail.gd`), with new art. Three things copied from it, and they fix the whole saga below:
  - **Size in pixels, not a multiplier** — `sword_size` (160) is the slash's width on screen; the sprite scale is derived (`sword_size / 64`), exactly like Firewalker's `size / 32.0`. Swap the art, the size stays.
  - **Hitbox derived from the art, not hand-tuned** — the envelope is measured at startup and the rectangle is cut from it, in art pixels, so it follows any size you set. Same spirit as Firewalker's `radius = size * 0.4`. **The art and the hitbox can no longer drift apart** — that was the bug that started all of this.
  - **Frames face west** — `rotation = dir.angle() - PI`, same convention as Firewalker's trail.
  - Art: `cursed sword fx.png` (768×55) → **12 frames of 64×55**. The frame width was found by detecting the drawing blocks per column and picking the only exact division of 768 where no drawing straddles a boundary. The new art is nearly symmetric (sweep centre −1.1° at `sword_lateral` 0, vs the old art's −13.8°).
  - Knobs: `sword_size`, `sword_reach`, `sword_lateral`, `sword_art_rotation`, `sword_anim_speed`, `sword_debug`. Set **`sword_debug = true`** to draw the hitbox live over the game — red rectangle = what hits, blue cross = where the art sits.
- ✅ **The slash looks identical in all 8 directions, just rotated**, and draws **under the player** (`z_index` −1 — slashing north used to paint the arc over his head). Every offset lives in **art space** and is rotated by your facing, through a single `_sword_offset(dir)`. Do **not** add un-rotated "screen" offsets: one was tried and it is exactly what breaks direction consistency (it drags the slash toward you at east but pushes it ahead at west).
- ✅ **Hitbox is a fixed rectangle cut from the animation's envelope.** In art space (x = forward, y = sideways), rotated by your facing: it starts at **0** (the player, so the gap between him and the crescent still deals damage), ends **forward at the animation's furthest pixel** (92 px), and **sideways at its furthest pixels** (−63…+67). It never changes during the sweep. The envelope is *measured at startup* from the frames' opaque pixels (`_masoara_arta_sabiei`), not hardcoded — swap the art and it recomputes; being in art pixels, it follows `sword_size`/`sword_reach`/`sword_lateral` automatically.
- ✅ **The hitbox is measured from the art, not guessed.** It originally hit at 135 px in a ±81° cone while the art only reached 107 px within ±62° — roughly **3× the visible area**, killing enemies past your shoulders. Shapes tried since, and why each was dropped: cone (the art wraps around the player at close reach, so fitting a forward cone yields ±180°) → disc (covers the hollow between the crescent's horns) → pixel-perfect 1:1 (exact, but left the gap between player and slash undamaged) → **rectangle**. Areas: disc 17,765 px², rectangle **11,960 px²**, 1:1 only 5,131 px².
- ⚠️ **Balance follow-up:** the honest hitbox covers far less than the broken one did, so the sword hits noticeably less than it originally felt. Not compensated yet — knobs are `sword_base_damage`, `sword_size` (the hitbox follows it automatically) and `sword_slow_start`.
- ✅ **New weapon — Cursed Sword** (4th selectable weapon in the menu). Auto-**slashes in the facing direction** every `fire_interval`. Base swing is intentionally **slow** (`sword_slow_start` = 1.9× interval when picked) so attack-speed upgrades feel impactful; scales with the player's damage / crit / knockback / instakill / weapon-size upgrades (modelled on the Extinguisher aura + bullet instakill).
- ✅ **Slash animation attached to the player.** The slash `AnimatedSprite2D` is a **child of the Player node** (not left behind in the world), so it moves with you — the vibe is that the sword is always in hand. Its position/scale divide by the player's `scale` (×2 in `main.tscn`) to stay in real pixels.
- ✅ **Upgrade tweaks** (`levelup.gd`): **Rabbit's Foot** now −5 damage · **+25%** attack speed (was +10%); **Grinder** rarity Rare → **Common**; **The Nightclub** rarity Epic → **Rare**; **Syringe → Knight's Power** (new icon `upgrade_26.png`).

## Current state (2026-07-15)
- ✅ **New bullet art + orientation system.** The Pistol's default bullet now uses `bullets/bullet normal.png`. The source art points **north-east**, so its `Sprite2D` child carries a `-45°` rotation that makes the composite point "north" — the existing `set_direction()` (`+PI/2`) then aims it correctly in **all** directions. Same treatment for the new combined bullet.
- ✅ **Weird Concoction + Stroh synergy (combined bullet).** Taken **alone**, each keeps only its stat bonus and leaves the bullet **normal** (they no longer swap to `bullet2/bullet3`). Taken **together**, the Pistol fires a special **`bullet_combined.tscn`** (purple) — a hidden synergy like Godwalker. Tracked via `has_weird` / `has_stroh` on `player.gd`.
- ✅ **Instakill mechanic + 5 new upgrades.** Bullets can now roll an **instant kill** (`instakill_chance` on `player.gd`, passed to `bullet.gd`; shows a red number). New items: **The Nightclub** (Epic, +35% damage · −35% attack speed), **Rusty Hacksaw** (Uncommon, 1% instakill, +0.5%/stack), **Doctor's Hacksaw** (Legendary, 5% instakill, +2%/stack), **Rabbit's Foot** (Uncommon, −5 damage · +10% attack speed), **Mike's Hedgehog** (Epic, reflect 100% of contact damage back, once every 3s). Pool is now **23 upgrades**.
- ✅ **Extinguisher foam animation reworked.** A 14-frame spritesheet (`stingator/stingator.png`) is sliced to `frame_0..13.png` and wired into the aura's foam animation. A single knob **`foam_scale`** (`@export`) now sizes it, and the **hitbox equals the sprite always** — both derive from the same `radius`, so what you see is exactly what damages enemies.
- ✅ **Weapon-size upgrades now scale the trails.** Pufferfish & Rat's Burger multiply `weapon_size_scale()` into **Firewalker / Frostwalker / Godwalker** patch sizes (visual **and** damage radius), on top of Pistol/Mage/Extinguisher.
- ✅ **Upgrade rebalance & reskins:** **Papers → Rolling Papers** (now +10% attack speed instead of bullet speed → also speeds up the Extinguisher pulse); **Pufferfish** +30 → **+10** weapon size; **Syringe** +12 → **+7** damage; **Adrenaline** now also crits on the **Extinguisher** aura; **Parallel Bullets → Twin Comets** (+1 Projectile, `upgrade_19`); **Knockback Stick** new icon (`upgrade_22`). The Mage orb also got a **purple tint** (`modulate`) to match its impact explosion.
- ✅ **Fewer dead Extinguisher upgrades.** Only **Twin Comets** and **Drill** do nothing for it now; Rolling Papers (attack speed) and Adrenaline (aura crit) both work.

## Current state (2026-07-14)
- ✅ **Weapon size is now a real stat** (`weapon_size_px` + `weapon_size_mult` on `player.gd`). It grows **sprite *and* hitbox** for whichever weapon you picked: Pistol/Mage → the bullet (and the mage orb, which is a child of it); Extinguisher → the aura radius (which is both the drawn ring *and* the damage zone). Two new upgrades drive it: **Pufferfish** (Common, +30px) and **Rat's Burger** (Rare, +30%). Pool is now **18 upgrades**.
- ✅ **Mage Staff visuals fixed.** The magic orb was being drawn ~4px wide and was effectively invisible: it's a child of the bullet, whose root is `scale = 0.1` in `bullet.tscn`, so its own scale got multiplied by that. `_make_mage_orb` now divides by the parent's scale, so `mage_orb_size` (35) means *actual pixels on screen*. The impact explosion is tuned via `BOOM_VISUAL_SCALE` in `bullet.gd` (visual only — the AOE damage radius is untouched).
- ✅ **Extinguisher base damage raised to 15/pulse** (`aura_damage` 6→10; total is `aura_damage + 50% of bullet_damage`, so it still scales with damage upgrades).
- ✅ **Upgrade renames + new icons:** Cocaine→**Weird Concoction**, Weed→**Wine**, Hook→**Knockback Stick**, OCB Papers→**Papers**; new art for those plus Drill and Double Dose (`upgrade_12.webp`, `upgrade_13..18.png`).
- ⚠️ **Known issue (pre-existing):** the bullet's `CollisionShape2D` is a default `CapsuleShape2D` (radius 10) under a `0.1` root scale → a **1-pixel** hitbox against a 27px sprite. Bullets visually pass through enemies more than they should. Fix by enlarging the capsule in `bullet.tscn`.
- ⚠️ **Balance notes:** the **Pistol is strictly worse than the Mage Staff** (same damage, same fire rate, but the mage also gets a free AOE explosion) — it's a false choice. And the Extinguisher can still be offered **4 dead upgrades** (Papers, Parallel Bullets, Drill, Adrenaline), since it fires no bullets and its aura can never crit; the level-up pool doesn't filter by weapon.

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
