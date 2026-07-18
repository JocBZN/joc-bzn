# Context for AI assistants

**Read `README.md` first** — it has the full project overview, architecture, current state, and (most importantly) **how to work with the project owner**, who is a complete beginner learning Godot.

Quick rules:
- **Reply in Romanian.** The owner is a beginner; teach in small, testable steps and be concrete about the Godot UI.
- **Godot 4.7 + GDScript.** Indentation is **TABS** — never mix tabs/spaces (Godot errors out). When code is involved, prefer writing `.gd` files directly to avoid copy-paste/tab problems.
- **Node lookups use groups:** `"player"` and `"enemy"` (via `get_tree().get_first_node_in_group(...)` / `get_nodes_in_group(...)`); cast results with `as Node2D` before using `global_position`.
- This is a **survivors-like / bullet-heaven** game (Vampire Survivors style), cyberpunk theme, for Android. See the roadmap in `README.md`.
- **Repo activ:** `Desktop\joc-bzn` (clonă pe `main`, remote `JocBZN/joc-bzn`). Notele vechi care zic „Downloads\joc-bzn-main" sunt depășite.
- **Există un CODEX al upgrade-urilor**, artifact pe claude.ai: `https://claude.ai/code/artifact/490e047c-2f80-45c5-b6a6-9af326065a4e`. Când schimbi ceva în `levelup.gd` (item nou, raritate, efect, iconiță) sau în `game_settings.gd` (META), **actualizează-l și pe el** — altfel rămâne în urmă în tăcere. **De pe 2026-07-17 e generat data-driven** din `codex.html` (în repo): editezi array-ul `ITEMS` / `SYN` de sus (efectele reale din cod), iconițele+chenarele se re-encodează base64 și se injectează în placeholder-ul `/*__ASSETS__*/` cu scriptul PowerShell (vezi session log 2026-07-17 „Codex regenerat”), apoi republici pe același URL cu `url=`. Mult mai simplu decât chirurgia pe base64.
- **NU da `git push` decât dacă Răzvan îți cere explicit** (regulă din 2026-07-16, o înlocuiește pe cea de mai jos din log-ul de sesiune, care zicea să dai push automat). Restul finisajului rămâne automat: după ce termini o serie de schimbări, actualizezi CLAUDE.md + README și faci commit local (mesaj în română) — dar `main`-ul de pe GitHub îl atinge doar el, când zice.

---

## Session log — 2026-07-18 (overlay de frunze peste tot ecranul)

**Done:**
- `harta/Leaf Overlay.png` = bandă de **80×16 = 5 frunze DIFERITE de 16×16** (nu cadre de animație — verificat fiecare celulă separat: 14-24 pixeli opaci, forme diferite).
- **Overlay de frunze în `atmosphere.gd`** (acolo era deja vignette + glow, deci toate reglajele de atmosferă stau într-un singur nod, „Atmosphere", selectabil în editor). `_setup_leaves()` face `leaf_count` Sprite2D-uri, fiecare cu un **`AtlasTexture`** care decupează una din cele 5 frunze la întâmplare; `_update_leaves()` le mișcă în fiecare cadru.
- **Mișcarea:** cădere + legănat pe sinus (fiecare frunză cu amplitudine și frecvență proprii) + vânt lateral + rotire proprie. Când ies pe jos reintră pe sus în alt loc, când ies în lateral reintră pe partea cealaltă → ciclu fără sfârșit, fără „valuri" vizibile.
- Reglaje `@export` pe nodul Atmosphere: `leaves_enabled`, `leaf_count` (28), `leaf_speed_min/max`, `leaf_wind`, `leaf_sway`, `leaf_scale_min/max`, `leaf_alpha`, `leaf_spin`.

**Gotchas:**
- **E pe `CanvasLayer`, deci în SPAȚIUL ECRANULUI** — frunzele nu se mișcă odată cu camera, plutesc peste toată imaginea oriunde ai fi în lume. Asta a cerut Răzvan („overlay peste tot ecranul").
- **Layer 2 = sub vignette (3), peste lume.** Intenționat: vignette-ul întunecă și frunzele din colțuri, altfel par lipite pe geamul camerei. Dacă le vrei peste tot, inclusiv peste marginile întunecate, pui layer 4.
- **`texture_filter = TEXTURE_FILTER_NEAREST` pe fiecare frunză** — fără el, o textură de 16px mărită de 2-3× iese ca o pată neclară în loc de pixel art.
- **Frunzele mari cad mai repede** (`viteza * (sc / leaf_scale_max)`) — truc ieftin de adâncime: cele mari par mai aproape de cameră.
- Le împrăștiem pe tot ecranul la pornire, nu doar sus, altfel vezi primul val care intră de sus în primele secunde.
- Verificat prin rulare reală: 28 de frunze active, toate cele 5 feluri ies la sorți, două poze la 1.5s distanță confirmă că se mișcă și se rotesc.

---

## Session log — 2026-07-18 (statuia: 3 variante alese pe șansă)

**Done:**
- Răzvan a pus `harta/Statue Version 1..3.png` și a **șters `harta/statue.png`** — adică `statue.gd` (`preload`) și `statue.tscn` (`ext_resource`) arătau spre un fișier inexistent. `preload` pe o cale lipsă e eroare de parsare, deci statuia era ruptă până la reparație.
- **Alegere pe șansă la fiecare statuie născută:** `VARIANTE` în `statue.gd` — Version 2 **60%**, Version 1 **30%**, Version 3 **10%**. Implementat ca „roată a norocului" (scădem șansele dintr-un zar până trece de 0). Verificat pe 10.000 de trageri: 59.9 / 30.3 / 9.8.
- `statue.tscn` arată acum spre Version 2 (varianta implicită, cea mai comună), ca scena să se deschidă normal în editor.

**Gotchas:**
- **Canvas 91×91 → 128×128**, deci `offset`-ul sprite-ului trebuia recalculat. Convenția din scenă e că `offset.y = -h/2` lipește **baza texturii** de originea nodului (originea = picioarele statuii, și linia de Y-sort). Pus pe **−60** (nu −64), ca baza artei să cadă exact unde cădea înainte. Verificat cu o linie de sol desenată: toate 3 stau perfect pe ea.
- **Butonul „Summon" se agață de CAPUL real, nu de marginea imaginii.** Variantele noi au ~30px de gol transparent deasupra; cu formula veche (înălțimea canvas-ului) butonul plutea la ~87px deasupra capului. Acum `_statue_top_y()` folosește `texture.get_image().get_used_rect()` → iese −273/−279/−285, adică fix deasupra capului fiecărei variante, indiferent de artă.
- **Coliziunea (130×60) a rămas neschimbată** — piedestalul nou are ~130px lățime pe ecran (48px × scale 3), deci se potrivește deja.
- **Există o SINGURĂ statuie în `main.tscn`**, deci varianta se alege o dată pe rundă — vezi statui diferite de la o rundă la alta, nu 3 deodată în lume.

---

## Session log — 2026-07-18 (VALURILE ELIMINATE → 10 minute + Final Swarm, ca la Megabonk)

**Done:**
- **Sistemul de valuri e complet scos.** În loc de „val 1 → boss → val 2 → …", runda are acum două faze, ca la Megabonk:
  - **0:00 → 10:00**, cronometru care **scade**. Inamicii curg continuu și cresc **liniar** (+55% viață/minut, +3.5% viteză, +28% rată de spawn). La minutul 10 sunt ~6.5× mai tari ca la început.
  - **FINAL SWARM** (după 10 min), cronometru care **urcă** de la 0. Creșterea devine **exponențială**: viața se dublează la fiecare 45s, rata de spawn la fiecare 75s, plus un salt brusc ×3 fix în secunda trecerii. Nu e menit să fie supraviețuibil — scorul e cât reziști.
- **`difficulty.gd` rescris.** `wave` a dispărut; totul se calculează din `time`. API nou: `is_final_swarm()`, `overtime()`, `time_left()`, `RUN_LENGTH` (600s). Toate butoanele de reglaj sunt constante la începutul fișierului (`HP_PER_MIN`, `FS_HP_DOUBLE_EVERY`, `SPEED_CAP` etc.).
- **`spawner.gd` rescris** — fără stări/valuri/boss. La fiecare tick transformă `spawn_mult()` în inamici/secundă; dacă ritmul cerut e mai rapid decât `min_interval`, **scoate mai mulți deodată** (`batch`) în loc să bată timer-ul mai des. Plafoane de siguranță: `max_enemies = 300`, `max_batch = 12`.
- **Bossul „Garda" se cheamă DOAR de la statuie** (cum era deja în `statue.gd`) — decizia lui Răzvan, e exact modelul Megabonk. `garda.gd` citește aceiași multiplicatori, deci cu cât îl chemi mai târziu, cu atât e mai tare.
- **HUD:** cronometru mare sus-centru (alb → **galben** în ultimul minut → **roșu cu „+"** în Final Swarm) + **kill count** sus-dreapta.
- **Kill count** nou: `GameSettings.run_kills`, incrementat în `enemy._die()` și `garda._die()`. Apare pe HUD, pe ecranul de Game Over și în leaderboard.
- **Leaderboard** salvează acum `{time, level, kills}` și marchează cu „SURVIVED" rundele care au trecut de cele 10 minute. Scorurile vechi n-au cheia `kills` → citite cu `s.get("kills", 0)`, deci nu crapă.

**Gotchas:**
- **Nu există formulă oficială Megabonk.** Am căutat, inclusiv date extrase din cod — comunitatea zice că sistemul intern e pe „credite" și nu e documentat public. Ce se confirmă: 10 minute, la 0 pornește „Final Swarm", iar scaling-ul urcă HP/viteză/damage/presiune de spawn. Restul numerelor sunt alese de mine ca să dea curba descrisă.
- **Viteza inamicilor are `SPEED_CAP = 2.2`.** Fără plafon, exponențiala îi face mai rapizi decât player-ul în ~2 minute de Final Swarm și n-ai mai avea absolut nimic de făcut. Viața poate exploda, viteza nu.
- **XP-ul crește la fel de repede ca viața în Final Swarm** (același `_fs_factor`), altfel n-ai mai lua niciun nivel exact când ai nevoie de el.
- **BUG vechi reparat pe drum:** `_drop_xp()` adăuga gema (Area2D) în timpul callback-ului de fizică → `Can't change this state while flushing queries` la FIECARE moarte de inamic. Nu se vedea mult înainte; cu sute de morți pe minut în Final Swarm devenea spam serios. Acum e `_drop_xp.call_deferred()` în `enemy.gd` și `garda.gd`.
- **Capcană la testat:** ecranul de level-up pune `get_tree().paused = true`, ceea ce oprește și `Difficulty.time` (corect pentru joc!). Dar `get_tree().create_timer()` merge mai departe pe pauză, așa că un test care „sare la minutul X" și așteaptă măsoară aiurea. Ca să testezi încărcarea, forțează `get_tree().paused = false` în fiecare cadru.
- Verificat prin rulare reală: trecerea la 10:00 se face corect (cronometru roșu + banner „FINAL SWARM"), iar la +3 minute erau **213 inamici simultan la 143 fps** — deci plafoanele țin.

---

## Session log — 2026-07-18 (artă nouă de inamic: „Short guy with a red", 8 direcții animate)

**Done:**
- Răzvan a șters vechiul folder `homeless directii/running homeless/` + `homeless directii pe loc/` și a pus 8 GIF-uri noi direct în `homeless directii/` (`Short_guy_with_a_red_walk_<dir>.gif`).
- **Tăiate în cadre** cu PowerShell + .NET `System.Drawing` (`FrameDimension.Time` + `SelectActiveFrame`, ca la sprite-urile vechi — tot nu există ImageMagick/ffmpeg/Python pe mașină). Rezultat: `homeless directii/frames/walk_<dir>_<0..5>.png`, **8 direcții × 6 cadre = 48 PNG**, 120×120, fundal transparent.
- **`enemy_frames.tres` regenerat de la zero** — 8 animații (`east`, `north`, `north_east`, `north_west`, `south`, `south_east`, `south_west`, `west`), toate cu `loop=true` și 6 cadre. Numele se potrivesc peste `DIRECTII` din `enemy.gd`, deci n-a trebuit atins codul.
- **`north` e acum animat.** Înainte era un singur cadru static (fallback din 2026-07-07, „lipsește GIF-ul de north running") — GIF-ul nou îl are, deci punctul ăla din TODO e rezolvat.

**Gotchas:**
- **`speed = 12.0`** (nu 8.0 ca înainte): animațiile vechi aveau 4 cadre la 8 fps = 0.5s/ciclu; cele noi au 6 cadre, deci 12 fps păstrează exact aceeași cadență de mers. Dacă vrei mers mai lent/rapid, ăsta e butonul, în `enemy_frames.tres`.
- **Hitbox-ul și `scale` NU au trebuit schimbate:** măsurat conturul opac — personajul vechi 37×60 px pe canvas 124×124, cel nou 31×59 px pe 120×120. Practic identic, deci `CircleShape2D` (rază 10 × scale 1.5) rămâne valabil.
- `.tres`-ul nou e scris **fără `uid=`** în `ext_resource` — Godot le rezolvă pe cale și își completează singur UID-urile. (Vechiul `.tres` avea UID-uri hardcodate spre fișiere șterse → de aia dădea `Failed loading resource` la fiecare `--import`.)
- Verificat vizual: randate toate cele 8 direcții într-o scenă de test, orientările sunt corecte (east→dreapta, west→stânga, north→din spate, south→din față).

---

## Session log — 2026-07-18 (audio nou: temă de meniu + click de buton tăiat)

**Done:**
- **Context:** Răzvan a șters manual toate SFX-urile vechi generate în cod (`shoot`/`hit`/`enemy_die`/`xp`/`levelup`/`hurt`/`music.wav`) și a pus în loc 2 fișiere: `audio/main menu theme.ogg` și `audio/button.mp3`.
- **`button.mp3` tăiat pe soundwave.** Măsurat cu Godot (nu există ffmpeg/Python pe mașină): fișierul avea 0.144 s, din care sunet real doar **0.046 s** — 50 ms tăcere la început (se simțea ca lag la click) și 66 ms la final. Rezultat: `audio/button.wav`, 16-bit stereo 48 kHz, cu 1 ms pre-roll ca să nu se taie atacul.
- **`audio.gd` curățat:** `SFX` conține acum doar `button`; încărcarea trece prin `ResourceLoader.exists()` (înainte ieșeau **6 erori roșii la fiecare pornire** pentru fișierele șterse). Muzica a fost generalizată: `MUSIC_MENU` / `MUSIC_GAME` + `_play_track()` privat, cu `play_menu_music()` / `play_music()` / `stop_music()`. Loop-ul se setează după format (`loop` la Ogg/MP3, `loop_mode` la WAV). `MUSIC_GAME` e gol → muzica din joc e oprită până pune el un fișier, fără erori.
- **`menu.gd`:** pornește tema în `_ready()`, o oprește în `_on_start()` (la intrarea în joc). Click-ul se pune pe **toate** butoanele deodată cu `_hook_button_sounds(self)`, care merge recursiv prin arbore după `_build_*` — deci prinde și butoanele de armă și cele de „BUY”, și nu trebuie agățat manual la fiecare buton nou. Volumul: constanta `CLICK_DB` din `menu.gd`.

**Gotchas:**
- **Cum tai audio fără ffmpeg:** bus nou cu `AudioEffectCapture` (mutat), redai stream-ul pe el, aduni `get_buffer()` în `_process`, cauți primul/ultimul sample peste 1% din vârf, apoi construiești `AudioStreamWAV` (PCM 16-bit interleaved via `data.encode_s16`) și `save_to_wav()`. Trebuie rulat **windowed**, nu `--headless` (headless folosește driver audio dummy → capturezi tăcere).
- `Audio.play("nume")` iese tăcut dacă numele nu e în `SFX` — de asta apelurile rămase din `player.gd`/`enemy.gd`/`xp.gd` nu deranjează. Ca să reactivezi un sunet: pui fișierul în `audio/`, adaugi linia în `SFX`, rulezi `--import`.
- `button.mp3` (originalul) a rămas în repo ca sursă; jocul folosește `button.wav`.
- Verificat prin rulare: muzica `playing=true` cu `loop=true`, iar apăsarea unui buton ocupă o boxă din pool (0 → 1 active).

---

## Session log — 2026-07-17 (Codex regenerat data-driven + sincronizat)

**Done:**
- **Codexul (artifact) adus la zi** cu tot ce lipsea: Last Resort (redenumit), multi-crit la Adrenaline, Broken Watch, Stacked Armory, Thunder God, Plugged In. Acum **34 de upgrade-uri**, numărătorile pe tier corecte, secțiunea „Ce nu scrie în joc” actualizată (Thunder God + Plugged In, multi-crit, ce nu ajunge la Stingător).
- **Refăcut complet abordarea:** în loc de chirurgie pe base64, codexul e acum **`codex.html` (în repo)** — un template cu design-ul cyberpunk păstrat + array-urile `ITEMS`/`META`/`SYN` (efectele reale din cod) + cod de render în JS. Iconițele și chenarele se citesc din fișiere, se encodează base64 și se injectează în `/*__ASSETS__*/` cu un script PowerShell (UTF-8 fără BOM, ca să nu strice diacriticele). Publicat pe același URL cu `Artifact url=…`.

**Gotchas:**
- **Editarea viitoare = trivială:** schimbi `ITEMS`/`SYN` de sus în `codex.html`, rulezi din nou splice-ul de assets (înlocuiește iar cele două linii `const BORDERS=…`/`const ICONS=…`), republici. Efectele din codex se scriu din `_apply` (levelup.gd) + player.gd, NU din descrierile din joc.
- **WebFetch pe URL de artifact chiar întoarce HTML-ul brut** (salvat local ca fișier), deci se poate citi conținutul vechi — dar are cache 15 min per URL.

---

## Session log — 2026-07-17 (Item nou: Plugged In — Thunder God pe șansă)

**Done:**
- **Plugged In** (`upgrade_39.png`, **Rare**): „10% chance to chain lightning on hit". Face exact ce face Thunder God (același `thunder_burst`), dar cu **șansă** la impact în loc de mereu. **+10% pe luare** (prima = 10%, cum a cerut), plafonat la 100%.
- **Decizia de declanșare unificată** în `player.thunder_active_on_hit()`: Thunder God (`thunder_stacks > 0`) → mereu true; altfel Plugged In → `randf() < min(1, plugged_in_stacks * 0.10)`. Folosită de sabie (`_sword_damage_pass`) și de glonț (prin `thunder_burst_maybe`, varianta deferred care rulează rostogolirea la momentul deferred). Flag-ul `bullet.thunder` = are vreo sursă (`thunder_stacks > 0 or plugged_in_stacks > 0`).
- **Pool-ul e acum 34 de upgrade-uri.**

**Gotchas:**
- **Rostogolirea se face la HIT, per lovitură** (nu la tragere): fiecare glonț/tăietură care lovește un inamic rulează propria șansă. La glonț se rulează în `thunder_burst_maybe` (deferred), nu în callback-ul de coliziune.
- **Se combină cu Thunder God:** dacă ai și Thunder God, `thunder_active_on_hit` întoarce mereu true (Plugged In devine irelevant). Damage-ul arcului e tot 25% din `bullet_damage` (Plugged In nu-l schimbă).
- Verificat pe 40.000 de apeluri: 1/3/5 stack-uri → 10/30/50% declanșare; cu Thunder God → 100%.

---

## Session log — 2026-07-17 (Thunder God: sabie + tentă albastră + 200px + 25% dmg)

**Done (peste implementarea de mai jos):**
- **Merge și cu Cursed Sword:** `_sword_damage_pass` cheamă `thunder_from(enemy)` pentru fiecare inamic pe care-l taie (dacă `thunder_stacks > 0`), la fel ca glonțul.
- **Tentă albastră pe inamicii loviți de curent:** `enemy.flash_electric()` (nou) — sclipire albastră electrică (`ELECTRIC_TINT = Color(0.5, 0.85, 2.6)`), ceva mai lungă (0.28s) decât cea albă de lovitură; revine la tenta curentă (albastru de frost dacă e înghețat). Chemată din `thunder_from` pe fiecare inamic ars de arc.
- **Damage = 25% din damage-ul playerului:** `thunder_damage()` = `bullet_damage * 0.25` (nu mai scalează cu `thunder_stacks`; `thunder_stacks` doar activează itemul). Crește indirect cu upgrade-urile de damage.
- **Rază 100 → 200px** (`thunder_range`).

**Gotchas:**
- **Glonțul cheamă lanțul cu `call_deferred("thunder_burst", ...)`**, NU direct: impactul glonțului se emite în timpul pasului de fizică, iar a omorî vecinii acolo dă „Can't change this state while flushing queries" (39 erori la stress → 3 baseline după fix). De-aia `thunder_from` (nod) a fost spart în `thunder_from(src)` (pt. sabie, care rulează în `_process`, nu în fizică) + `thunder_burst(origin, exclude_id)` (pe poziție + id, ca să meargă deferred chiar dacă inamicul-sursă a murit între timp). **Rămân ~3-5 erori „flushing queries" pre-existente** (gloanțe/morți în coliziune), fără legătură cu Thunder God.
- Ordinea în `thunder_burst`: `take_damage` (care dă sclipirea ALBĂ) apoi `flash_electric` (omoară tween-ul alb, pune albastru) → câștigă albastrul. Dacă inamicul moare din arc, `flash_electric` iese pe `_dying`.
- Verificat: dmg 25% (5 la bullet_damage 19), rază 200 (inamic la 150px lovit, la 250px nu), tenta `modulate.b = 2.6`, sabia declanșează arcuri, iar un vecin nelovit de sabie ia doar damage de curent. Screenshot: inamici albaștri + arcuri + „5".

---

## Session log — 2026-07-17 (Item nou: Thunder God — chain lightning ca Jacob's Ladder)

**Done:**
- **Thunder God** (`upgrade_38.png`, **Epic**): la impactul unui glonț, curent electric de la inamicul LOVIT spre TOȚI ceilalți din rază (`thunder_range` = 100px) — fiecare primește un arc + damage. Ca **Jacob's Ladder** din Binding of Isaac. Animația pornește din inamic (nu din player), la impact, și **NU se lanțuie mai departe** (arcurile nu declanșează alt Thunder).
- **Artă:** `fx/electricity fx/electricity.png` (896×63) tăiată în **14 cadre de 64×63** (`frame_0..13.png`, System.Drawing), încărcate cu `_load_fx_frames("res://fx/electricity fx", 30.0, false)`. Fulgerul e spre NORD și umple toată înălțimea (0..62, fără padding).
- **Vizual (`_spawn_electric_arc`):** rotit ca gloanțele (`dir.angle() + PI/2`, „nord→direcție") și **întins pe verticală** ca lungimea să fie fix distanța dintre inamici (`scale.y = d / 63`); `scale.x = 1.0` = grosimea liniei. Centrat între cei doi → capetele cad exact pe inamici. One-shot, se auto-distruge.
- **Damage:** `thunder_damage()` = ½ × `bullet_damage` × `thunder_stacks` (1 luare = 50%, 2 = 100% ...).
- **Cablaj:** `_spawn_one_bullet` setează `bullet.thunder = thunder_stacks > 0`; `bullet._on_body_entered` cheamă `player.thunder_from(body)` la impact. Doar la gloanțe (pistol/mage).
- **Pool-ul e acum 33 de upgrade-uri.**

**Gotchas:**
- **Nu se auto-lovește:** `thunder_from` sare peste `src` (inamicul lovit deja a primit damage-ul glonțului) și peste inamicii din afara razei.
- **Nu se lanțuie recursiv:** damage-ul de arc trece prin `enemy.take_damage` direct, nu prin glonț, deci nu re-declanșează Thunder — exact ca Jacob's Ladder (un singur „salt" din inamicul lovit).
- **Efectul e copil al World-ului** (`get_parent()`), nu al player-ului → scale natural (nu ×2), `z_index = 50` ca să fie peste inamici.
- Verificat: cu inamici la 50/80/200px de sursă → 2 arcuri (doar cei sub 100px), damage corect, sursa neatinsă; și pe o coliziune REALĂ de glonț arcul apare.

---

## Session log — 2026-07-17 (Broken Watch → proiectile random, ca Stacked Armory)

**Done:**
- **Broken Watch nu mai adaugă proiectile PARALELE.** Acum, când se declanșează (50%), trage `broken_watch_stacks` proiectile în **ALȚI inamici la întâmplare**, exact ca Stacked Armory — doar că pe șansă, nu garantat.
- În `_fire_bullets`, cele două s-au unit într-un singur bloc de „proiectile bonus random": `bonus = stacked_armory_stacks (garantat) + broken_watch_stacks (dacă randf() < 0.5)`, apoi `_armory_targets(target, bonus)` + `_spawn_one_bullet`. `bullet_count` nu mai e umflat de Broken Watch (salva principală rămâne curat paralelă = Twin Comets).

**Gotchas:**
- Verificat: cu 2 stack-uri Broken Watch și `bullet_count` 1 → 50% salve cu 1 glonț, 50% cu 3; când sunt 3, merg în direcții diferite (inamici random), nu paralel.
- Descrierea itemului rămâne „50% chance to fire +1 projectile" (nu zicea nimic de paralel, deci e tot corectă).

---

## Session log — 2026-07-17 (Item nou: Stacked Armory)

**Done:**
- **Stacked Armory** (`upgrade_37.png`, **Rare**): „+1 projectile at a random enemy". Proiectil GARANTAT în plus pe luare (scalează +1, +2, +3), dar spre deosebire de Twin Comets (paralele lângă țintă), fiecare proiectil bonus e tras într-un **ALT inamic la întâmplare** → pleacă în direcții diferite deodată.
- **Refactor:** crearea unui glonț a fost scoasă în `_spawn_one_bullet(pos, dir, dmg_base, ex_radius, ex_damage) -> bool` (întoarce dacă a fost critic). Folosit și de salva principală, și de Stacked Armory. `_armory_targets(primary, n)` alege `n` inamici, preferați alții decât ținta principală.
- Variabilă nouă: `stacked_armory_stacks` (player.gd). Efect în `_fire_bullets`, după salva principală.
- **Pool-ul e acum 32 de upgrade-uri.**

**Gotchas:**
- **Se garantează n proiectile bonus chiar dacă nu-s destui alți inamici:** `_armory_targets` repetă lista amestecată (`others[i % size]`) și, dacă nu există niciun alt inamic, cade pe ținta principală — altfel itemul n-ar face nimic când e un singur inamic pe hartă.
- **`tnode` din array e Variant** → `var d2 := tnode.global_position...` dă „Cannot infer type". Rezolvat cu `var enemy2 := tnode as Node2D`. (Aceeași capcană ca la `get_*_in_group` din CLAUDE.)
- **Doar la gloanțe (pistol/mage)**, ca Twin Comets / Broken Watch. Nu apare în panoul de STATS (bonus condiționat de existența altor inamici, nu stat fix).
- Verificat: cu 2 stack-uri și `bullet_count` 1 ies 3 gloanțe pe salvă, cele 2 bonus spre inamici diferiți aleși random (unghiuri diferite, variază de la salvă la salvă).

---

## Session log — 2026-07-17 (Item nou: Broken Watch)

**Done:**
- **Broken Watch** (`upgrade_36.png`, **Uncommon**): „50% chance to fire +1 projectile". La fiecare salvă, șansă FIXĂ de 50% să tragi proiectile bonus. Repetarea NU crește șansa, ci CÂTE proiectile bonus dai când se declanșează: +1, +2, +3 ... (`p.broken_watch_stacks += 1` pe luare).
- Implementat în `_fire_bullets`: `count := bullet_count`, apoi `if broken_watch_stacks > 0 and randf() < broken_watch_chance: count += broken_watch_stacks`. Bucla de tragere folosește acum `count` (și centrarea offset-ului tot pe `count`). Variabile noi în player.gd: `broken_watch_chance` (0.5, `@export`) și `broken_watch_stacks`.
- **Pool-ul e acum 31 de upgrade-uri.**

**Gotchas:**
- **Doar la gloanțe (pistol/mage).** Stingătorul și sabia nu folosesc `bullet_count`, deci nu văd Broken Watch — exact ca Twin Comets.
- **Nu apare în panoul de STATS.** E un bonus condiționat (pe șansă), nu un stat fix ca `bullet_count`, deci rândul „Projectiles" arată tot valoarea de bază.
- Verificat pe 6000 de salve cu 2 stack-uri și `bullet_count` 1: ~49% trag 1 proiectil, ~51% trag 3 (1 + 2 bonus). Șansa e fixă, bonusul scalează.
- **Raritatea (Uncommon) e ușor de schimbat** din intrarea din `UPGRADES` — pusă modest fiindcă efectul e pe șansă (Twin Comets, +2 GARANTAT, e Legendary).

---

## Session log — 2026-07-17 (Multi-crit peste 100% șansă)

**Done:**
- **Șansa de critic nu mai e plafonată la 100%.** Peste 100% intră **multi-crit** (stil Brotato): partea întreagă din șansă = crituri GARANTATE, partea fracționară = șansa de încă unul. Fiecare nivel înmulțește damage-ul cu `crit_mult` (2×): **100% → 2×, 200% → 4×, 300% → 8×** ... 150% = 50% ×2 / 50% ×4.
- **`player.roll_crit()`** (nou) întoarce `{tiers, mult}` și e sursa unică pentru cele 3 arme (`_fire_bullets`, `_aura_pulse`, `_sword_swing`) — au trecut toate de la `randf() < crit_chance_now()` + `× crit_mult` la `roll_crit()`.
- Plafonul scos din 2 locuri: `crit_chance_now()` (nu mai face `minf(1.0, …)`) și itemul **Adrenaline** din `levelup.gd` (nu mai face `min(1.0, …)`).

**Gotchas:**
- **Fiecare glonț dintr-o salvă își rulează propriul `roll_crit()`** (bucla din `_fire_bullets`) — la Twin Comets pot ieși crituri diferite pe gloanțe diferite, ca înainte.
- **Se compune cu Megane's Katana:** `crit_chance_now()` = Adrenaline (fix) + Katana (crește cu viteza), deci la viteză mare poți depăși 100% și fără să maxezi Adrenaline. Panoul de STATS arată doar partea fixă (`crit_chance`), care acum poate trece de 100%.
- Verificat pe 20.000 de trageri per prag: 100%→100% ×2, 200%→100% ×4, 150%→50/50 ×2/×4, 250%→50/50 ×4/×8. Exact.

---

## Session log — 2026-07-17 (Panou de statusuri în meniul de level-up)

**Done:**
- **Panou de STATS pe dreapta ecranului**, stil Binding of Isaac, apare când se deschide meniul de level-up. Aceeași ramă `Menu.png`, lipită de marginea dreaptă, centrată pe verticală (`levelup.gd`: `_build_stats_panel()` + `_refresh_stats()`, chemat din `_show_choices()`).
- **Culori pe stare:** gri = neschimbat față de valoarea de start, **verde** = mai bun, **roșu** = mai slab. 12 rânduri: Damage, Attack Speed, Crit, Projectiles, Pierce, Weapon Size, Knockback, Instakill, Move Speed, Max HP, HP Regen, Damage Taken.
- **Reperul („baza") = valorile cu care PORNEȘTI runda, DUPĂ meta-progresie** — prinse într-un snapshot `_stats_base` la finalul lui `player._ready()` (după META + slow-ul sabiei). Deci la nivelul 1 tot panoul e gri; meta cumpărat din magazin e deja inclus în bază, nu iese verde.
- **`player.stat_lines()`** produce rândurile gata formatate (`{label, value, state}`); `_stat_row()` decide starea comparând cu baza.
- **Layout:** meniul principal NU mai e centrat — e ancorat pe **stânga-centru** (`PRESET_CENTER_LEFT`, offset 40px), ca să lase loc panoului de STATS pe dreapta. Panoul de stats e lărgit la 350px (font 19) ca să încapă textul (înainte era 214px și tăia „Attack Speed 2.50/s").

**Gotchas:**
- **Attack Speed și Damage Taken sunt „lower_better":** valoarea brută (`fire_interval`, `contact_damage`) e mai bună când SCADE, așa că acolo comparația e inversată (`lower_better = true` în `_stat_row`). Restul: mai mare = mai bun.
- **Attack Speed se afișează ca rată** (`1/fire_interval`, „2.50/s") ca să crească vizual când tragi mai des, deși variabila din spate scade.
- **Crit afișat = `crit_chance` fix (Adrenaline)**, nu `crit_chance_now()` — partea dinamică de la Megane's Katana e 0 pe pauză (viteză 0), deci n-ar spune nimic util în panou.
- Verificat vizual: Damage roșu (Rabbit's Foot −5), Attack Speed/Crit/Projectiles/Max HP/Damage Taken verzi, restul gri. Panoul intră lângă meniu la 1152×648 fără să-l acopere; pe ecrane mai late (aspect `expand`) e și mai mult loc.

---

## Session log — 2026-07-17 (Knight's Power redenumit Last Resort)

**Done:**
- **Knight's Power → „Last Resort"** (`levelup.gd`, itemul cu `id` intern `seringa`). Iconiță nouă: `upgrade_26.png` → **`upgrade_35.png`** (un shot aprins, băgat de Răzvan în `Upgrades/`). Efectul (+7 Bullet damage) și raritatea (Uncommon) rămân neschimbate — doar numele afișat și poza. `id`-ul intern e tot `seringa`, deci `_apply()` nu se atinge.
- **Curățenie `weapons/`:** Răzvan a șters intenționat tot folderul `weapons/` (~10.200 fișiere, inclusiv „Super Pixel Effects Gigapack"). Commit separat de redenumire, ca să nu amestec istoricul.

**Gotchas:**
- Verificat vizual: am încărcat `upgrade_35.png` prin `levelup.gd` (128×128, textura OK) și l-am salvat ca screenshot înainte de commit — vezi [[joc-bzn-run-verify]].
- **Codex-ul rămâne de actualizat:** cardul „Knight's Power" trebuie redenumit „Last Resort" + iconiță nouă. (Sync separat, nu blochează commit-ul.)

---

## Session log — 2026-07-17 (The Nightclub înapoi la Epic)

**Done:**
- **The Nightclub: Rare → Epic** (`levelup.gd`, linia itemului). Se anulează schimbarea din `e6ccab0` (2026-07-16), unde fusese mutat Epic → Rare. **Grinder rămâne Common** — doar Nightclub s-a întors. Împărțirea pe rarități e acum: Legendary 3 · Epic 7 · Rare 6 · Uncommon 8 · Common 6 = 30.
- Codex-ul actualizat: cardul mutat din tier-ul Rare în Epic, cu border-ul Epic (violet), numărătorile pe tier corectate.

**Gotchas:**
- **Răzvan a raportat-o ca „bug în artifact".** Nu era: codex-ul arăta Rare fiindcă exact asta scria în cod — deci își făcea treaba. Bug-ul era în joc, adică în propria lui schimbare de pe 16 iulie, pe care o uitase. **Lecție: când zice „e bugat în codex", verifică întâi codul + `git log -S`** — codex-ul e oglinda codului, dacă îl „repari" doar pe el începe să mintă, și exact asta trebuie să nu facă.
- **Semnalul care a lămurit ce voia:** a cerut și `commit`. Codex-ul nu e în repo, deci un commit n-are sens decât dacă se schimbă codul → voia jocul schimbat, nu pagina.

---

## Session log — 2026-07-17 (încă 2 iteme: Megane's Katana · Panic Button)

**Done:**
- **Megane's Katana** (`upgrade_33.png`, **Rare**): șansa de critic crește cu viteza. Geamănul lui Diesel Power — aceeași intrare (viteza), altă monedă (crit în loc de damage). +15% crit la viteza de start pe luare, plafonat la 2× = **+30%**, **0 dacă stai pe loc**. Se adună peste criticul fix de la Adrenaline; `crit_chance_now()` plafonează totalul la 100%, ca Adrenaline.
- **Refactor mic:** raportul de viteză s-a mutat într-un singur `speed_ratio()`, folosit și de Diesel Power, și de Katana. `diesel_speed_cap` → **`speed_ratio_cap`** (nu mai e doar al lui Diesel). Toate cele 3 citiri de `crit_chance` din arme (`_fire_bullets`, `_aura_pulse`, `_sword_swing`) trec acum prin `crit_chance_now()`.
- **Panic Button** (`upgrade_34.png`, **Epic**): 100 damage fix la TOȚI inamicii de pe hartă, **o dată, chiar la luare**; după aia itemul e consumat. Damage fix intenționat: NU trece prin `damage_mult()` și nu poate da critic — e o detonare, nu o lovitură de armă. Are screen shake + numere roșii pe fiecare inamic.
- **Pool-ul e acum 30 de upgrade-uri.**

**Gotchas:**
- **Panic Button e un Epic slab și Răzvan știe.** Când îl iei ești deja pe PAUZĂ și în siguranță, deci nu te scapă niciodată dintr-o încercuire — practic îți dă doar XP-ul de pe ecran. I-am arătat variantele (se declanșează singur sub 20% viață / la fiecare level up) și **a ales-o pe cea literală**. Dacă se plânge că e mort la joc, se schimbă **CÂND** se declanșează, nu cât lovește.
- **Iconițele PAR inversate, dar așa le vrea:** `upgrade_33` (Megane's Katana) e **un câine**, `upgrade_34` (Panic Button) e **o katana însângerată**. L-am întrebat explicit pe 2026-07-17 și a zis să rămână așa. **Nu le „repara".**
- **`Fx` are `PROCESS_MODE_ALWAYS`** (`fx.gd:20`), de-aia numerele de damage de la Panic Button se văd deși `_apply()` rulează cu jocul pe pauză.
- **`_show_choices()` cade dacă pool-ul are sub 3 iteme** („Out of bounds get index '2'"). Nu e o problemă la joc (30 de iteme), dar dacă înlocuiești `lv.UPGRADES` într-un test ca să vezi un item anume, pune-i **cel puțin 3**.
- **Verificat pe jocul real:** Katana pe loc = 0, la viteza de start = 0.15, la 1.5× = 0.225, la 5× = 0.30 (plafonat); cu Adrenaline în mers = 0.30, pe loc = 0.15 (rămâne doar Adrenaline); cu crit fix 100% + Katana = 1.0 (plafonat). Panic Button: 4 inamici × 30 HP → toți la −70, morți, curățați de pe hartă; `crit_chance` / `bullet_damage` / `damage_mult` rămân neatinse după. Poză din meniul real: chenarele Epic/Rare și textele ies corect.

---

## Session log — 2026-07-17 (3 iteme noi: Theo's Wrath · Cigarette Pack · Diesel Power + `damage_mult()`)

**Done:**
- **`player.damage_mult()` — damage procentual DINAMIC**, gândit ca `weapon_size_scale()`: un factor derivat, citit la folosire, nu o valoare scrisă în player. Se aplică pe damage-ul **FINAL al lovturii, exact ca `crit_mult`**, în toate cele 3 locuri unde se calculează: `_fire_bullets` (`dmg_base`, plus explozia mage care iese din el), `_aura_pulse`, `_sword_swing`. Deci merge la **toate armele**, inclusiv Stingător și sabie. Dârele de foc/gheață NU îl primesc — nici upgrade-urile normale de damage nu le ating.
- **Theo's Wrath** (`upgrade_30.png`, **Uncommon**): +15% damage cât ești **sub 20% din viața maximă**, +10% la fiecare repetare (15 → 25 → 35%). Model „bază vs. stack" de la Hacksaw-uri (`_theo_taken`). Prag reglabil: `theo_hp_threshold`.
- **Cigarette Pack** (`upgrade_31.png`, **Common**): +5% damage, **aditiv** la fiecare luare (5 → 10 → 15%).
- **Diesel Power** (`upgrade_32.png`, **Uncommon**): damage cu cât mergi mai repede. `diesel_per_stack` (0.15) × stack-uri × `clamp(velocity.length() / _speed_base, 0, diesel_speed_cap)`. Pe loc = 0; la viteza de start = +15%; plafon la **2× viteza de start = +30%/stack**.
- **Pool-ul e acum 28 de upgrade-uri** (era 25). README zicea „23" în „Project structure" — era în urmă de două sesiuni, l-am corectat.

**Gotchas:**
- **De ce nu merge scris în `bullet_damage` ca la The Nightclub:** Theo's și Diesel depind de starea de ACUM (viața, viteza), care se schimbă în fiecare secundă — un `bullet_damage *= 1.15` s-ar lipi permanent. De-aia sunt multiplicator citit la fiecare lovitură.
- **Cigarette Pack ar fi putut fi scris direct, dar rotunjirea îl minte:** `round(10 × 1.05) = 11` = **+10%**, dublu cât scrie pe card, fiindcă `bullet_damage` e `int`. În `damage_mult()` se adună exact. Regula: procentele mici NU se compun într-un întreg mic.
- **`_speed_base` se ia în `_ready` DUPĂ `_apply_meta()`**, altfel cine are Speed maxat din magazin (+15/nivel, până la +120) ar porni cu bonusul lui Diesel deja pe jumătate dat. Așa, Diesel măsoară doar viteza câștigată ÎN rundă.
- **Plafonul lui Diesel e obligatoriu:** Alex's Protection face `speed *= 1.15` compus, la infinit — fără `diesel_speed_cap` bonusul creștea nelimitat.
- **Verificat pe jocul real**, toate valorile pică fix: Cigarette 1× = 1.05, 3× = 1.15; Theo's la 25% viață = 1.0, la 20% (pe prag) = 1.15, la 10% = 1.15, 3 luări = 1.35, te vindeci → se stinge la 1.0; Diesel pe loc = 1.0, la viteza de start = 1.15, la 1.5× = 1.225, la 5× = 1.30 (plafonat); toate trei odată, sub 20% HP, în mers = 1.35. Poză din meniul real: iconițele, chenarele și descrierile ies corect.
- **Ca să vezi output-ul unui test în consolă:** NU filtra cu `grep -v "^  "` — liniile mele de print încep cu spații și dispar toate. Am pățit-o azi și părea că testul nu printează nimic.

---

## Session log — 2026-07-17 (Twin Comets: +2 proiectile în loc de +1)

**Done:**
- **Twin Comets** (`levelup.gd`, `id="gloante_paralele"`, Legendary): descrierea „+1 Projectile" → **„+2 Parallel Projectiles"**, iar efectul din `_apply()` `p.bullet_count += 1` → **`+= 2`**. Deci `bullet_count` merge acum 1 → **3** → **5** → 7, nu 1 → 2 → 3.
- **N-a fost nevoie de nimic în `player.gd`.** Spawn-ul gloanțelor se centrează singur pe orice număr: `offset = (i - (bullet_count - 1) / 2.0) * bullet_spacing` (`player.gd` ~294). La 3 gloanțe → offset-uri −26/0/+26, la 5 → −52/−26/0/+26/+52. Cu număr **impar** ai mereu un glonț fix pe centru, pe traiectoria vechiului glonț unic — arată mai bine decât numărul par de dinainte (la 2 gloanțe, ținta din mijloc era ratată).

**Gotchas:**
- **Descrierea nu e sursa de adevăr, `_apply()` este** (scrie și în README, „Project structure" → `LevelUp`). Cele două se schimbă mereu ÎMPREUNĂ, altfel itemul minte în meniu — exact asta era problema aici, la nivel de intenție.
- **Verificat pe jocul real** cu o scenă temporară care instanțiază `main.tscn` și apelează `lv._apply("gloante_paralele", p)`: desc = „+2 Parallel Projectiles", `bullet_count` 1 → 3 → 5, offset-uri simetrice. `_apply` se poate chema direct, nu trebuie trecut prin meniu.
- **Codex-ul de upgrade-uri** (vezi Quick rules) a fost actualizat pentru Twin Comets în aceeași sesiune.

---

## Session log — 2026-07-16 (item nou: Alex's Protection · iconiță nouă la Stolen Halo)

**Done:**
- **Alex's Protection** (`levelup.gd`): iconiță `upgrade_28.png` (cască albă cu insigne), raritate **Rare** (aleasă de Răzvan; îi propusesem Epic, fiind două statistici fără dezavantaj), **+25% Max HP · +15% Move speed**. Efect: `p.upgrade_max_hp(int(round(p.max_hp * 0.25)))` (te și vindecă) + `p.speed *= 1.15`.
- **Procentele se COMPUN**, pe valoarea curentă, nu pe cea de start — ca la The Nightclub (`p.bullet_damage = int(round(p.bullet_damage * 1.35))`), care e singurul precedent de procent din joc. Verificat: max_hp 100 → 125 → 156 → 195, speed × 1.15 de fiecare dată.
- **Stolen Halo:** iconița `upgrade_27.png` → **`upgrade_29.png`** (aureolă cu flăcări albe, se potrivește mai bine). `upgrade_27.png` rămâne în repo, nefolosit.

**Gotchas:**
- **Iconițele noi trebuie IMPORTATE, altfel nu se văd în meniu.** Primul test a raportat `iconita exista: false` pentru AMBELE (`ResourceLoader.exists()` dă false pe un PNG neimportat) — meniul de level up ar fi afișat casete goale. Fix: `godot --headless --path . --import`. Valabil ori de câte ori Răzvan pune poze noi.
- **Ca să vezi un item în meniul REAL:** `UPGRADES` e `var`, nu `const` → îl poți înlocui cu exact itemele care te interesează, apoi `lv.open()`. `_show_choices()` amestecă pool-ul și ia primele 3, deci un pool de 3 le arată pe toate.
- **Verificat pe jocul real:** ambele iteme apar în meniu cu iconița, border-ul Rare și descrierea corecte (poză); 3 luări de Alex's Protection compun corect și vindecă odată cu max_hp; nu pun aureolă (doar Stolen Halo o face).

---

## Session log — 2026-07-16 (item nou: Stolen Halo + aureolă permanentă)

**Cererea lui Răzvan:** item nou „Stolen Halo", iconiță `upgrade_27`, raritate **Rare**, **+15 Damage / +5 Max HP**, stivuibil (fiecare luare adaugă la fel). Special: animația din `fx/halo fx` să stea **deasupra player-ului pentru totdeauna** după ce iei itemul.

**Done:**
- **Arta:** `fx/halo fx/Halo.png` (640×58) → **10 cadre de 64×58** (`frame_0..9.png`), aceeași metodă ca la sabie: detectez blocurile de desen pe coloane și aleg singura împărțire exactă a lui 640 fără desen tăiat (10×64 → 0 rupte; 4×160 → 2; 8×80 → 6). Cele 10 blocuri au ~350 px opaci fiecare — inel care se rotește.
- **Itemul** (`levelup.gd`): în `UPGRADES` + o ramură în `_apply` — `p.bullet_damage += 15`, `p.upgrade_max_hp(5)` (te și vindecă), `p.show_halo()`. Stivuiește natural, fiindcă `_apply` se cheamă la fiecare luare. `bullet_damage` merge la TOATE armele (sabia face `sword_base_damage + bullet_damage`).
- **Aureola** (`player.gd` `show_halo()`): `AnimatedSprite2D` copil al player-ului, `z_index = 1` (peste el), animație pe **loop**, la `halo_height = 76` px deasupra centrului. Se pune **O SINGURĂ dată** (`_halo` + `is_instance_valid`) — altfel, luând itemul de 3 ori, ai avea 3 aureole suprapuse în același loc.
- **Mărimea, ca la Firewalker/sabie:** `halo_size = 54` px pe ecran, scara derivată (`halo_size / HALO_FRAME_W`), nu multiplicator → schimbi arta, mărimea rămâne.
- **Poziția, reglabilă:** `halo_side` (− = stânga pe ecran, acum **−2** la cererea lui Răzvan) și `halo_height` (76).

**Gotchas:**
- **Nu există `levelup.tscn`** — `levelup.gd` e pe un `CanvasLayer` din `main.tscn`. Ca să-l testezi, instanțiază `main.tscn` și ia-l cu `get_tree().get_first_node_in_group("levelup_menu")` (player-ul: grupul `"player"`).
- **Poziția aureolei vine dintr-o măsurătoare:** sprite-ul player-ului e 124×124 cu creștetul la y=31, deci capul e la 31 px deasupra centrului → ×2 (scale-ul player-ului din `main.tscn`) = 62 px reali. De-aia 76 lasă un spațiu firesc. Ca la orice copil al player-ului, poziția/scara se împart la `scale.x`.
- **La aureolă offset-ul pe ecran (nerotit) e CORECT** — invers decât la sabie. Player-ul nu se rotește (are 8 sprite-uri de direcție), iar aureola trebuie să stea mereu deasupra capului, deci `halo_side`/`halo_height` NU se rotesc cu privirea. Nu „repara" asta după modelul sabiei.
- **PowerShell nu face diferență între majuscule și minuscule la variabile:** `$W` (lățimea imaginii) și `$w` (lățimea cadrului) sunt ACEEAȘI variabilă → lățimea se împărțea cumulativ (640 → 320 → 80 → 16 → 2) și detecția de cadre dădea rezultate absurde. Folosește nume distincte, nu doar altă capitalizare.
- **Verificat pe jocul real** (main.tscn, nu mock): itemul apare în `UPGRADES` cu datele corecte, iconița există, raritatea `rare` e definită; 3 luări → dmg +45 (15×3), max_hp +15 (5×3), **o singură aureolă**; aureola: 10 cadre, loop, y = −76 px reali, lățime 54 px, z=1. Plus poză cu aureola pe toate cele 4 direcții.

---

## Session log — 2026-07-16 (BUG: hitbox-ul sabiei rămânea în urmă la size up)

**Reclamația lui Răzvan:** „când iau iteme de size up parcă nu se ține bine hitboxul." Avea dreptate.

**Cauza:** `_sword_offset()` așeza sprite-ul la `Vector2(sword_reach, sword_lateral) * weapon_size_scale()`, dar `_sword_hit_rect()` aduna `sword_reach` / `sword_lateral` **NESCALATE**. La `weapon_size_scale() == 1` cele două coincid — de-aia a trecut de toate testele de până acum, făcute pe player fără upgrade-uri. Cu Pufferfish/Rat's Burger, arta pleacă în față și dreptunghiul rămâne pe loc:

| wss | hitbox ajungea la | arta ajunge la | lipsă |
|---|---|---|---|
| 1.00 | 92 | 92 | 0 |
| 1.37 | 110.5 | 126.1 | 16 px |
| 2.26 | 155.2 | 208.2 | 53 px |
| 4.19 | 251.7 | 385.8 | 134 px (≈ o treime din tăietură) |

**Fix:** `_sword_offset_art()` — ancora în sistemul artei, scalată o singură dată, **sursă unică** pentru sprite (`_sword_offset(dir)` = ea, rotită), pentru hitbox și pentru debug. Cele două nu se mai pot despărți fiindcă pleacă din același loc.

**Gotchas:**
- **Un `weapon_size_scale()` uitat într-un singur loc nu se vede la scale 1.** Orice mărime nouă a sabiei trebuie testată la MAI MULTE valori de `weapon_size_px` / `weapon_size_mult`, nu doar pe player curat. Toate testele mele de azi (0 nepotriviri, 100% acord pe pixeli etc.) rulaseră la wss = 1 și au ratat bug-ul complet.
- **Verificat acum la 4 mărimi** (wss 1.00 / 1.37 / 2.26 / 4.19): marginea din față și cea laterală a dreptunghiului cad **exact** pe cel mai depărtat pixel al artei (diferență 0.00 la toate). Plus test viu la wss = 4.19: inamicul de la vârf e lovit, cel de dincolo nu, iar cel de la x=100 (unde se oprea bug-ul) e lovit acum.

---

## Session log — 2026-07-16 (Cursed Sword: hitbox = dreptunghi croit pe anvelopa animației)

**Cererea lui Răzvan:** întâi „vreau hitbox 1:1 cu sprite-ul", apoi s-a răzgândit: „nu vreau 1:1, vreau să dea damage și între animație și player. Fă-l un dreptunghi care începe din fața playerului și se termină la laterale și în față la cel mai depărtat pixel din toată animația (hitboxul stă constant acea formă)".

**Done:**
- **Hitbox = dreptunghi FIX**, în sistemul artei (x = înainte, y = lateral), rotit cu privirea:
  - **înapoi: 0** (de la player) → prinde golul dintre el și semilună, ăsta era scopul;
  - **în față: 92 px** = `(32 − env.x_min) × scale + sword_reach`, adică fix cel mai depărtat pixel;
  - **lateral: −63.25 … +66.75** (ușor asimetric, cât e și arta).
  Nu se schimbă pe parcursul măturatului — aceeași formă tot timpul.
- **Anvelopa se MĂSOARĂ la pornire** (`_masoara_arta_sabiei`), din pixelii opaci ai tuturor cadrelor → `_sword_env` = `[P: (12,2), S: (39,53)]` în pixeli de artă. Nu e scrisă de mână: schimbi arta, se recalculează singură. Fiind în pixeli de artă, urmează automat `sword_size`/`sword_reach`/`sword_lateral`.
- **Scoase:** BitMap-urile per cadru (`_sword_masks`), `_sword_pixel_hit`, `_sword_coarse_radius`, recuperarea de cadre sărite (`ultim_cadru`) — dreptunghiul fiind constant, nu mai depinde de ce cadru se desenează.

**Istoricul formelor (util dacă se mai schimbă):** con ±81° stricat (14% tăietură reală) → con potrivit ±42° (42%) → disc (36%, apoi 29% cu arta nouă, mai subțire) → 1:1 pe pixeli (exact, dar lăsa gaura dintre player și tăietură fără damage) → **dreptunghi pe anvelopă**. Arii: disc 17.765 px², dreptunghi **11.960 px²** (92×130), 1:1 doar 5.131 px².

**Gotchas:**
- **Sprite-ul e rotit cu −PI** (arta are fața spre vest), deci în cadru un **x MIC = departe în FAȚĂ**. De-aia marginea din față se calculează din `env.position.x` (minimul), nu din `env.end.x`. Semnele se inversează și pe lateral.
- **`Rect2.end` e exclusiv** — pixelul cel mai de jos e `end.y - 1`, de-aia apare `-1.0` în calculul lui `y1`.
- **Verificat:** dreptunghiul calculat de joc = `[P: (0, −63.25), S: (92, 130)]`, exact cât dă formula pe mână din anvelopă; grilă de 2576 de puncte → 759 loviți (759 × 16 px² = 12.144 ≈ aria 11.960 ✓); cel mai apropiat lovit la **x = 0** (chiar de la player); punctul din gaură (x=15) **ia damage** — cererea principală; 0 loviți de două ori; toate 8 direcțiile identice.
- **La testele cu grilă mare: pune `p.contact_damage = 0`.** 2208 dummy-uri în grupul `enemy` îl omoară pe player instant → Game Over → scena se reîncarcă → `_ready` rulează iar. M-a costat: vedeam „TEST PORNIT" de 11 ori și niciun rezultat.

---

## Session log — 2026-07-16 (Cursed Sword: tăietura se rotește după privire cât mătură, ca în Megabonk)

**Cererea lui Răzvan:** „știi cum e făcută sabia în Megabonk? animația se mișcă constant cu playerul… aici dacă începe animația la west și te miști spre east rămâne la fel."

**Done:**
- **Tăietura nu mai e o poză înghețată.** Era copil al player-ului, deci se **muta** cu el (translație), dar direcția rămânea cea de la pornire. Acum `_update_slashes()` (din `_process`) îi rescrie în fiecare cadru poziția, rotația și scara după `_sword_dir()` de ACUM → sabia se întoarce odată cu tine cât mătură.
- **Damage-ul urmărește și el, altfel introduceam bug-ul de azi întors pe dos:** dacă doar vizualul urmărea, tăiai un inamic spre est și el nu lua damage, fiindcă lovitura fusese rezolvată instant spre vest. Acum tăietura e **vie cât ține animația**: `_sword_damage_pass()` recalculează centrul din privirea curentă la fiecare cadru.
- **Fiecare inamic e lovit o SINGURĂ dată per tăietură** — `t["loviti"]` ține **instance ID-urile** (nu nodurile: inamicul poate muri între treceri). Fără asta ar fi luat damage în fiecare cadru. Tăietura următoare îi poate lovi din nou (verificat). Și zguduitura de crit e o singură dată per tăietură (`t["shake"]`), nu una pe cadru.
- Structura: `_sword_swing()` doar dă zarurile (dmg + crit), pornește vizualul și înregistrează tăietura în `_slashes`; restul se întâmplă în `_update_slashes` / `_sword_damage_pass`.

**Gotchas:**
- **Verifică `is_instance_valid()` ÎNAINTE de a atribui într-o variabilă tipată.** `var nod: AnimatedSprite2D = t["nod"]` crapă cu *„Trying to assign invalid previously freed instance"* dacă animația s-a terminat și nodul s-a auto-șters (`animation_finished` → `queue_free`). Testul a prins-o: eroarea abandona funcția înainte de `remove_at`, deci tăieturile moarte se adunau în listă (`taieturi active ramase: 1` în loc de 0).
- **Consecință de balans (mică, intenționată):** înainte, damage-ul se dădea o dată, în clipa pornirii. Acum inamicii care **intră** în tăietură cât mătură sunt și ei loviți (o dată). Sabia e un pic mai bună, dar plafonul „un hit per inamic per tăietură" rămâne.
- **Verificat cu o SINGURĂ tăietură, rotindu-ne în timpul ei:** pornită spre est (est=1, vest=0 — vest era la 84 px, în afara razei de 75), răsucire spre vest → vest=1, apoi spre nord → nord=1, fiecare exact o dată; la final `_slashes` gol; a doua tăietură lovește est din nou (est=2). Plus 3 poze din aceeași tăietură (est → sud → vest) care arată sprite-ul și cercul întorcându-se împreună.

---

## Session log — 2026-07-16 (Cursed Sword: artă nouă + rescrisă pe modelul Firewalker)

**Cererea lui Răzvan:** artă nouă pusă peste cea veche, de tăiat iar în cadre; e orientată spre **vest**; tăietura să fie **EGALĂ în toate direcțiile**; „poți să o gândești cum e făcut firewalker că mereu stă aceeași mărime".

**Done:**
- **Artă nouă tăiată:** `fx/cursed sword fx/cursed sword fx.png` (768×55) → **12 cadre de 64×55** (`frame_0..11.png`). Lățimea de cadru NU e ghicită: am detectat blocurile de desen pe coloane și am ales singura împărțire exactă a lui 768 la care **niciun desen nu calcă peste graniță** (12×64 → 0 blocuri tăiate; 8×96 → 3, 16×48 → 6). Vechile `frame_0..9` (64×60) și `cursed sword anim real.png` — șterse/înlocuite.
- **Rescrisă pe modelul Firewalker** (`firetrail.gd`), exact cum a cerut:
  - `sword_size` în **PIXELI** (nu multiplicator) → `a.scale = _sword_visual_size() / SWORD_FRAME_W`, ca `size / 32.0` acolo. Schimbi arta, mărimea rămâne.
  - **Raza de damage DERIVATĂ:** `_sword_radius() = sword_size × sword_hit_ratio`, ca `radius = size * 0.4` acolo. `sword_hit_ratio = 0.47` = cel mai depărtat pixel al artei (30.1) / lățimea cadrului (64) → e o **proporție**, deci rămâne corectă la orice mărime. **Asta vindecă boala de toată ziua:** arta și hitbox-ul nu se mai pot despărți, fiindcă hitbox-ul se calculează din mărime.
  - **Cadrele au fața spre VEST:** `a.rotation = dir.angle() - PI + sword_art_rotation`, ca `direction.angle() - PI` acolo.
- **Butoane simplificate:** `sword_art_reach`/`sword_art_lateral`/`sword_hit_reach`/`sword_hit_lateral`/`sword_hit_radius`/`sword_scale` → **`sword_size`, `sword_reach`, `sword_lateral`, `sword_hit_ratio`**. Un singur `_sword_offset(dir)` pentru artă + hitbox + debug.
- **Arta nouă e aproape simetrică:** la `lateral = 0` mijlocul măturatului e la −1.1° (cea veche era la −13.8° și cerea 12 px de corecție). `sword_lateral = 3` → 0.2°. 0 pixeli în spatele player-ului la reach 42.
- **Reglajul lui Răzvan, salvat:** `player.tscn` avea `sword_scale = 2.5` și `sword_art_lateral = 0.0` (reglate de el în Inspector). Redenumind butoanele, liniile alea au rămas **moarte — și Godot le ignoră în tăcere, fără nicio eroare**. I-am dus alegerea mai departe: 2.5 × cadru 64 = **160 px** → `sword_size = 160` (verificat: dă `scale = 2.500`, exact ce avea). Liniile moarte scoase din `player.tscn`.

**Gotchas:**
- **La redenumirea unui `@export` folosit ca override într-un `.tscn`, Godot NU se plânge** — override-ul dispare pur și simplu. Verifică `git diff` pe `.tscn` după orice redenumire de export, altfel arunci reglajele omului fără să afle nimeni.
- **Verificat prin rotație:** caiet de 10 puncte în sistemul est, rotit pe fiecare din cele 8 direcții → **toate identice cu estul**. Plus verificare pe pixelii pozei: **0 pixeli de artă în afara cercului** (cel mai depărtat 32.0 din limita 36.2).
- **Fitul discului a scăzut la 29%** (arta veche + disc: 36%, con reparat: 42%, hitbox stricat inițial: 14%) — arta nouă e mai subțire (anvelopă 821 px de artă față de 1229). Se strânge din `sword_hit_ratio` dacă vrea mai precis.
- **La testul cu poză: eliberează player-ul precedent ȘI așteaptă să-i expire tăietura (~0.55s) înainte de următoarea poză** — altfel prinzi două slash-uri suprapuse și două camere, și măsurătoarea pe pixeli iese aiurea (am pățit-o: „3367 pixeli verzi, toți în afara cercului").

---

## Session log — 2026-07-16 (Cursed Sword: butoane manuale + debug draw)

**Reclamația lui Răzvan:** „dă-mi butoane să schimb eu manual și cum arată sprite-ul și cum e pus hitbox-ul că le-ai făcut de sânge." Avea dreptate: valorile erau exporturi, dar **cuplate** — îi tot spuneam „nu umbla la reach/scale că trebuie remăsurată raza". Adică nu le putea regla singur.

**Done:**
- **Arta și hitbox-ul, decuplate.** `sword_reach`/`sword_lateral` → despărțite în `sword_art_reach`/`sword_art_lateral` (unde se desenează) și `sword_hit_reach`/`sword_hit_lateral` (unde lovește discul). Implicit au aceleași valori (42 / 12), dar acum le poate depărta oricât. Două funcții separate: `_sword_art_offset(dir)` și `_sword_hit_offset(dir)`.
- **`sword_debug: bool`** — desenează live, peste joc, cercul roșu al hitbox-ului + crucea albastră a ancorei artei + linia albă a direcției de privire. `_draw()` pe player + `queue_redraw()` în `_process` cât e pornit. **Ăsta e răspunsul real la reclamație:** nu poate regla ce nu vede. Cu el, dacă mută arta și uită hitbox-ul, VEDE că s-au despărțit.
- **`sword_anim_speed`** (nou, via `a.speed_scale`) — cât de repede se joacă tăietura; 22 fps era hardcodat. Clampat la min 0.01, că 0 ar îngheța tăietura pe ecran pentru totdeauna.

**Gotchas:**
- **`_draw()` pe player e la `scale = 2`** (din main.tscn) → împarte TOT la `scale.x`: și coordonatele, și grosimile de linie, și raza. Altfel desenezi la dublu.
- **Decizia de design:** i-am dat controlul manual cerut, cu riscul să despartă arta de hitbox și să reintroducă bug-ul inițial. Compensat prin debug draw — controlul vine la pachet cu unealta care-i arată consecința. Valorile din fabrică rămân cele măsurate.
- **Verificat:** hitbox mutat manual (reach 100, rază 25) → 5 puncte testate, **0 nepotriviri**; poze cu arta și hitbox-ul mutate separat, ca să se vadă că nu mai sunt legate. Plus o verificare pe pixeli a pozei: la valorile din fabrică, **0 pixeli de artă în afara cercului roșu** (cel mai depărtat la 33.9 din 39.2 px de ecran) → raza 56 chiar acoperă arta.

---

## Session log — 2026-07-16 (Cursed Sword: identică în toate direcțiile · hitbox = disc · sub player)

**Done:**
- **Tăietura arată identic în toate cele 8 direcții**, doar rotită (cerință explicită a lui Răzvan: „vreau să arate EXACT la fel ca la east"). Tot ce poziționează arta stă acum în sistemul ARTEI și **se rotește** cu privirea: `_sword_offset(dir) = Vector2(sword_reach, sword_lateral).rotated(dir.angle()) * weapon_size_scale()`. Funcția e folosită **și** de vizual, **și** de hitbox → nu se mai pot despărți.
- **`sword_screen_offset` scos.** Îl adăugasem (nerotit, ca sabia să pară ținută în stânga) și exact asta strica: nerotit înseamnă că la est trăgea tăietura spre player, la vest o împingea în față, la nord o dădea lateral. **Nu adăuga offset-uri „pe ecran" la o artă care se rotește.** Efectul lui la est (−20 px) a fost băgat în `sword_reach`: 62 → **42**.
- **Hitbox: con → DISC.** La `reach = 42` arta îl învăluie pe player (5.2% din pixeli, coada, ajung ~12 px în **spatele** lui, ascunși sub sprite-ul lui) → un con din față n-o mai poate descrie: fitul dă ±180°, adică ai lovi tot în jur. Acum: disc de rază **`sword_hit_radius` = 56** (cel mai depărtat pixel de artă față de centrul ei) în jurul lui `global_position + _sword_offset(dir)`. `sword_range` și `sword_arc_dot` **eliminate**.
- **Discul e mai cinstit decât pare:** măsurat pe anvelopa măturatului (uniunea celor 10 cadre = 3.552 px²) — con vechi (135, ±81°): **14%** tăietură reală; con reparat (108, ±42°): **42%**; disc (r 56): **36%**. Deci −6 puncte față de con, dar se rotește corect prin construcție. Aria: 9.852 px² (față de 8.465 la con), deci sabia e un pic mai puternică decât azi-dimineață.
- **Cazul special „inamic lipit de tine" a dispărut** — nu mai e nevoie de el: discul e centrat în față, deci acoperă natural și `distance == 0`. Knockback-ul împinge dinspre **player**, nu dinspre centrul tăieturii.
- **Tăietura trece sub player:** `a.z_index` 2 → **−1**. E frate cu `AnimatedSprite2D`-ul player-ului (z 0), deci −1 îl lasă mereu în spate. Înainte, la nord, slash-ul era desenat peste cap și-l acoperea.

**Gotchas:**
- **Regula de aur:** orice poziționare a tăieturii trebuie să fie un vector în sistemul artei, rotit cu `dir.angle()`. Un offset nerotit rupe consistența pe direcții. Dacă vrei sabia „în mâna stângă", asta se face din `sword_lateral` (care se rotește), nu dintr-un offset de ecran.
- **`sword_reach` minim ca arta să rămână toată în față = 54.4** (jumătatea lățimii artei: 32 px × `sword_scale` 1.7). Sub atât, coada trece în spatele player-ului și modelul de con devine invalid — de-aia e disc acum.
- **Verificat prin rotație, nu prin ochi:** caiet de 15 puncte definit în sistemul est, rotit pentru fiecare din cele 8 direcții, cu un inamic fals în fiecare punct → **toate 8 dau exact aceeași listă de lovituri ca estul**. Plus o poză cu toți 8 player-ii tăind simultan. Șterse după.
- **Camera2D dezactivată pe toți player-ii dintr-o scenă de test** → viewport-ul cade pe transformul implicit (origine în colțul stânga-sus), deci coordonatele negative ies din ecran.

---

## Session log — 2026-07-16 (Cursed Sword: hitbox potrivit pe artă · tăietură centrată pe privire)

**Reclamația lui Răzvan:** „la cursed sword arată cam dubios și hitboxul nu e bun".

**Done:**
- **Hitbox-ul lovea ~3× mai mult decât se vedea.** Măsurat pixel cu pixel pe cele 10 cadre (System.Drawing, alpha > 20, trecute prin exact formula din `_spawn_sword_slash`): arta ajunge la **107 px** de player și stă într-un con de **±62°**. Codul avea `sword_range = 135` și `sword_arc_dot = 0.15` (**±81°** — aproape o semilună, care trecea pe lângă umeri în spate). Acum `sword_range = 108`, `sword_arc_dot = 0.75` (**±42°**) — măsurate pe artă *după* centrare.
- **Tăietura stătea strâmb** (ăsta era „dubios"-ul, confirmat de Răzvan): arta e desenată asimetric — măturatul mergea de la **−62°** (deasupra axei privirii) până la **+34°**, deci cu mijlocul la −13.8°. Fix: **`sword_lateral = 12.0`** (export nou), offset perpendicular pe privire → sweep **−41°..+42°**, mijloc 0.2°.
- **`sword_art_rotation` NU rezolvă asta** (de-aia era 0 și degeaba): rotește sprite-ul în jurul centrului **lui**, care stă la 62 px în fața player-ului, așa că 24° de rotație mută mijlocul sweep-ului cu doar 3.5°. Măturat 0..24° ca să confirm. Ce mișcă arcul e offset-ul lateral, nu rotația.
- **Bug la distanță ~0:** inamicul lipit de player nu era tăiat niciodată — `to_enemy.normalized()` dă `(0,0)` → `dot = 0` < prag. Acum `dist > 4.0` sare peste verificarea de con. La fel knockback-ul primea vector zero → cade înapoi pe `dir`.

**Gotchas:**
- **Offset-ul se scrie în sistemul ARTEI, apoi se rotește:** `Vector2(sword_reach, sword_lateral).rotated(dir.angle())`. Așa tăietura arată identic în toate cele 8 direcții.
- **`sword_reach` / `sword_scale` / `sword_lateral` / `sword_range` / `sword_arc_dot` sunt un PACHET** — ultimele două ies din măsurători pe artă cu primele trei fixate. Schimbi unul → remăsori tot (scriptul: încarcă cadrele, `local = (px − w/2, py − h/2) × sword_scale`, `+ (reach, lateral)`, apoi `atan2`/lungime față de player).
- **Consecință de balans (netratată):** aria acoperită a scăzut de la ~25.900 px² la ~8.400 px² (**~1/3**). Sabia lovește acum doar ce se vede → e sensibil mai slabă. De compensat separat dacă zice Răzvan (`sword_base_damage`, sau `sword_scale` mai mare + remăsurat, sau `sword_slow_start`).
- **Verificat** cu scenă de test temporară: 72 de inamici falși la unghiuri/distanțe știute → **0 nepotriviri** față de formula așteptată, simetrie ±30/±41/±50 confirmată; plus un render cu toate cele 10 cadre suprapuse peste axa privirii (înainte/după). Ștearsă după.
- **NU edita `.gd` cu .NET `WriteAllLines`** — scrie CRLF, iar repo-ul e pe LF (întreg fișierul apare modificat). Și atenție la tab-uri: corpul unui `if` dinăuntrul lui `for` e la **3 tab-uri**.

---

## Session log — 2026-07-16 (armă nouă: Cursed Sword · animație atașată de player · tweak-uri iteme)

**Done:**
- **Armă nouă „Cursed Sword"** — al 4-lea `weapon_type` selectabil în meniu (`menu.gd` `WEAPONS`, `id="sword"`, iconiță `weapons_icons/cursed sword.png`). Taie automat în **direcția în care se uită** player-ul (nou `_facing` în `player.gd`, actualizat în `_physics_process` la mișcare). Lovește **toți inamicii din conul din față** (`to_enemy.normalized().dot(dir) >= sword_arc_dot`, în raza `sword_range * weapon_size_scale()`), damage = `sword_base_damage + bullet_damage` + crit (ca aura) + instakill (ca glonțul). Dispecer în `_fire()`: `elif weapon_type == "sword": _sword_swing()`.
- **Slow la început + scalare cu player-ul:** la selectarea sabiei, `fire_interval *= sword_slow_start` (1.9) O SINGURĂ dată în `_ready` (înainte de crearea `fire_timer`). Attack-speed upgrade-urile (Rabbit's Foot, The Nightclub, Rolling Papers) o accelerează/încetinesc după, fiindcă folosește același `fire_interval`. Scalează și cu damage/crit/knockback/instakill/mărime (Pufferfish/Rat's Burger via `weapon_size_scale()`).
- **Animația de tăiere = COPIL al player-ului** (`_spawn_sword_slash` face `add_child(a)` pe player, NU pe `get_parent()`/World) → tăietura îl urmează când merge (sabia „mereu în mână"), nu mai rămâne în urmă. Poziția/scara se împart la `scale.x` al player-ului (×2 în `main.tscn`) ca `sword_reach`/`sword_scale` să fie în pixeli reali. Rotită cu `dir.angle() + sword_art_rotation`.
- **Arta sabiei:** `fx/cursed sword fx/cursed sword anim real.png` (640×60, înlocuită de Răzvan — prima versiune arăta urât) tăiată în **10 cadre uniforme** de 64×60 (`frame_0..9.png`, System.Drawing), încărcate cu `_load_fx_frames("res://fx/cursed sword fx", 22.0, false)`.
- **Tweak-uri iteme** (`levelup.gd`): **Rabbit's Foot** −5 dmg / **+25%** attack speed (era +10% → `upgrade_fire_rate(0.80)`, adică 1/1.25); **Grinder** Rare→**Common**; **The Nightclub** Epic→**Rare**; **Syringe → „Knight's Power"** cu iconiță nouă `upgrade_26.png` (id intern rămâne `seringa`).

**Gotchas:**
- **Un copil al player-ului moștenește `scale = 2`** (din `main.tscn`) → orice „pixeli reali" pe un efect atașat de player trebuie împărțiți la `scale.x` (ca la sfera mage, care e copil de glonț cu scale 0.1).
- **Spritesheet nou tăiat = importă înainte de rulare** (`godot --headless --path . --import`), altfel `load()` nu găsește cadrele.
- **PowerShell + System.Drawing:** `New-Object System.Drawing.Rectangle($i*$fw, ...)` a crăpat cu erori de tip; fix = variabile `[int]` separate + `New-Object ... -ArgumentList`. Bitmap-ul se citește cu `-ArgumentList $path`.
- **Verificat rulând** o scenă de test temporară (weapon="sword", player scale 2, 4 inamici în con) → screenshot la mijlocul animației + `print` care confirmă că slash-ul e copil al player-ului. Ștearsă după.

**De reținut (workflow):** ~~după ce termin, actualizez CLAUDE.md + README și dau push pe `main` fără să mai întreb~~ — **DEPĂȘIT din 2026-07-16:** docs + commit local rămân automate, dar **push doar la cererea explicită a lui Răzvan**. Vezi regula din capul fișierului.

---

## Session log — 2026-07-15 (gloanțe noi + sinergie combinat · stingător foam+hitbox · instakill + 5 iteme · rebalans)

**Done:**
- **Sfera mage (mage_orb) filtru mov:** `orb.modulate = Color(0.72, 0.45, 1.0)` în `_make_mage_orb` (`player.gd`) — se asortează cu explozia `mage_boom`. Doar vizual.
- **Stingător — animație de spumă nouă:** `stingator/stingator.png` (896×63) tăiat în **14 frame-uri** de 64×63 (`frame_0..13.png`, cu System.Drawing). `_build_foam_frames` încarcă acum `frame_%d` (14, 24fps) în loc de vechile `foam_*` (care nu existau → cădea pe fallback gradient).
- **Stingător — un singur reglaj `@export foam_scale` (1.25) + hitbox = sprite MEREU:** `radius = (aura_base_radius + level*aura_growth + weapon_size_px) * weapon_size_mult * foam_scale`, iar sprite-ul aurei = `radius*2/64` (am scos multiplicatorul vizual separat). Amândouă pornesc din același `radius`, deci nu se pot desincroniza.
- **Pufferfish/Rat's Burger măresc și dârele:** `patch.size *= weapon_size_scale()` în `_drop_fire`/`_drop_ice`/`_drop_god`. La bază factorul = 1.0 (fără upgrade nu schimbă nimic). `size` scalează și vizualul, și raza de damage a dârei.
- **Rebalans upgrade-uri** (`levelup.gd`): Papers→**Rolling Papers** (`upgrade_fire_rate(0.90)` = +10% attack speed; merge și la stingător fiindcă pulsul folosește `fire_timer`); Pufferfish +30→**+10**; Syringe +12→**+7**; **Adrenaline** dă critic și pe aură (roll de `crit_chance` în `_aura_pulse`); Parallel Bullets→**Twin Comets** (`upgrade_19.png`, „+1 Projectile"); Knockback Stick → `upgrade_22.png`.
- **5 iteme noi** (pool = **23**): **Rabbit's Foot** (`upgrade_20`, uncommon: -5 dmg / +10% atk speed), **Mike's Hedgehog** (`upgrade_21`, epic: reflect 100% din contact damage, o dată la 3s), **The Nightclub** (`upgrade_25`, epic: +35% dmg / -35% atk speed), **Rusty Hacksaw** (`upgrade_24`, uncommon: 1% instakill, +0.5%/stack), **Doctor's Hacksaw** (`upgrade_23`, legendary: 5% instakill, +2%/stack).
- **Instakill:** `@export instakill_chance` pe player → pasat glonțului (`bullet.instakill_chance`) → în `bullet.gd _on_body_entered` roll `randf() < instakill_chance`; la succes scoate `body.hp` dintr-o lovitură (număr roșu mare). Ambele Hacksaw cumulează în același `instakill_chance` (bază la prima luare via `_rusty_taken`/`_doctor_taken`, increment la fiecare stack).
- **Mike's Hedgehog** reflectă în `_take_contact_damage` (acolo player-ul iterează inamicii care-l ating), cooldown 3s cu `Time.get_ticks_msec()` (`_hedgehog_next`).
- **Gloanțe noi:** `bullets/bullet normal.png` (pistol, în `bullet.tscn`) + `bullets/bullet_combined.png` (`bullet_combined.tscn`, nou). Vechile `bullet1/2/3.png` nu mai există. **Weird Concoction/Stroh nu mai schimbă glonțul individual** (păstrează doar statul); luate **ÎMPREUNĂ** → glonțul combinat (violet). Flaguri `has_weird`/`has_stroh` pe player; sinergie ca Godwalker.

**Gotchas:**
- **Orientarea sprite-ului de glonț:** arta nouă e desenată spre **NE**, dar `set_direction` presupune „nord". Fix corect = rotește **Sprite2D-ul copil** cu `-0.7853982` (-45°) direct în `.tscn`, ca ansamblul să arate „spre nord"; **nu** atinge `set_direction` (`+PI/2`), altfel strici mage/orice alt glonț desenat spre nord. Matematic: NE = -PI/4, nord = -PI/2, offset = -PI/4.
- **PowerShell 5.1 citește fișierele fără BOM ca ANSI** → strică diacriticele (ș/ț/î/ă → mojibake „È™ansÄƒ"). Pentru text românesc procesat cu PowerShell (ex. editarea codexului): ține-l într-un fișier **UTF-8 separat** (JSON) și citește-l cu `[IO.File]::ReadAllText(path, [Text.Encoding]::UTF8)`, scrie cu `New-Object System.Text.UTF8Encoding($false)` (fără BOM). **NU pune diacritice în literalele din `.ps1`** — se corup la citirea scriptului.
- **Ceas headless:** `Time.get_ticks_msec()` (timp real) și `create_timer` (timp de joc, pe delta de frame) **diverg în `--headless`**. Un test de cooldown cu `create_timer` dă fals-negativ. Așteaptă pe același ceas ca și codul: `var t0 := Time.get_ticks_msec(); while Time.get_ticks_msec()-t0 < N: await get_tree().process_frame`.
- **Codexul (artifact)** e HTML mare cu iconițe base64, grupat pe tier-uri de raritate (`<!-- EPIC -->` etc. sunt ancore bune). Ramele de raritate sunt base64 **partajate per raritate** — extrage una per raritate din codexul existent și refolosește. Se updatează pe același URL cu param. `url=`.

**Probleme rezolvate** (erau în „cunoscute" la 2026-07-14):
- **Stingătorul avea 4 upgrade-uri moarte** → acum doar **2** (Twin Comets, Drill). Rolling Papers (attack speed) și Adrenaline (crit pe aură) funcționează acum cu el.

---

## Session log — 2026-07-14 (efecte Mage Staff · damage stingător · redenumiri upgrade-uri · mărimea armei)

**Done:**
- **Sfera mage era INVIZIBILĂ** (bug, nu lipsă de feature). `_make_mage_orb` (`player.gd`) o adăuga drept **copil al glonțului**, iar rădăcina glonțului are `scale = Vector2(0.1, 0.1)` în `bullet.tscn` → `0.7 × 0.1 × 64px ≈ 4px` pe ecran. Acum sfera **compensează scara părintelui** (`orb.scale = (mage_orb_size / lățime_cadru) / bullet.scale.x`), deci `@export var mage_orb_size` (35) înseamnă **pixeli reali pe ecran**.
- **Explozia mage** reglabilă din `BOOM_VISUAL_SCALE` (`bullet.gd`, acum `1.3 / 3.0`) — scrisă ca fracție ca să se vadă cele două reglaje separat („÷3, apoi ×1.3"). **Doar vizual**: `explosion_radius` (110, zona de damage) e neatinsă. Măsurat: sferă 35px, explozie 95px.
- **Stingător: damage de bază 15/puls** (`aura_damage` 6→10). Formula reală e `aura_damage + int(bullet_damage * 0.5)` → 10+5=15 la start; jumătatea din `bullet_damage` e **intenționată** (fără ea, stingătorul n-ar scala cu niciun upgrade de damage).
- **Redenumiri + iconițe noi** (`levelup.gd`): Cocaine→**Weird Concoction** (`upgrade_15.png`), Weed→**Wine** (`upgrade_13.png`), Hook→**Knockback Stick** (`upgrade_12.webp`), OCB Papers→**Papers**; poze noi la Drill (`upgrade_16.png`) și Double Dose (`upgrade_14.png`). Scos „Bullet 2"/„Bullet 3" din descrierile Weird Concoction/Stroh (efectul de schimbare a glonțului a **rămas**).
- **Mărimea ARMEI = stat nou, comun** (`player.gd`): `weapon_size_px` (Pufferfish, +30px) + `weapon_size_mult` (Rat's Burger, ×1.30), combinate în `weapon_size_scale()` raportat la `BULLET_BASE_PX` (27). Se aplică la **sprite ȘI hitbox**: pistol/mage → `bullet.scale *= bullet_scale * weapon_size_scale()` (Sprite2D, CollisionShape2D și sfera sunt toate copii → cresc împreună); stingător → raza aurei, care e și vizualul, și zona de damage. Măsurat: glonț 27→74px, sferă 35→96px, aură 102→172px.
- **2 upgrade-uri noi** (acum **18** în pool): **Pufferfish** (Common, `upgrade_17.png`) și **Rat's Burger** (Rare, `upgrade_18.png`).

**Gotchas:**
- **`levelup.gd` are CRLF** → `Edit` cu `old_string` pe mai multe linii **eșuează**. Potrivește o singură linie, sau editează cu PowerShell (`[IO.File]::ReadAllLines`). După o inserție cu Edit, **verifică indentarea** (mie mi-a ieșit un tab în plus).
- **Sfera/orice copil al glonțului moștenește `scale = 0.1`** al rădăcinii din `bullet.tscn`. Orice mărime „în pixeli" pe un copil de glonț trebuie împărțită la scara părintelui.
- **Ordinea contează în `_fire_bullets`**: `_make_mage_orb(bullet)` rulează ÎNAINTE de `bullet.scale *= ...`, deci citește `bullet.scale.x == 0.1`. Sfera crește apoi automat odată cu glonțul (bine — asta vrem).
- **Când testezi un glonț „după upgrade", șterge întâi gloanțele deja în aer** — altfel măsori unul vechi și trage concluzia greșită (mie mi-a arătat că mage-ul „nu crește", deși creștea).
- **`upgrade_12` e `.webp`, nu `.png`.** `load()` NU verifică existența: dacă greșești extensia, întoarce `null` și rămâi cu un chenar gol, fără eroare.
- **PNG nou trebuie importat** înainte de rulare (`godot --headless --path . --import`) — `upgrade_17/18` erau neimportate.
- **`_show_choices()` indexează mereu 3 rânduri** → un test care restrânge `UPGRADES` la mai puțin de 3 crapă.

**Probleme cunoscute (NU rezolvate):**
- **Hitbox-ul glonțului = 1 pixel.** `CapsuleShape2D` pe valorile default (rază 10) × `scale 0.1` → rază 1.0px, față de un sprite de 27px. Gloanțele „trec prin" inamici mai des decât ar trebui. Fix: mărește capsula în `bullet.tscn`.
- **Pistolul e strict inferior lui Mage Staff** (același damage/cadență, dar mage-ul primește gratis explozia AOE) → alegere falsă în meniu.
- **Stingătorul primește 4 upgrade-uri moarte** (Papers, Parallel Bullets, Drill, Adrenaline): nu trage gloanțe, iar aura nu poate da critic. Pool-ul nu filtrează după armă.
- **Explozia AOE a mage-ului nu crește** cu Pufferfish/Rat's Burger (rază separată, `explosion_radius`).

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
