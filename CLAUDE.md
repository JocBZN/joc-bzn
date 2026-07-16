# Context for AI assistants

**Read `README.md` first** — it has the full project overview, architecture, current state, and (most importantly) **how to work with the project owner**, who is a complete beginner learning Godot.

Quick rules:
- **Reply in Romanian.** The owner is a beginner; teach in small, testable steps and be concrete about the Godot UI.
- **Godot 4.7 + GDScript.** Indentation is **TABS** — never mix tabs/spaces (Godot errors out). When code is involved, prefer writing `.gd` files directly to avoid copy-paste/tab problems.
- **Node lookups use groups:** `"player"` and `"enemy"` (via `get_tree().get_first_node_in_group(...)` / `get_nodes_in_group(...)`); cast results with `as Node2D` before using `global_position`.
- This is a **survivors-like / bullet-heaven** game (Vampire Survivors style), cyberpunk theme, for Android. See the roadmap in `README.md`.
- **Repo activ:** `Desktop\joc-bzn` (clonă pe `main`, remote `JocBZN/joc-bzn`). Notele vechi care zic „Downloads\joc-bzn-main" sunt depășite.
- **NU da `git push` decât dacă Răzvan îți cere explicit** (regulă din 2026-07-16, o înlocuiește pe cea de mai jos din log-ul de sesiune, care zicea să dai push automat). Restul finisajului rămâne automat: după ce termini o serie de schimbări, actualizezi CLAUDE.md + README și faci commit local (mesaj în română) — dar `main`-ul de pe GitHub îl atinge doar el, când zice.

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
