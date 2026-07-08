# Context for AI assistants

**Read `README.md` first** — it has the full project overview, architecture, current state, and (most importantly) **how to work with the project owner**, who is a complete beginner learning Godot.

Quick rules:
- **Reply in Romanian.** The owner is a beginner; teach in small, testable steps and be concrete about the Godot UI.
- **Godot 4.7 + GDScript.** Indentation is **TABS** — never mix tabs/spaces (Godot errors out). When code is involved, prefer writing `.gd` files directly to avoid copy-paste/tab problems.
- **Node lookups use groups:** `"player"` and `"enemy"` (via `get_tree().get_first_node_in_group(...)` / `get_nodes_in_group(...)`); cast results with `as Node2D` before using `global_position`.
- This is a **survivors-like / bullet-heaven** game (Vampire Survivors style), cyberpunk theme, for Android. See the roadmap in `README.md`.
- **Repo activ:** `Desktop\joc-bzn` (clonă pe `main`, remote `JocBZN/joc-bzn`). Notele vechi care zic „Downloads\joc-bzn-main" sunt depășite.

---

## Session log — 2026-07-08 (Frostwalker + Godwalker · reguli biom copaci/pietre · structuri de deșert)

**Done:**
- **Explozie Jean's Bomb mai mică**: cadre noi în `Upgrades/explozie_animatie/` + `EXPLOSION_VISUAL_SCALE` (0.5) în `fx.gd` (diametru la ~50%, raza AOE neschimbată).
- **Frostwalker** (upgrade nou, `upgrade_11.png`, `icetrail.gd`): oglinda lui Firewalker, dar **slow** în loc de damage principal. Inamicul primește slow (viteză 50%) ținut `SLOW_HOLD` sec apoi revenire în `SLOW_RECOVER`, cu **filtru albastru** (`enemy.gd`: `apply_slow(hold)`, `_current_slow_mult`, `_slow_color`; `_flash` revine la tenta de slow). Per upgrade: damage FIX (2), +0.5s slow (`frost_slow_time`), +0.3s durată trail. Firewalker scalat și el: +3 dmg, ×1.10 mărime, +0.3s durată per upgrade.
- **Godwalker** (`godtrail.gd`): când player-ul are ȘI Firewalker ȘI Frostwalker, `_drop_fire`/`_drop_ice` din `player.gd` nu mai lasă foc/gheață separat, ci `_drop_god` → o dâră combinată (damage foc+gheață + slow).
- **Feliere spritesheet la RULARE** pentru dâre: `frostwalker.png`/`Godwalker.png` tăiate în 4 cadre cu `AtlasTexture`, cu margini **rotunjite** (`round(i*W/N)`) ca să nu driftează stânga-dreapta / să nu taie cadre. Gheața e **desaturată** procesând pixelii o dată (`Image` → `ImageTexture`), nu shader (shaderul + AtlasTexture nu se aplica).
- **Reguli de biom pentru props** (`biome_map.gd` + `props.gd`/`rocks.gd`): funcții noi `desertness_at_chunk` (0..1, cu gradient, replică shaderul), `desert_inset_chunk` (adâncime în deșertul plin), `desert_rect_of_macro`, `macro_of_chunk`. **Copaci** blocați pe deșert ȘI gradient (`desertness > 0`); **pietre** blocate doar în deșertul hard (apar pe gradient).
- **Structuri de deșert** (`desert_structures.gd` nou + nod `DesertStructures` sub `World` în `main.tscn`): apar DOAR în deșert, din `harta/desert structures/`. Model: **cactus** împrăștiat per-chunk (`cacti_per_chunk`); **house** garantat `houses_min..houses_max` (1–2) **per deșert**, doar în deșertul plin la ≥`min_inset_px` (20) de gradient; **monument** cu `monument_chance` (0.5 = 1 la 2 deșerturi), doar în deșertul plin. Config per-tip (`CONFIG`: scale + hitbox + `min_inset_px`). Case/monumente legate de macro-celula deșertului (deterministe, independente de chunk).

**Gotchas:**
- **INVARIANT biom**: `desertness_at_chunk`/`desert_inset_chunk` din `biome_map.gd` trebuie să rămână în sync cu `biome.gdshader` (aceeași `BLEND_CHUNKS` = `blend_chunks` din `ground.gd`).
- **Determinism cu filtre**: consumă RNG-ul (pick + x + y) ÎNAINTE de a filtra pe biom, ca ordinea să fie identică la build și la verificarea vecinilor.
- **PNG nou/înlocuit trebuie IMPORTAT** înainte de rulare (`godot --headless --path . --import`), altfel `load()` dă `No loader found for resource` — și jocul crapă la prima dâră/structură.
- **Se poate RULA și verifica vizual din acest mediu**: Godot 4.7 din `Downloads\Godot_v4.7-stable_win64_console.exe` (căi absolute, PATH gol în shell). Scenă de test temporară → `get_viewport().get_texture().get_image().save_png("user://shot.png")` (rulat CU fereastră) → citit screenshot-ul. Șterge fișierele de test după.

---

## Session log — 2026-07-07 (8 direcții player + meniu upgrade „Megabonk" + text EN + Jean's Bomb + Firewalker)

**Done:**
- **Player pe 8 direcții + fix la înghețarea animației**: adăugate GIF-urile de alergat pe diagonale (NE/NV/SE/SV), sparte în cadre (`grasu directii/running/frames/<dir>_<i>.png`) și băgate în `player_frames.tres` (run + `idle_<diag>` = cadrul 0 al alergării). `player.gd` folosește acum `DIRECTII` de 8 (octanți, `PI/4`) ca `enemy.gd`/`garda.gd`. **Fix înghețare**: `_update_anim` cheamă `play()` DOAR când numele animației se schimbă și păstrează cadrul + `frame_progress` (altfel, lângă granița dintre 2 direcții cu stick analog, `play()` reseta cadrul la 0 → animația părea blocată).
- **Meniu de Level Up redesenat** (stil Megabonk, `levelup.gd`): fundal `Upgrades/Menu UI/Menu.png` ca **NinePatchRect**; lista upgrade-urilor în stânga, fiecare rând = iconița în **border-ul rarității** (`Border Common/Uncommon/Rare/Epic/Legendary.png`, 64×64) + raritate + nume + descriere. Fiecare upgrade are `"rar"`; culorile de text sunt **exact** culoarea dominantă a border-ului (extrasă cu `System.Drawing`: Common `#424B6D`, Uncommon `#838BA5`, Rare `#3AA04C`, Epic `#7A16E1`, Legendary `#EC7267`). Contur negru 2px pe tot textul (`font_outline_color` + `outline_size`). Butoanele sunt `flat` cu highlight pe hover. Mărimi reglabile (`CELL`, panou, fonturi).
- **Tot textul din joc tradus în engleză** (`menu.gd`, `levelup.gd`, `hud.gd`, `gameover.gd`, `spawner.gd`). Comentariile din cod rămân în română; `push_warning`/`print` (doar consola) au rămas RO.
- **Jean's Bomb** (upgrade LEGENDAR, `upgrade_9.png`): `+20` damage și gloanțele **explodează AOE** la impact. `bullet.gd` are `explosion_radius`/`explosion_damage`; la impact `_explode()` lovește inamicii din rază + îi suflă cu knockback (ca player-ul să nu mănânce damage de contact de aproape — explozia NU lovește player-ul, doar grupul `enemy`). Vizualul: `Fx.explosion(pos, radius)` din `fx.gd` (animația `Upgrades/explozie_animatie/`, 9 cadre, cache o dată, scalată pe rază).
- **Firewalker** (upgrade EPIC, `upgrade_10.png`, `firetrail.gd` nou): cât timp player-ul **merge**, lasă o dâră de foc care arde inamicii care o ating. Fiecare upgrade → +1s durată și +5px mărime (bază 1s / 80px). Spritesheet `Upgrades/firewalker anim/FireWalker Animation.png` (127×21, prim → **4 cadre** de 32px, tăiate pe grila naturală a flăcărilor). Focul se **rotește** după direcția de mers (baza e spre vest → `rotation = direction.angle() - PI`), e la **picioarele** player-ului (offset ×2 din cauza `scale=2`) și **sub** actori.

**Gotchas:**
- **Player-ul are `scale = Vector2(2,2)` în `main.tscn`** → orice offset în lume (picioarele) trebuie dublat (~58px sub origine).
- **Foc „sub player" indiferent de direcție**: y-sort se uită la Y-ul NODULUI, iar la nord flacăra rotită se întinde în sus peste sprite, iar dârele din sud se sortau în față. Rezolvat cu `z_index`: foc la **-1**, iar `Ground` coborât la **-10** în `main.tscn` (ca focul să fie sub actori dar peste iarbă). `z_index` bate y-sort-ul.
- **Culoarea „exactă" din border** = nuanța dominantă (mod), extrasă numărând pixelii opaci non-închiși; `Color8(r,g,b)` pentru valori 0–255 fără conversie.
- **Fișierele noi (Menu UI, border-uri, `upgrade_10.png`, cadrele firewalker) trebuie importate deschizând Godot o dată** înainte ca `load()` să le găsească (ca de obicei). Explozia era deja importată.
- **`127` e prim** → spritesheet-ul firewalker nu se împarte egal; l-am tăiat pe grila de 32px după unde cad flăcările (detectat cu profil de opacitate pe coloane).

---

## Session log — 2026-07-07 (muzică + sistem de VALURI + boss la final + screen shake)

**Done:**
- **Muzică de fundal în buclă**: `audio/music.wav` (loop de 8s, 22050 Hz mono, ~350KB) — un progres Am–F–C–G cu bas+arpegiu square, kick four-on-floor și hi-hat, sintetizat cu PowerShell + .NET (WAV PCM). În `audio.gd`: `play_music()`/`stop_music()` cu un `AudioStreamPlayer` dedicat (`PROCESS_MODE_ALWAYS`). Bucla e continuă setând pe resursă `AudioStreamWAV.loop_mode = LOOP_FORWARD` la rulare (fără gol între repetări). Pornită din `spawner._ready`, oprită din `spawner._exit_tree` (meniu/restart).
- **Sistem de VALURI** (rescris `spawner.gd` ca manager de waves, folosind nodul `Spawner` existent — fără scene noi). Un val = 3 faze (`enum State`): **SPAWNING** (apar inamici normali `wave_duration`=25s, tot mai des cu valul) → **BOSS** (apare `garda.tscn`; cât trăiește, nu mai apar inamici) → **BREAK** (`break_duration`=4s, apoi valul următor). Bossul mort e detectat cu `is_instance_valid(_boss)`. Numărul valului e ținut în `_wave` și trimis în `Difficulty.wave`.
- **Dificultate pe VAL, nu pe timp** (`difficulty.gd`): motorul principal e acum `Difficulty.wave` (setat de spawner). Multiplicatorii folosesc `(wave-1)`: HP +45%/val, viteză +6%/val, spawn +30%/val, XP scalat cu valul; XP2 deblocat de la valul 3. `time` rămâne doar pentru cronometrul de pe Game Over. Bossul se întărește automat prin `enemy_hp_mult()` din `garda._ready`.
- **Anunțuri pe ecran** (`hud.gd`): banner mare centrat (`announce(text, sub)`) cu „pop" (tween scale `TRANS_BACK`) + fade, folosit de spawner pentru „VALUL N", „BOSS!", „VALUL N TERMINAT". HUD-ul e acum în grupul `"hud"`.
- **Screen shake** (`player.gd`): sistem trauma pe `Camera2D` (`add_shake`, `_trauma²`, decay), declanșat la lovitură **critică** în `_fire()`. Gardă `_shaking`: player-ul atinge `cam.offset` DOAR cât tremură el, ca să nu se bată cu cutremurul statuii (care setează offset direct).

**Gotchas:**
- **Buclă WAV fără gol** = setat `loop_mode`/`loop_begin` pe `AudioStreamWAV` la rulare (nu reconectare pe `finished`, care lasă un mic gol). Fade de 8ms la capetele fișierului ca siguranță.
- **Screen shake + cutremurul statuii se bat pe `cam.offset`** → player-ul controlează camera doar cât `_trauma>0`, o readuce la zero O DATĂ la final, apoi n-o mai atinge (`_shaking`).
- **Eroare pre-existentă** (NU din această sesiune): „Can't change this state while flushing queries" apare de la coliziuni Area2D (gloanțe/XP/lightning care se distrug la impact în `body_entered`). Non-fatală (doar log spam); confirmată prin `git stash` + rulat originalul. De curățat separat (ex. `set_deferred("monitoring", false)` înainte de `queue_free`).
- Verificat rulând scena headless (`godot --headless res://main.tscn --quit-after N`) — fără erori NOI de script/rulare.

---

## Session log — 2026-07-07 (upgrade-uri de armă + efecte & animații)

**Done:**
- **Atelier de efecte** (`fx.gd`, autoload nou **`Fx`**). API refolosibil, tot din cod (fără scene noi de editat): `Fx.muzzle(pos)` (fulger la gura armei), `Fx.impact(pos, culoare)` (flash glow + scântei `CPUParticles2D` one-shot), `Fx.damage_number(pos, amount, crit)` (număr care sare în sus și se stinge; crit = galben mare cu contur). Glow-ul folosește o `GradientTexture2D` radială construită o dată + `CanvasItemMaterial` cu `BLEND_MODE_ADD`. Toate se adaugă în `get_tree().current_scene` (coordonate de lume) și se auto-distrug.
- **Mecanici noi de armă** (statistici pe `player.gd`, aplicate la tragere în `_fire()`): `crit_chance`/`crit_mult` (zar per glonț → damage ×2, număr galben), `pierce` (glonțul trece prin `pierce+1` inamici), `bullet_scale` (mărime sprite+hitbox), `knockback` (împinge inamicul). `bullet.gd` extins cu `pierce`/`knockback`/`is_crit` + `_hits`; nu se mai auto-distruge la primul contact, ci după `_hits > pierce`. La impact cheamă `Fx.impact` + `Fx.damage_number`.
- **Knockback pe inamic** (`enemy.gd`): `apply_knockback(v)` setează `_knockback`, adăugat la `velocity` în `_physics_process` și stins spre 0 cu `knockback_decay` (900 px/s²).
- **Muzzle flash** la fiecare volei în `player.gd _fire()` (`Fx.muzzle`, spre inamic).
- **4 upgrade-uri noi** în `levelup.gd` (acum 14 în pool, tot 3-din-N random): **Foraj** (pierce +1), **Adrenalină** (crit +15%), **Doză dublă** (bullet_scale +0.3 & +5 dmg), **Croșeu** (knockback +250). Icoane refolosite (bullet2/3, upgrade_3/5).
- Toate cele 3 gloanțe (`bullet`/`bullet2`/`bullet3.tscn`) partajează `bullet.gd` → efectele merg pe orice armă aleasă.

**Gotchas:**
- `CPUParticles2D` fără textură desenează pătrățele mici = scântei OK. Nume proprietăți 4.x: `scale_amount_min/max`, `initial_velocity_min/max`, `spread` (grade, 180=cerc), `explosiveness`, `one_shot`, apoi `emitting = true` la final.
- Numărul de damage = `Label` (Control) copil al unui `Node2D` în lume → randează corect în coordonate de lume; `z_index` mare ca să fie deasupra. GDScript are `a if cond else b` (nu `?:`).
- Efectele se adaugă în `current_scene` (root-ul `main`, NU în `World` care e y-sortat) + `z_index` 60/100 → mereu deasupra lumii, fără probleme de sortare.

---

## Session log — 2026-07-07 (sunet: manager audio + SFX generate)

**Done:**
- **Manager de sunet global** (`audio.gd`, autoload nou **`Audio`** în `project.godot [autoload]`, lângă `Difficulty`/`GameSettings`). API simplu: `Audio.play("shoot", volume_db, pitch_rand)`. Ține un **pool** de 12 `AudioStreamPlayer` (ca să sune multe efecte deodată — multe gloanțe), alege o „boxă" liberă (rotativ dacă toate cântă), aplică variație aleatoare de ton (`pitch_scale`) ca să nu sune identic. `process_mode = ALWAYS` (se aude și pe pauză, ex. level up). Sunetele sunt într-un dicționar `SFX` nume→cale; adaugi un efect nou punând o linie acolo.
- **6 efecte sonore retro generate în cod** (nu descărcate) în `audio/`: `shoot`, `hit`, `enemy_die`, `xp`, `levelup`, `hurt`. Sintetizate cu **PowerShell + .NET** scriind WAV PCM 16-bit mono 44100 Hz direct (sweep-uri de frecvență, zgomot alb, arpegiu C-E-G). Seed fix → reproductibile.
- **Agățate în gameplay:** `player.gd _fire()` → `shoot` (−6 dB); `player.gd take_damage()` → `hurt`; `player.gd _level_up()` → `levelup`; `enemy.gd take_damage()` → `hit` (−8 dB, se aude des); `enemy.gd _die()` → `enemy_die`; `xp.gd` la colectare → `xp`.

**Gotchas:**
- **WAV-urile noi trebuie importate** (rulat `godot --headless --import` sau deschis editorul o dată) înainte ca `load()` la rulare să le găsească — la fel ca PNG-urile. Verificat: `.import` create, `--import` fără erori de script.
- `Audio.play` folosește `load()` cu gardă pe `null` → dacă un wav lipsește/nu-i importat, pur și simplu nu se aude (nu crapă).
- Volumele sunt în **dB** (0 = plin, negativ = mai încet). `hit` e la −8 fiindcă sună la fiecare glonț care lovește.

---

## Session log — 2026-07-07 (statuie „Summon" + boss Garda + atac lightning)

**Done:**
- **Statuie interactivă** (`statue.gd` + `statue.tscn`, instanțiată în `main.tscn` sub `World` la `(0,-220)`): `StaticBody2D` cu Sprite2D (`harta/statue.png`, scale 3) + `CollisionShape2D` dreptunghi **editabil vizual în editor** (după ce sistemul „pe orb" din cod, cu fracții din lățime + `sort_anchor`, s-a dovedit nereglabil — refăcut ca scenă). Poziția nodului = BAZA statuii → și linia de Y-sort (te acoperă din nord, nu din sud). Când player-ul e la < `interact_range` (200) apare un `Button` mic „Summon" (creat în cod, deasupra statuii).
- **Secvența de Summon** (în `statue.gd`, o singură dată): (1) simbol de alertă (`Upgrades/symbol_alert_002_large_red/`, 16 cadre) deasupra statuii; (2) statuia **intră în pământ** (Tween: coboară `sink_depth`=70px + fade) și coliziunea se dezactivează; (3) **cutremur** pe ecran = `Camera2D.offset` aleator care scade la 0 (`tween_method` + `randf_range`); (4) **iese încet un boss din pământ** la `enemy_spawn_offset` (spre nord), înghețat (`set_physics_process(false)`) cât urcă, apoi pornește. Toate reglabile prin `@export`.
- **Boss „Garda"** (`garda.gd` + `garda.tscn`) — inamic invocat DOAR de statuie. GIF-urile din `boss/` (mers pe 8 direcții) sparte în PNG-uri `walk_<dir>_<i>.png` (6 cadre/dir, 128×128) cu PowerShell + `System.Drawing`; `SpriteFrames` construit în cod la rulare. Cadrul static `garda_0.png` = animația „summon" (cât iese din pământ); după ce merge, joacă animația pe octantul spre player (ca `enemy.gd`). Mai lent (`speed` 70) și mai rezistent (`max_hp` 200), lasă mult XP. Scale (2.5) și hitbox (cerc rază 28) reglate pe scenă.
- **Atac de la distanță** (`lightning.gd` + `lightning.tscn`): garda aruncă o **bilă de lightning** (Area2D, hitbox **cerc**) când player-ul e în `attack_range` (420) și cooldown-ul (`attack_interval` 2s) e gata. Proiectilul zboară pe direcția spre player, lovește **doar** grupul `"player"` (`is_in_group`), îi cheamă `take_damage`. Animație din `boss/lightning_burst_003_large_violet/` (10 cadre). Vizibilitate: `anim_fps` mic (8, cadre mai lente) + `modulate` PESTE 1 (`tint` Color(1.9,1.5,2.4)) → strălucește cu glow-ul din `atmosphere.gd`.

**Gotchas:**
- **Y-sort se uită DOAR la Y-ul NODULUI**, nu la unde e desenat sprite-ul. Ca `sort_anchor`/linia de acoperire să conteze, trebuie mutat NODUL, nu doar imaginea (păcăleală ca la copaci). În final, cea mai simplă abordare corectă = nodul statuii la BAZĂ, sprite desenat în sus, sort = picioarele.
- **`CanvasItem` NU are `position`** (doar `Node2D`). Un `as CanvasItem` pe sprite-ul inamicului urmat de `.position` = eroare de compilare care „strica tot" (nici butonul nu apărea). Tipează `as Node2D`.
- **Lambda-uri inline cu `-> void:`** pot da erori de parsare la Godot — mai sigur funcții numite + `Callable.bind(...)` (ex. `enemy.set_physics_process.bind(true)`).
- **GIF-urile NU-s folosibile direct** de Godot → sparte în PNG-uri. Iar PNG-urile noi trebuie **importate deschizând Godot** înainte ca `load()` la rulare să le găsească.
- **Hitbox editabil = scenă, nu cod.** Pentru un beginner, reglatul din `@export`-uri numerice e un chin; un `CollisionShape2D` într-un `.tscn` (tras cu mouse-ul în viewport) e mereu „ce vezi = ce ai".

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
- **Player art:** now an `AnimatedSprite2D` (was a static `Sprite2D`). Running animations for 8 directions (E, SE, S, SW, W, NW, N, NE) + `idle_*` frames for standing. Frames are in `grasu directii/running/frames/` (running) and `grasu directii/rotations/` (cardinal idle poses; diagonal idle reuses that run's frame 0). Animations resource: `player_frames.tres`. Logic in `player.gd`: picks direction by movement angle (8 eighths, `PI/4`), plays `idle_<dir>` when standing.
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
