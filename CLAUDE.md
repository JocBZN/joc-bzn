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

## Session log — 2026-07-23 (Stolen Halo: scos efectul vizual + sprite-ul)

**Cerut de Răzvan:** „scoate efectul de după ce iei Stolen Halo să ți-l puna și sprite, poți să ștergi și fișierele de animație."

**Ce am făcut:**
- `levelup.gd` (ramura `"stolen_halo"`): am șters apelul `p.show_halo()`. Itemul rămâne **exact la fel ca stat** — `+15 Damage / +5 Max HP`, stivuibil — doar că nu mai apare nimic vizual.
- `player.gd`: am șters funcția `show_halo()` întreagă și toate reglajele legate de ea (`HALO_FRAME_W`, `halo_size`, `halo_side`, `halo_height`, `_halo`). `_load_fx_frames` a rămas neatins — e folosit și de sabie/alte fx.
- Am șters folderul de artă `fx/halo fx/` (Halo.png + cele 10 cadre `frame_0..9.png` + fișierele `.import`). Nimic altceva nu mai referea calea `res://fx/halo fx`.

**Verificat:** `player.gd` și `levelup.gd` se încarcă fără erori de parse; jocul real pornește curat (fără erori de script, fără avertismentul de cadre lipsă). Erorile „Identifier not found: Fx/Audio/GameSettings" de la testul de load izolat sunt autoload-uri, false positive, apar mereu.

**Codex:** nu necesită update — efectul, raritatea și statul rămân aceleași; codexul nu arăta oricum aureola.

---

## Session log — 2026-07-22 (inamicii vin din față + dublu spawn după 2:00)

**Cerut de Răzvan:** „vreau inamicii să se spawneze doar din direcția unde se uită player-ul" + „după minutul 2 vreau să se spawneze 2× mai mulți decât acum".

**1) Conul din față** — `spawner._spawn_enemy()` nu mai trage un unghi la întâmplare pe tot cercul: pleacă de la `player.facing_dir()` și adaugă ±`spawn_cone_deg` (**45°**, `@export`, deci 180 aduce înapoi comportamentul vechi). `facing_dir()` e forma publică a ceea ce folosea deja `_sword_dir()` (`_facing` = ultima direcție reală de mers), iar `_sword_dir()` o cheamă acum pe ea — așa sabia și spawner-ul nu pot ajunge să creadă lucruri diferite despre „în față". Când stai pe loc, privirea rămâne ultima direcție de mers, deci inamicii continuă să vină de acolo.

**2) Dublarea de la 2:00** — `SPAWN_DOUBLE_AFTER = 120.0` / `SPAWN_DOUBLE_MULT = 2.0` în `difficulty.gd`, aplicate în `spawn_mult()` peste creșterea normală. Citite prin `_mult_time()`, nu prin `time`, ca **înghețarea din Limbo să se aplice și aici**, ca la toți ceilalți multiplicatori. E un salt brusc la 2:00, nu o rampă — exact cum a cerut.

**Măsurat în joc** (player întors spre est, `mult_time_override` folosit ca să fixez momentul): secunda 100 → `spawn_mult` **1.47**, 1.2 inamici/s; secunda 140 → **3.31**, 2.2/s. Toți inamicii au apărut între **−42° și +44°** față de privire, în ambele rulări.

**Ce am lăsat intenționat neatins:** Limbo (`limbo.gd`) aruncă în continuare inamici pe tot cercul — acolo ideea e că ești încercuit — iar statuia ridică boss-ul la baza ei. Doar spawner-ul normal s-a schimbat.

---

## Session log — 2026-07-22 (garda aruncă o bastonă care se învârte)

**Cerut de Răzvan:** a șters cadrele vechi ale atacului gărzii din `boss/lightning_burst_003_large_violet/` și a pus în loc **un singur cadru**, `police baton.png`, orientat nord-est. Voia din el o animație de atac **ca un cerc complet**, iar fiecare cadru (inclusiv al lui) să aibă **contur mov de 2px, cu efect ușor de glow**.

**Cum s-a făcut:** `tool_baton.gd` (rămâne în repo, e sursa animației) — încarcă PNG-ul, îl rotește în **16 cadre × 22.5°** și scrie înapoi `frame0000…frame0015.png`. Rulare: `godot --headless --path <proj> res://tool_baton.tscn`.

**Două lucruri care contează în generator:**
- **Rotirea se face în jurul centrului DESENULUI, nu al fișierului.** Bastona nu stă centrată în pânza ei de 128×128; rotită în jurul centrului imaginii, se învârtea excentric, ca o roată dezechilibrată. Tool-ul ia dreptunghiul pixelilor opaci și se rotește în jurul centrului lui, pe o pânză cât diagonala (160×160).
- **Eșantionare cu vecinul cel mai apropiat**, nu bilinear: pixel art-ul se încețoșează, iar marginile pe jumătate transparente ar fi păcălit pasul de contur.

**Conturul (2px):** inelul lipit de desen e mov plin (`#B747FF`), al doilea inel e același mov la **50% alfa** — asta face să pară strălucire, nu chenar tras cu creionul. În joc mai și înflorește, fiindcă glow-ul din `atmosphere.gd` prinde tot ce trece de 1.0, iar conturul e înmulțit cu `tint`-ul proiectilului.

**⚠️ Două potriviri care nu se vedeau din cerință:**
1. Cadrele vechi erau **96×96**, ale mele ies **160×160** → bastona ar fi apărut mult mai mare decât bila veche, cu hitbox-ul rămas la 30px. Am pus `scale = 0.6` pe `AnimatedSprite2D` în `lightning.tscn`, ca desenul să corespundă cu ce lovește.
2. `tint` era `(1.9, 1.5, 2.4)` — făcut ca să lumineze o bilă violet. Pe o bastonă aproape neagră, doar o spăla în gri-mov. Coborât la `(1.25, 1.05, 1.4)`: corpul rămâne închis, conturul strălucește.

`FRAME_COUNT` 10 → 16, `anim_fps` 8 → 24 (o rotire la 0.67s). **Cadrele noi trebuie importate** (`--headless --import`) înainte de o rulare separată, altfel jocul folosește cache-ul vechi.

**Verificat cu poze**: planșa cu toate cele 16 cadre (rotirea e continuă, conturul e pe fiecare) și o poză în joc cu garda lângă bastoane, pentru mărime.

---

## Session log — 2026-07-22 (item nou: Bloody Situation)

**Cerut de Răzvan:** `upgrade_54` **Bloody Situation** (Common) — la fiecare critic te vindeci 2 HP, +2 pe fiecare luare.

**Unde s-a legat:** `player.bloody_heal()` (`bloody_stacks × 2`, plafonat la `max_hp`) e chemat din cele **trei** locuri unde un critic chiar ATINGE un inamic: handler-ul de lovitură din `bullet.gd`, pulsul de aură (`_aura_pulse`) și trecerea de damage a sabiei (`_sword_damage_pass`).

**⚠️ Decizia care contează: o vindecare per LOVITURĂ critică, nu per inamic atins.** Aura rostogolește UN critic pe puls și apoi lovește tot ce prinde; sabia, unul pe tăietură. Dacă vindecarea mergea per inamic, un singur puls critic în mijlocul gloatei te umplea de viață. La sabie am pus un flag separat în dicționarul tăieturii (`t["bloody"]`), nu am refolosit `t["shake"]`, fiindcă tăietura face mai multe treceri de damage cât ține animația.

**Vindecarea e la IMPACT, nu la rostogolire:** un glonț critic care ratează nu dă nimic (de-aia apelul stă în `bullet.gd`, nu în `_spawn_one_bullet`, unde se rostogolește criticul). Un glonț cu străpungere (Drill) vindecă doar la primul inamic (`_hits == 0`).

**Măsurat în joc** (20 de ținte lipite de player, crit 100%, 5s): pistol **9 lovituri → +18 HP**; Stingător **180 de inamici loviți → +18 HP** (adică 2 pe puls, nu 360); sabie **35 de lovituri → +10 HP** (2 pe tăietură); fără item **+0**; cu 3 stack-uri **6 HP pe lovitură**. Cardul a fost fotografiat în meniu: chenar Common, iconița `upgrade_54.png`.

**Pool: 47 de iteme.** Codex actualizat + republicat.

**⚠️ Capcană la splice-ul din codex (m-a prins azi):** `sed 'Nr fisier'` inserează **DUPĂ** linia N. Un card are 2–3 linii (`{ id: ...` / `eff:` / `warn:`), deci ca să inserezi ÎNAINTEA cardului de la linia N dai `(N-1)r`. Am dat `280r` peste `{ id: "iarba"` de pe linia 280 și am rupt cardul Wine în două — JS invalid, pagina ar fi ieșit goală. Verificările de ghilimele/acolade **nu prind** asta; verificarea bună e structurală: *fiecare linie `^  { id: "` trebuie urmată de o linie `^    eff:`*, cu awk. Rulează asta după fiecare splice.

---

## Session log — 2026-07-22 (urmărirea gloanțelor devine item: Psychic Flip Flops)

**Cerut de Răzvan:** „fă gloanțele cum erau înainte să îți zic eu să lovească inamicii" + itemul `upgrade_53` **Psychic Flip Flops** (Epic) care să dea exact efectul de aimbot care era pus pe toate gloanțele.

**Cum s-a făcut, în două linii:** `bullet.gd` — `homing_turn` are acum **default 0.0** (deci tot blocul de urmărire din `_physics_process` e sărit, gloanțele zboară drept ca înainte de 07-21); `player.gd` — `aimbot_stacks` + `aimbot_turn()` (`stacks × 8.0 rad/s`), scris pe **fiecare glonț la tragere** în `_spawn_one_bullet`. Mecanica din `bullet.gd` (țintește UNDE VA FI, renunță când ținta a rămas în spate) **n-a fost atinsă** — s-a schimbat doar cine o pornește.

**Ce am păstrat intenționat** din pasul de pe 07-21: proiectilele bonus își caută ținte doar în **600px** (`ARMORY_RANGE_SQ`). Aia e *alegerea* țintei la tragere, nu urmărire în zbor — n-are legătură cu itemul.

**⚠️ Capcana măsurătorii (două teste greșite la rând, ambele ziceau „100% și fără item"):**
1. Cu un **inel** de ținte care se rotesc, un glonț care ratează ținta lui o lovește pe **vecina** — și eu numărăm loviturile pe toate țintele. Rata iese perfectă orice ai face. Corect: **o singură țintă**.
2. Mai perfid: ținta de test se **teleporta** în fiecare cadru (`global_position = ...`) și, fiind `CharacterBody2D`, **târa player-ul după ea** prin depenetrarea din `move_and_slide()` — player-ul ajungea lipit de țintă (25px), deci orice glonț lovea. Se vedea în log: gloanțele zburau *tangențial*, nu radial. Corect: **`player.set_physics_process(false)`** în test (tragerea merge pe Timer, deci ține).

**Măsurat corect** (țintă care traversează linia de foc, 400px, 250px/s, 55 de gloanțe): **0% fără item → 90.9% cu itemul**. Verificat și cablajul: fără item `homing_turn` ajunge 0.0 pe glonț, cu itemul 8.0, la două luări 16.0. Meniul de level up a fost fotografiat: cardul apare cu chenar Epic și iconița `upgrade_53.png`.

**Pool: 46 de iteme.** **Codex actualizat + republicat**: cardul nou și — important — nota veche „Gloanțele se corectează în zbor" a fost **rescrisă** („Urmărirea NU mai e din oficiu"), fiindcă devenise pur și simplu falsă. Sincronizare verificată: 46 = 46.

---

## Session log — 2026-07-22 (3 iteme noi: Hellas, Borat's Mankini, Horse Mask)

**Cerut de Răzvan:** `upgrade_50` Hellas (uncommon, 15% move speed + 5% crit), `upgrade_51` Borat's Mankini (common, 50% șansă să pice 2 geme de XP mic la fiecare 5 secunde), `upgrade_52` Horse Mask (epic, 5% la lovitură să întorci inamicul împotriva alor lui, +5% pe luare).

**1) Hellas** — `p.speed *= 1.15` (procent pe valoarea curentă, se compune) + `p.crit_chance += 0.05` (aditiv). Nimic nou în cod.

**2) Borat's Mankini** — un Timer nou pe player (`MANKINI_INTERVAL = 5.0`), pornit din `_ready`, care nu face nimic până ai itemul. Ca la Broken Watch, repetarea crește NUMĂRUL de geme (2 pe luare), nu șansa. Două detalii:
- gemele cad la **50–100px** de player, nu în buzunar — le vezi cum vin singure (au magnet propriu);
- valoarea trece prin `Difficulty.xp_mult()`, exact ca dropul inamicilor. Fără asta, la minutul 10 ar fi fost firimituri.

**3) Horse Mask** — starea stă în `enemy.gd` (`charmed`, `_charm_target`), player-ul expune doar `horse_mask_chance()` — aceeași împărțire ca la Duridama. Fermecatul devine roz (`CHARM_TINT`, are prioritate în `_tenta()`, redenumită din `_slow_color`), își ia drept victimă **cel mai apropiat alt inamic nefermecat** (rază 700px) și o lovește cu **10 × dificultate la fiecare 0.5s** până moare; atunci vraja se rupe și se întoarce la tine.
- ⚠️ **Lovitura fermecatului NU are voie să farmece la rândul ei.** `take_damage` a primit `from_charm`, plus o ușă separată `charm_hit()`. Fără asta, un singur proc s-ar fi propagat în lanț prin toată gloata până nu mai lupta nimeni cu tine.
- ⚠️ **`charm_hit()` există și dintr-un motiv mai prozaic:** `garda.gd` (boss-ul) e și el în grupul `"enemy"`, dar are `take_damage(amount)` cu UN argument — un apel cu două argumente ar fi crăpat lupta cu boss-ul. Așa, pe garda se cade pe `take_damage(dmg)` obișnuit.
- cât e fermecat nu-ți mai face damage la contact (`player._take_contact_damage` îl sare), dar rămâne în grupul `"enemy"`, deci îl poți omorî normal — cum a cerut Răzvan.

**Verificat rulând jocul** (scenă de test ștearsă după): farmecul se declanșează, victima moare în 2.5s, vraja se rupe, iar player-ul lipit de un fermecat rămâne la **100/100 HP**, în timp ce unul normal în același loc îi ia **10**. Meniul de level-up a fost și el fotografiat: toate cele 3 iconițe se încarcă în chenarele de raritate corecte.

**Pool: 45 de iteme.**

**Codex actualizat** (același URL, 2026-07-22): cele 3 carduri noi + nota de sinergie **„Farmecul nu se propagă în lanț"** (charm_hit, fermecații se sar între ei, Duridama are prioritate pe lovitură) + nota „Cum se adună Norocul" rescrisă cu lista completă a șanselor pe care le atinge norocul: **crit, instakill, Broken Watch, Plugged In, Horse Mask, Borat's Mankini — dar NU Duridama** (`duridama_chance()` nu adună `luck_bonus()`, spre deosebire de `horse_mask_chance()`).

**Metodă nouă de splice, fără PowerShell:** iconițele se encodează cu `base64 -w0` (coreutils există în Bash) în linii `ICONS["upgrade_NN.png"]="data:..."`, iar tot montajul se face **într-o singură trecere de `sed -i`** cu mai multe `-e 'Nr fisier'` (numerele de linie rămân cele din fișierul original în aceeași trecere). Textul românesc stă în fișiere scrise separat, deci **nu mai trece prin literale PowerShell** — dispare complet riscul de diacritice stricate. Inserțiile se dau în ordine crescătoare de linie; `-e '308r luck.txt' -e '309d'` înlocuiește o linie întreagă.

**Sincronizare verificată: 45 = 45**, comparând `id|iconiță|raritate` din `levelup.gd` cu cele din `codex.html` — zero diferențe. Toate cele 45 de iconițe folosite au base64 în fișier. Verificarea vizuală în browser **nu s-a putut face** (fără extensia Chrome în sesiunea asta), doar verificări statice: ghilimele și acolade echilibrate în regiunea editată.

---

## Session log — 2026-07-21 (gloanțe cu urmărire + explozia lui Jean's Bomb nu mai suflă)

**Cerut de Răzvan:** „la Jean's Bomb — bomba să nu-i mai miște pe inamici" + „fă tracking mai bun la proiectile, că atunci când ai mai multe proiectile trackingul e prost rău, trece prin inamici".

**1) Explozia nu mai suflă** (`bullet.gd`, `_explode`): scos `apply_knockback` + constanta `EXPLOSION_KNOCKBACK`. Knockback-ul de la GLONȚ (itemul Knockback Stick) rămâne neatins.

**2) Gloanțele își urmăresc ținta.** `bullet.gd` are acum `homing_turn` (rad/s) și `target`, iar player-ul îi dă ținta la tragere (`_fire_volley`/`_spawn_one_bullet` au primit un parametru `tinta`). Trei detalii care fac diferența:
- ⚠️ **Anticiparea e obligatorie, nu un moft.** Prima versiune vira spre unde era inamicul ACUM: rata de lovire a ieșit **0%**. Cauza e clasica problemă de rachetă — raza de viraj a glonțului (`speed / homing_turn` = 700/8 = 87px) e mai mare decât distanța la care trece pe lângă țintă, deci o ratează la limită și apoi **orbitează** în jurul ei până moare de bătrânețe. Acum țintește unde VA FI (`spre + velocity × timp_de_zbor`).
- **Dacă ținta a rămas în spate, glonțul nu se mai întoarce** (`aim.dot(direction) > 0`) — altfel orbitează la nesfârșit. Trece pe lângă și își caută altă țintă în față.
- **Re-țintirea e ieftină**: doar când ținta a murit, cel mult o dată la 0.2s, doar în față, cu `length_squared`. În Final Swarm sunt sute de gloanțe și sute de inamici.
- Proiectilele bonus își caută ținte doar în **600px** (`ARMORY_RANGE_SQ`). Înainte se alegeau din TOATĂ harta, deci multe plecau spre celălalt capăt și mureau de bătrânețe (lifetime 2s × 700px/s = ~1400px).

**Măsurat** (12 inamici care se rotesc în jurul playerului la 400px, deci se mișcă mereu perpendicular pe glonț; 9 proiectile pe salvă):

| homing (rad/s) | rata de lovire |
|---|---|
| 0 (vechiul comportament) | **0%** |
| 4 | 75% |
| **8 (ales)** | **85%** |
| 16 | 89% |

**Performanță:** 200 de inamici + tragere la 12.5 salve/s → **141.8 FPS fără urmărire vs 144.5 cu** (adică zero cost măsurabil).

**De semnalat lui Răzvan:** cauza de fond a lui „trece prin inamici" e că **hitbox-ul inamicului e mult mai mic decât desenul**: desenul are 47×89px pe ecran, hitbox-ul e un cerc de 30px (`CircleShape2D` lăsat pe raza default 10, × scale 1.5). Gloanțele care trec prin cap sau prin picioare nu ating nimic. Urmărirea maschează problema (ținteșc centrul), dar dacă vrea, hitbox-ul se face capsulă pe măsura corpului. **N-am schimbat-o**: un hitbox mai mare schimbă și cum se înghesuie inamicii între ei și cât de aproape ajung de player.

⚠️ **Greșeala mea, de reținut:** am curățat fișierele de test cu `rm -f *.gd.uid` și am șters **toate cele 33 de `.uid`-uri ale proiectului** (Godot le folosește ca identificatori de script). Recuperate cu `git checkout -- "*.gd.uid"`. La curățenie se șterg fișierele pe nume, niciodată cu wildcard peste o extensie a proiectului.

---

## Session log — 2026-07-21 (BUG: ecranul tremura continuu — de la cadența de tragere)

**Reclamat de Răzvan:** „la un moment dat am efect de shake pe ecran încontinuu, nu știu de la ce" + o înregistrare de ecran în `debugging/`.

**Cauza (matematică, nu ghicită):** fiecare lovitură critică adaugă `0.35` traumă (`add_shake`), iar trauma scade cu `shake_decay = 4.0` pe secundă. Deci **peste ~11.4 atacuri pe secundă se adună mai repede decât se stinge**, trauma se lipește de 1.0 și camera tremură fără oprire. În video: **Attack Speed 12.92/s, 9 proiectile, 43% crit** — cu 9 proiectile și 43% crit, practic FIECARE salvă are măcar un critic, deci 12.92 × 0.35 = 4.52 > 4.0. Exact peste prag.

**Cum am citit videoclipul** (util data viitoare — **ffmpeg EXISTĂ** pe mașina asta: `~/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_*/ffmpeg-*/bin/`):
- diferența dintre cadre consecutive, pe secundă, arată unde e agitație: `-vf "scale=480:-1,tblend=all_mode=difference,signalstats,metadata=print:file=diff.txt"`, apoi mediat cu awk. Secundele cu `diff ≈ 0.01` sunt meniul de level-up (ecran înghețat), cele cu `diff ≈ 2` sunt joc.
- ⚠️ **Capcană:** filtrul `metadata=print:file=` NU acceptă căi Windows cu `C:` (parserul de filtre taie la `:`). Se face `cd` în folderul de ieșire și se dă doar numele fișierului.
- cadrele extrase cu `-ss <t> -frames:v 1` s-au citit direct ca imagini — **panoul STATS din meniul de level-up e cea mai bună sursă de adevăr**: de acolo au ieșit cele 12.92 atacuri/s care explică totul.

**Fix:** `add_shake` are acum un **răgaz minim** (`SHAKE_MIN_GAP = 0.12s`) între două zguduituri. Peste ~8.3 impulsuri pe secundă restul se ignoră, deci intră cel mult 2.9 traumă/s — sub cei 4.0 care se sting. **Sub 8 atacuri/s nu se schimbă absolut nimic** (la 2 atacuri/s impulsurile sunt oricum la 0.5s distanță), deci senzația de la un critic izolat rămâne identică.

**Măsurat**, cu un test care reproduce exact statisticile din video (12.92/s, 9 proiectile, 43% crit): **înainte** trauma urca la 0.94 și camera stătea la 18.3px offset; **după**, trauma face vârfuri fixe de 0.35 și offset-ul rămâne ~2px, stabil 12 secunde la rând.

**Notă:** `debugging/*.mp4` a intrat în `.gitignore` — videoul rămâne pe disc, dar 14 MB în istoric pentru un raport de bug nu merită. Capturile PNG rămân în repo.

---

## Session log — 2026-07-21 (Thunder God: Legendary + damage care se stivuiește)

**Cerut de Răzvan:** „vreau ca Thunder God să fie legendary și să scaleze % of damage. La început are 25% și vreau cu fiecare luare să crească cu 25%".

- **Raritate:** `epic` → `legendary` în `levelup.gd`. Descrierea din joc: „Chain lightning for 25% of damage (+25%/stack)".
- **Damage:** `thunder_stacks` nu mai e doar un întrerupător (0/1), ci scalează. Nou: `player.thunder_damage_pct()` = `THUNDER_PCT_PER_STACK (0.25) × maxi(thunder_stacks, 1)`.
- ⚠️ **`maxi(..., 1)` e esențial pentru Plugged In:** el pornește lanțul cu `thunder_stacks == 0`, deci fără el arcul lui ar fi făcut **0 damage** și itemul ar fi devenit decor. Așa, Plugged In singur rămâne la 25% — el crește ȘANSA, nu damage-ul. (E a doua oară când Plugged In se sparge din cauza unei condiții pe `thunder_stacks`; prima e documentată în comentariul lung din `thunder_burst`.)
- **Am adăugat și `damage_mult()`** în `thunder_damage()`: procentul se ia acum din damage-ul REAL al momentului (cu Theo's Wrath / Cigarette / Diesel), ca la Jean's Bomb. Înainte se lua din `bullet_damage` brut. **E o schimbare pe care Răzvan nu a cerut-o explicit** — i-am spus, se scoate cu o singură tăietură dacă nu o vrea.

**Măsurat** (headless, prin `Levelup._apply`): fără nimic 25%/5 damage · doar Plugged In 25%/5 · Thunder God 1× 25%/5 · 2× 50%/10 · 3× 75%/14; după `+20 damage` arcul urcă la 29, iar după `+5% damage mult` la 31.

**Codex actualizat**: cardul s-a mutat la Legendary, marcat „modificat", plus nota din secțiunea de sinergii (Plugged In crește doar șansa).

---

## Session log — 2026-07-21 (dificultatea: creștere COMPUSĂ după 1:30 + inamicii lovesc mai tare)

**Reclamat de Răzvan:** „inamicii sunt prea slabi după primul 1:30, fă-i să fie din ce în ce mai OP". L-am întrebat cât de brutal (i-am arătat tabele cu 3 variante) și a ales **×1.40/minut** pentru viață și **×2 la minutul 10** pentru damage.

**De ce rămâneau în urmă:** faza 1 creștea LINIAR (`1 + 0.55 × minute`), iar build-ul playerului se înmulțește (damage × crit × proiectile × AOE). La minutul 10 inamicii aveau doar **6.5×** viață. Plus: **damage-ul lor nu creștea DELOC** — un inamic de la minutul 10 lovea exact cât unul de la secunda 0.

**Ce s-a schimbat în `difficulty.gd`:**
- **Primele `RAMP_START = 90s` au rămas neatinse** (liniarul vechi) — reclamația era despre ce vine DUPĂ 1:30, nu despre început.
- După 1:30 viața devine compusă: `pow(HP_GROWTH_PER_MIN, minute_de_rampă)`, cu **1.40**.
- Nou: `enemy_damage_mult()` — `DMG_GROWTH_PER_MIN = 1.0844` (adică `2^(1/8.5)`, fiindcă din 1:30 până la 10:00 sunt 8.5 minute de rampă), iar în Final Swarm se dublează la fiecare 2 minute (`FS_DMG_DOUBLE_EVERY`). Se aplică la damage-ul de contact (`player._take_contact_damage`, inclusiv reflexia de la Mike's Hedgehog) și la bilele Gărzii (`garda.gd`).
- ⚠️ **XP-ul a primit ACELAȘI factor compus ca viața.** Dacă îl lăsam liniar, la minutul 10 aveai inamici de 32× viață care dădeau 4× XP → ritmul upgrade-urilor s-ar fi prăbușit și ieșea „imposibil", nu „greu". Raportul xp/hp rămâne acum **1.59 constant** după 1:30 (verificat în tabel), adică exact echilibrul dinainte.

**Măsurat** (test temporar care plimbă `Difficulty.time` și naște inamici reali):

| timp | viață (mult) | viața reală a unui inamic | damage la contact (bază 5) |
|---|---|---|---|
| 1:30 | 1.8× | 54 | 5 |
| 5:00 | 5.9× | 177 | 7 |
| 7:00 | 11.6× | — | 8 |
| 10:00 | 31.9× | 956 | 10 |
| 12:00 | ~250× | — | 20 |

**De semnalat lui Răzvan (efect secundar real):** itemele cu damage FIX rămân acum mult în urmă — `fire_trail_damage = 5`, `frost_trail_damage = 2` și **Panic Button (100 damage)**, care la minutul 10 nu mai omoară un inamic de 956 HP. Aceeași problemă pe care tocmai am rezolvat-o la Jean's Bomb (trecut pe procent). Merită trecute și ele pe procent din damage-ul playerului — dar e decizia lui.

---

## Session log — 2026-07-21 (Undying Spirit apare o singură dată + Jean's Bomb pe procent)

**Cerut de Răzvan:** „dacă playerul a luat o dată Undying Spirit, fă să nu-i mai apară niciodată runda aia" + „la Jean's Bomb, în loc de 25 damage în zonă fă să fie 15% of damage (și să scaleze cu +20 damage prima parte, și explozia cu range +20 și 10% of damage)".

**Iteme „unice"** — mecanism GENERAL, nu un caz special pentru Undying: în dicționarul itemului pui `"unic": true`, iar `_on_choice` îi trece id-ul în `_luate_unic` după ce l-ai ales. `_trage_unul` filtrează prin `_e_disponibil()` — și în tragerea pe raritate, ȘI în plasa de siguranță (dacă lipsea din a doua, itemul ar fi reapărut exact în cazul rar în care categoria rămâne goală). Lista se golește singură la rundă nouă, fiindcă `main.tscn` se reîncarcă. **Deocamdată doar Undying Spirit e marcat**; oricare altul se marchează la fel, cu un singur cuvânt.

**Jean's Bomb** nu mai face 25 damage fix în zonă, ci **un procent din damage-ul salvei**:
- câmp nou pe player: `explosion_damage_pct` (15% la prima luare, **+10%** la fiecare repetare), iar raza e 130 la prima luare și **+20** la repetare (înainte era `=130`, deci repetarea nu făcea nimic pe rază). Partea directă rămâne `+20 damage` de fiecare dată.
- calculul se face **la tragere**, în `_fire_bullets`: `ex_damage = maxi(ex_damage, int(round(dmg_base * explosion_damage_pct)))`. `dmg_base` include deja `damage_mult()` (Theo's / Cigarette / Diesel), deci explozia crește singură cu tot ce iei pe damage — asta era și ideea: 25 fix devenea neglijabil după 10 minute.
- `max`-ul păstrează regula veche a Mage Staff-ului (60% din damage) — la mage câștigă tot 60%, ca înainte.
- `explosion_damage` (fix) a rămas în cod, dar acum nu-l mai setează nimeni.

**Verificat** headless: raza 130 → 150, procentul 0.15 → 0.25, iar glonțul chiar tras avea `damage=62, explosion_radius=150, explosion_damage=16` (= 25% din 62, cu tot cu +5% de la Cigarette Pack). Pentru unic: **11 apariții la 300 de pagini** înainte de a-l lua, **0 după**.

---

## Session log — 2026-07-21 (Gunslinger + item nou: Death Sentence)

**Cerut de Răzvan:** „schimb poza la Stacked Armory — e upgrade_47, și numele în Gunslinger" + „upgrade nou — upgrade_49 (Rare) Death Sentence: -35% movement speed, +20% attack damage, +20% attack speed".

**Gunslinger** = fostul Stacked Armory: alt nume, altă iconiță (`upgrade_47.png`, un revolver), **efect neschimbat**. **Id-ul a rămas `stacked_armory`** — la fel ca la Twin Comets, id-ul e cheia din `_apply` și din toate referințele vechi; numele afișat e doar text. Am schimbat „Stacked Armory" → „Gunslinger" și în comentariile din `levelup.gd` + `player.gd`, ca să nu rămână două nume pentru același lucru. `upgrade_46.png` (borcanul cu săgeți) nu mai e folosit de niciun item.

**Death Sentence** (Rare, `upgrade_49.png` — bila cu lanț, exact tema): `p.speed *= 0.65`, `p.bullet_damage = int(round(p.bullet_damage * 1.20))`, `p.upgrade_fire_rate(0.80)`. Convenția de attack speed din proiect: factorul înmulțește **intervalul**, deci 0.80 = tragi cu 20% mai des (ca `foite` cu 0.90 sau `nightclub` cu 1.35 în sens invers).
- ⚠️ **Toate trei sunt procente pe valoarea CURENTĂ**, deci se compun la repetare (ca The Nightclub). Măsurat: 315 → 204.75 → 133.09 viteză; damage 19 → 23 → 28; cadență 2.00/s → 2.50/s → 3.12/s. La a patra luare rămâi cu **18%** din viteza de start. **N-am pus plafon intenționat** — itemul e un pariu, dar dacă Răzvan zice că e prea brutal, o singură linie cu `maxf(p.speed * 0.65, ceva)` rezolvă.

**Verificat** cu test temporar headless (numerele de mai sus, aplicate prin chiar `Levelup._apply`) + captură windowed a paginii de level-up cu toate trei itemele noi: iconițele se randează, iar panoul de statusuri arată exact povestea itemului — Damage și Attack Speed **verzi**, Move Speed **roșu**.

**Codex actualizat** (același URL): Gunslinger redenumit (cu notă că e fostul Stacked Armory) + cardul Death Sentence. Iconițele injectate cu același `add_icon.ps1` din sesiunea anterioară — merge la fel de bine în buclă pentru mai multe iconițe.

---

## Session log — 2026-07-21 (item nou: Lucky Die — reroll la pagina de iteme)

**Cerut de Răzvan:** „upgrade nou — upgrade_48 (Rare) Lucky Die — reroll item page (când iei upgrade-ul îți apare o pagină nouă de upgrade-uri)".

**Cum e făcut** (tot în `levelup.gd`, nimic în `player.gd` — itemul nu atinge playerul):
- `_apply("lucky_die")` doar ridică steagul `_reroll = true`.
- `_on_choice` îl citește **după** `_apply`: dacă e ridicat, cheamă `_show_choices(_current)` și face `return` **înainte** de `_pending -= 1` → nivelul NU se consumă, deci după reroll tot alegi un item. Meniul rămâne deschis și jocul pe pauză, fără să clipească.
- `_show_choices` și `_trage_iteme` au primit un parametru nou `exclude` (implicit gol, deci restul codului merge neatins). La reroll se trimit chiar cele 3 iteme de pe pagina veche → **pagina nouă e garantat alta**, iar Lucky Die (fiind pe pagina veche) **nu poate reapărea pe ea**, deci nu se poate intra într-un lanț de reroll-uri la nesfârșit din aceeași alegere.

⚠️ **Iconița nouă avea nevoie de reimport** — `upgrade_48.png` venise fără `.import`, deci `load()` ar fi întors `null` și rândul ar fi rămas gol. Rulat `--headless --import`. (În repo mai e și `upgrade_47.png`, nefolosit de niciun item.)

**Verificat** cu un test temporar headless care instanțiază `main.tscn`, deschide level-up-ul, forțează Lucky Die pe prima poziție și apasă: `_pending` rămâne **1**, meniul rămâne vizibil, pagina nouă are **0 iteme comune** cu cea veche și nu conține `lucky_die`; după o alegere normală `_pending` ajunge 0, meniul se închide și pauza se ridică. Plus o captură windowed a paginii, ca să văd că iconița și border-ul verde de Rare chiar se randează.
⚠️ **Capcană la testele care instanțiază `main.tscn`:** `add_child` direct din `_ready` crapă („Parent node is busy setting up children"). Se face cu `add_child.call_deferred(main)` + 2-3 `await get_tree().process_frame`, altfel scena nu intră în arbore, `_ready`-urile nu rulează și primești rezultate false (la mine `_current` ieșea gol).

**Codex actualizat** (același URL) cu itemul nou. Iconița a fost injectată în harta `ICONS` **fără să ating linia uriașă** de base64 deja existentă: un `.ps1` mic (`scratchpad\add_icon.ps1`) care adaugă o linie `ICONS["upgrade_48.png"]="data:..."` chiar înainte de `const RARS`. Mult mai ieftin decât re-splice-ul complet și fără riscul de a strica diacriticele (citit/scris tot cu `UTF8Encoding($false)`).

---

## Session log — 2026-07-21 (Twin Comets: proiectile în alți inamici, nu gloanțe paralele)

**Cerut de Răzvan:** „Twin Comets — în loc de parallel bullets îți dă +2 projectiles". L-am întrebat ce înseamnă exact (în cod erau două mecanici diferite) și a ales: **cele 2 proiectile pleacă spre ALȚI inamici la întâmplare**, ca la Stacked Armory, nu în evantai spre aceeași țintă.

**Schimbarea e de o linie** (`levelup.gd`, `_apply`): `p.bullet_count += 2` → `p.stacked_armory_stacks += 2`. Twin Comets și Stacked Armory **se adună în același contor**, deci ambele luate = 3 proiectile bonus, fiecare tras într-un alt inamic. Descrierea din joc: „+2 projectiles at random enemies". **Id-ul a rămas `gloante_paralele`** ca să nu stric referințele vechi (log-uri, codex) — numele lui nu mai descrie ce face.

**Consecință de care trebuie ținut cont:** acum **niciun item nu mai crește `bullet_count`**, deci gloanțele paralele sunt cod viu dar nefolosit (`bullet_spacing`, `_fire_volley` cu un singur glonț). L-am lăsat pe loc, gata de refolosit dacă vrea un item nou de tip „shotgun". A dispărut și înmulțirea de dinainte (Twin Comets ×proiectilele bonus, adăugată pe 07-20): înainte 2× Twin + 1× Armory dădeau 5 gloanțe pe salvă principală + 5 pe cea bonus; acum e liniar.

⚠️ **Panoul de statusuri arăta `bullet_count` direct**, deci după schimbare ar fi rămas veșnic pe „Projectiles 1", deși itemele îl cresc. Adăugat `player.projectiles_total()` = `bullet_count + stacked_armory_stacks` (Broken Watch NU intră — e pe șansă, nu garantat) și rândul „Projectiles" îl folosește pe el.

**Verificat** cu un test temporar headless care pune 4 inamici falși în grupul `"enemy"`, aplică itemul prin chiar `Levelup._apply` și numără gloanțele dintr-o salvă: **1 → 3** (1× Twin) **→ 6** (2× Twin + 1× Armory), iar panoul afișează aceleași cifre. Trucul: proiectilele bonus se recunosc după `has_method("set_direction")`, iar ținte false ajung să fie simple `Node2D` puse în grupul `"enemy"`.

**Codex actualizat** (același URL): efectul rescris + o etichetă nouă **„modificat"** (`isRework`, badge auriu, pe lângă „nou"/`isNew`) — un item vechi cu efect schimbat e mai perfid decât unul nou, fiindcă Răzvan crede că știe ce face.

---

## Session log — 2026-07-21 (sfera magică: 7 cadre în loc de 14 + contur negru de 1px)

**Cerut de Răzvan:** „la mage_orb ți-am șters niște frame-uri, vreau să le folosești doar pe alea ce au rămas + să le pui un stroke negru de 1px".

**Cadrele.** Șterse `frame_7` … `frame_13`; au rămas **`frame_0` … `frame_6`** (7 cadre, 64×64). **Nu a fost nevoie de nicio modificare de cod:** `_load_fx_frames` (`player.gd`) numără de la 0 și se oprește la primul cadru care lipsește, deci numerotarea rămasă fiind continuă, animația s-a scurtat singură. La 18 FPS, bucla ține acum 0.39s în loc de 0.78s (proiectilul e loop, deci se vede doar ca o pulsație de două ori mai rapidă). Dacă vrei viteza veche, scazi FPS-ul la 9 în `player.gd:233`.

**Conturul.** Aceeași idee ca la bila de lightning (vezi log-ul din 2026-07-19), dar **făcut din Godot**, nu din PowerShell/System.Drawing — un script temporar care încarcă PNG-ul cu `Image.load_from_file`, îl prelucrează și îl salvează la loc. Mai simplu și fără capcanele de PowerShell.
- **Diferența importantă față de data trecută: se conturează DOAR silueta exterioară.** Prima încercare a fost regula veche („orice pixel transparent lipit de unul plin devine negru") și a ieșit **noroioasă**: arta sferei e plină de scântei mici și de goluri interioare, așa că negrul intra peste tot prin mijloc și înghițea desenul. Acum pixelii goi din INTERIORUL siluetei sunt excluși printr-un **flood fill de la marginea imaginii** — negru primesc doar cei legați de „afară".
- Prag de alfa **0.25** (sub el, pixelul e considerat gol). Cu 0.05 conturul stătea prea departe de formă, fiindcă arta are un halou foarte slab în jur; cu 0.5 mânca din desen.
- Originalele au fost citite din backup (scratchpad), nu din fișierele deja modificate → scriptul e re-rulabil fără să îngroașe conturul la fiecare rulare. Backup-ul e temporar; sursa de adevăr pentru originale rămâne git (`git checkout HEAD~1 -- fx/mage_orb`).
- **Reimport obligatoriu** după rescrierea PNG-urilor (`--headless --import`), altfel jocul rulează cadrele vechi din cache.

**Verificat vizual**, la mărimea reală din joc (35px pe ecran, `mage_orb_size`), pe fundal întunecat ȘI pe nisip: conturul se citește clar pe deșert, unde chiar era nevoie de el. ⚠️ **Capcană la verificare:** proiectul are `stretch/mode="canvas_items"` fără `viewport_width` setat, deci baza e 1152×648; dacă rulezi captura cu `--resolution 460x200`, tot ce vezi e micșorat cu 0.4 și trage la concluzii greșite despre cât de gros arată conturul. Rulează captura la **1152×648** și mărește imaginea în cod (`Image.resize` cu `INTERPOLATE_NEAREST`).

**De semnalat lui Răzvan:** sursa e 64px, dar sfera se desenează la 35px → 1px de contur devine ~0.55px pe ecran, deci pe cadrele mari conturul iese **întrerupt, punctat**. Dacă vrea un contur continuu, varianta e 2px (se reaplică din backup/git într-o rulare).

---

## Session log — 2026-07-21 (bulele de XP — contopire vizibilă, nu ștergere)

**Cerut de Răzvan**, imediat după sesiunea de mai jos: „la xp nu vreau să dispară, vreau să pui un overlay roșu pe poza xp2 — și când se strâng foarte multe geme de xp într-un loc, 20 de cele xp simplu (nu xp2) devin o singură bulă de xp3".

**Regula (în `xp.gd`):** când `CLUSTER_NR = 20` geme de ACELAȘI fel ajung la mai puțin de `CLUSTER_RAZA = 260px` una de alta, toate **zboară spre centrul lor** și se contopesc într-o bulă care valorează exact cât ele la un loc. Bulele se contopesc și ele între ele, după aceeași regulă → numărul de geme rămâne mic de la sine, oricât ar dura runda (măsurat: ~80 geme + ~70 bule, constant, cu bule de 26.000 XP). Gema rară **xp2 nu se contopește** (cerut explicit). Cine se contopește se știe după `tier` (1 = xp1, 2 = xp2, 3 = bulă) — `@export`, setat în fiecare `.tscn`.

⚠️ **Capcana care a făcut ca la prima încercare să nu se contopească NIMIC:** verificarea era în `_ready()`, dar cine creează o gemă îi pune poziția **după** `add_child` (vezi `enemy._drop_xp`), deci în `_ready` gema e încă la (0,0) și nu găsește niciun vecin. Rezolvat cu `_incearca_contopirea.call_deferred()` — rulează la sfârșitul cadrului, când poziția e deja pusă. **Regulă generală: nimic care depinde de poziția unui nod nou nu se face în `_ready`.**

**Culoarea bulei:** arta lui `xp/xp2.png`, vopsită roșu **la rulare** (`_textura_rosie`): fiecare pixel primește nuanța `NUANTA_BULA` (0.0 = roșu) și își păstrează saturația + luminozitatea → același desen, aceleași umbre, altă culoare. O singură prelucrare pe rundă, ținută într-un `static`. **Intenționat NU există `xp3.png`**: schimbi `xp2.png`, bula se ia automat după el, fără reimport.

**Overlay-ul roșu cerut a fost încercat primul și a ieșit prost** — testat pe 4 variante și comparat cu ochii: additiv 0.8 și 1.0 = orbul rămâne albastru, doar marginile bat în mov; roșu peste el la 0.55 = noroios; canale R↔B inversate = portocaliu (se bate cu xp1 galben). Rotirea nuanței cu −210° dădea miezul măsliniu. Câștigătoarea a fost nuanța FIXĂ. Poza comparativă a celor trei geme pe iarbă: `debugging/geme_xp1_xp2_xp3.png`.

**De semnalat lui Răzvan:** gemele **xp2 se adună la nesfârșit** (5% din ~30 de morți pe secundă = ~1.5/s; măsurat 207 după 2:30 de Final Swarm). Nu strică framerate-ul acum, dar la o rundă lungă ar deveni aceeași problemă — și „rara" nu mai pare rară când e tot ecranul plin. Așteaptă decizia lui (contopire și pentru ele / șansă mai mică de drop în Final Swarm / lăsat așa).

---

## Session log — 2026-07-21 (laghitul din Final Swarm — măsurat și reparat)

**Reclamat de Răzvan:** „după ce se termină timer-ul și trec 2 minute începe să lagheze rău de tot".

**Întâi măsurat, abia apoi reparat.** Am scris un harness temporar (`_perf.tscn` + `_perf.gd`, șters la final): instanțiază `main.tscn`, sare cu `Difficulty.time` direct în Final Swarm, face player-ul nemuritor cu build de final de rundă și loghează la fiecare 5s FPS + un **recensământ al nodurilor din lume grupate după scriptul lor**. Recensământul e cheia — a arătat vinovatul din prima, fără ghicit:

```
t= 600 fps=144 noduri=  677 inamici= 7 xp=   6
t= 660 fps=144 noduri= 4039 inamici=39 xp=1076
t= 720 fps= 68 noduri= 7860 inamici=54 xp=2327
t= 780 fps=  4 noduri=17224 inamici=88 xp=5390   <-- gemele de XP
```

**Cauza 1 — gemele de XP nu dispăreau niciodată.** Inamicii și gloanțele stăteau constante; gemele creșteau liniar la nesfârșit. Rezultat după reparare: noduri constant ~1500, **144 FPS toată runda**.

Prima variantă (plafon de 200, gema cea mai depărtată se vărsa în cea nouă și dispărea) **a fost respinsă de Răzvan**: „la xp nu vreau să dispară". A cerut în loc o contopire VIZIBILĂ — 20 de geme simple devin o bulă. Vezi log-ul de mai jos.

**Cauza 2 — Thunder God, într-o gloată.** Test separat cu player slab (inamicii se adună la plafonul de 300): **4400 de arcuri electrice vii** → 6 FPS. Un impact = un arc pentru FIECARE inamic din rază, iar arcurile au `_process` propriu. Plafoane în `player.gd`, **doar pe vizual — damage-ul îl încasează toți din rază ca înainte**: `THUNDER_MAX_ARCE = 10` arcuri desenate per descărcare, `THUNDER_MAX_ARCE_VII = 60` arcuri vii în total.

**Cauza 3 — un Tween per sclipire de lovitură.** Cu 300 de inamici loviți de mai multe ori pe secundă, `_flash()` și `flash_electric()` creau mii de obiecte `Tween` pe secundă pentru un fade de 0.12s. Înlocuite cu un cronometru float scurs în `_physics_process` (`_flash_time`/`_flash_dur`/`_flash_color`) — comportament identic. Tot în `enemy.gd`: player-ul se ține minte în loc să fie căutat prin grup în fiecare cadru (×300), și `anim.play()` se cheamă doar când chiar se schimbă direcția.

**Plus, preventiv:** plafoane în `fx.gd` (45 numere de damage / 25 nori de scântei / 35 fulgere vii deodată — o pulsație de aură peste 200 de inamici cerea 200 de `Label`-uri într-un cadru) și throttle pe `Audio.play()` (45ms per nume; sunetele de hit lipsesc acum din `SFX`, dar când le pui la loc ar fi cerute de sute de ori pe secundă).

⚠️ **Capcana contoarelor din `fx.gd`:** tween-urile care le scad aparțin nodurilor din scena curentă și **mor odată cu ea** la restart. Fără resetul din `_world()` (la schimbarea scenei), contoarele ar rămâne blocate sus și după câteva runde n-ar mai apărea NICIUN efect. Același risc ar exista la orice viitor plafon bazat pe contor + tween.

**Rezultat măsurat, cazul cel mai rău (300 de inamici + Thunder God): 6 FPS → 90-144 FPS.** Plafonul de 300 de inamici (`spawner.max_enemies`) **nu** era problema — 300 de inamici fără Thunder God mergeau la 118-144 FPS și înainte. Verificat vizual pe joc (screenshot): geme, inamici, arc electric, numere de damage, HUD — toate normale.

---

## Session log — 2026-07-20 (iconiță nouă Stacked Armory + artă nouă xp2)

**Cerut de Răzvan:** iconița Stacked Armory → `upgrade_46.png`; separat, a schimbat el arta gemei xp2 (`xp/xp2.png`, acum un orb albastru în spirală).

**Făcut:** icon `upgrade_37.png` → `upgrade_46.png` în `levelup.gd` și în codex (injectat base64, republicat). `upgrade_37` nu mai e referit de niciun item — iconița veche rămâne în `ICONS` din codex, nefolosită dar inofensivă.

**Reimportate AMBELE imagini** (`--headless --import`) — pasul ușor de uitat: la o rulare directă (nu din editor) texturile noi/înlocuite trebuie importate întâi, altfel `load()` crapă cu „No loader found". Verificat: `xp2` se încarcă fără eroare, iconița Stacked Armory apare pe card (butoiul cu arme), gemele xp2 sunt culese și dau XP normal.

---

## Session log — 2026-07-20 (item nou: Duridama — inamici auriți, mecanică în 2 lovituri)

**Cerut de Răzvan:** `upgrade_45` Duridama (Legendary) — 1% șansă la lovire să facă inamicul auriu (overlay auriu + îngheață exact în cadrul lovit); după ce lovești un inamic deja auriu, moare instant și lasă 2× XP.

**Mecanica trăiește în `enemy.gd`** (nu în player), fiindcă starea „auriu" e a inamicului:
- `take_damage()`: dacă e deja `golden` → `_die(2.0)` (instakill + 2× XP); altfel rulează `_try_golden()`, iar dacă iese, se aurește **fără să-i scadă viața** (lovitura îl îngheață, nu-l rănește).
- `_make_golden()`: `anim.pause()` îngheață **exact cadrul curent**, `modulate = GOLD_TINT`, oprește knockback-ul și orice tween de sclipire.
- `_physics_process`: `if _dying or golden: return` — aurit = complet înghețat (nici mișcare, nici schimbare de animație/culoare). De aia trebuie `anim.pause()` separat: `_process` nu mai cheamă `anim.play()`, dar `AnimatedSprite2D` își avansează singur cadrele dacă nu e pausat.
- `flash_electric()` are gardă pe `golden`, ca Thunder God să nu-i strice filtrul auriu.

**Șansa e pe player** (`duridama_chance() = duridama_stacks * 0.01`, plafon 1.0), citită de inamic. +1% pe luare.

**Capcană de rotunjire prinsă de test:** 2× XP aplicat pe valoarea deja scalată dădea raport **1.7**, nu 2 — la minutul 1 `xp_mult=2.6`, deci `round(2.6)=3` vs `round(5.2)=5`. Fix: rotunjesc **întâi** valoarea normală, apoi o dublez → 3 vs 6, exact 2×.

**Decizie luată singur (spune dacă vrei altfel):** Norocul NU umflă șansa Duridama (spre deosebire de crit/instakill). Aurirea + instakill garantat pe Legendary e deja foarte tare; n-am vrut s-o fac și mai probabilă fără să ceri. Se adaugă ușor (`+ luck_bonus()` în `duridama_chance`) dacă vrei.

**Verificat pe jocul real:** șansa se adună (0.01/stack, plafon 1.0); lovitura 1 aurește fără pierdere de HP, `anim.pause()` confirmat, modulate auriu, inamicul nu se mișcă 0.5s; lovitura 2 dă instakill + o gemă; raport XP aurit/normal **exact 2.0**; poză cu aurii lângă normali (se disting clar); cardul de level up arată corect (trofeu auriu, Legendary).

**Codex:** adăugat + republicat, iconița injectată. Sync: **40 = 40**.

---

## Session log — 2026-07-20 (Rabbit's Foot → move speed · Twin Comets pe proiectilele bonus)

**Cerut de Răzvan:** Rabbit's Foot să dea +25% viteză de MIȘCARE, nu de atac. Iar Twin Comets (gloanțe paralele) să se aplice și celorlalte proiectile, nu doar celui principal.

**Rabbit's Foot:** `upgrade_fire_rate(0.80)` → `p.speed *= 1.25` (model de la Alex's Protection, se compune la fiecare luare). Desc: „+25% Attack speed" → „+25% Move speed". Verificat: viteza 315 → 394 (+25%), cadența **neschimbată**.

**Twin Comets pe bonus:** înainte, `bullet_count` (paralelele) se aplica DOAR salvei principale; proiectilele Stacked Armory / Broken Watch trăgeau câte 1 glonț. Am extras salva într-un helper `_fire_volley(origin, dir, ...)` folosit și de salva principală, și de fiecare țintă bonus — deci fiecare proiectil bonus e acum o salvă întreagă. Verificat prin numărarea gloanțelor reale din lume: bullet_count=3 + 2× Stacked Armory → **9 gloanțe** (3 + 2×3); fără Twin Comets → 3 (1 + 2×1). Înainte ar fi fost 5.

**Codex:** ambele descrieri actualizate + republicat. Nota de sinergie „Ce nu ajunge la Stingător" rămâne validă (Twin Comets tot pe gloanțe). Sync: 39 = 39.

---

## Session log — 2026-07-20 (item nou: Tome of Knowledge)

**Cerut de Răzvan:** `upgrade_44` Tome of Knowledge (Rare) — 50% mai puțin XP până la nivel.

**Același model ca Grinder** (care e −15%): `p.xp_to_next = max(5, int(p.xp_to_next * 0.5))`. **De ce o reducere unică e de fapt permanentă:** pragul următor se calculează din `xp_to_next` curent (×1.2 pe nivel în `_level_up`), deci dacă îl tai o dată la jumătate, toate nivelurile de după rămân la jumătate. Se stivuiește (a doua luare = 25% din original).

**Verificat:** 20 → 10 → 5 pe două luări. Iconița se încarcă, rândul arată corect (carte deschisă, Rare).

**Codex:** adăugat și republicat, iconița injectată. Sync: **39 = 39** id-uri.

---

## Session log — 2026-07-20 (Adrenaline = „crit", nu „dublu damage" + liniuță în loc de punct)

**Cerut de Răzvan:** Adrenaline să fie crit, nu „șansă de dublu damage". Iar la descrieri, separatorul dintre statusuri (`+15 damage · +5 Max HP`) să fie liniuță ` - `, nu punctul `·`.

**Adrenaline era DEJA crit mecanic** — `p.crit_chance += 0.15`, iar criticul înmulțește cu `crit_mult = 2×`, de unde venea vechea formulare „damage dublu". Deci **n-am schimbat nicio mecanică**, doar textul înșelător: desc `+15% chance of double damage` → `+15% Crit chance`, plus comentariul și codexul. (Contribuia deja la rândul „Crit" din panou și se cumula cu Megane's Katana — nimic din astea nu s-a schimbat.)

**Punctul → liniuță** la toate cele 10 descrieri cu două statusuri. Făcut cu un regex care atinge **doar câmpul `desc`**, nu punctele din comentarii sau din alte texte (`· ` → ` - ` doar între `"desc": "..."`). Verificat: 0 descrieri mai au `·`.

**Codexul:** are texte proprii, mai bogate, unde `·` apare în propoziții, nu ca separator de statusuri — **acolo NU l-am atins**. Am corectat doar formularea lui Adrenaline (acuratețe, nu stil) și am republicat.

---

## Session log — 2026-07-20 (încă 2 iteme de noroc: The Office + Royal Flush)

**Cerut de Răzvan:** `upgrade_40` The Office (Uncommon) = +2.5 Luck și +5% Attack Speed · `upgrade_42` Royal Flush (Epic) = +10 Luck.

**Schimbarea care nu se vede în cerință: `luck` a trebuit să devină ZECIMAL.** Era `int`, iar The Office dă **+2.5** — cu întreg s-ar fi pierdut tăcut jumătatea la fiecare luare (2.5 → 2), și nimeni n-ar fi observat decât după ce nu ieșeau socotelile. Acum `var luck: float`.
- Afișarea în panou: `("%.1f" % luck).trim_suffix(".0")` — 2.5 rămâne „2.5", dar 5.0 se scrie „5", nu „5.0".

**Cadența** folosește convenția existentă: `upgrade_fire_rate(0.95)` pentru +5%, exact ca Rolling Papers care e `0.90` pentru +10%. **De reținut:** factorul înmulțește pauza dintre trageri, deci 0.95 înseamnă de fapt **+5.3%** trageri pe secundă, nu fix 5%. Așa e peste tot în joc — nu am schimbat convenția pentru un singur item.

**Verificat:** stivuire 2.5 + 10 + 5 = **17.5**; noroc fracționar 2.5 dă exact jumătate din deplasarea lui 5 (C 28.75 · U 28.75 · R 21 · E 16 · L 5.5, total 100.00); crit 15% → 16% la 2.5 noroc, → 22% la 17.5; panoul afișează „2.5" și „5" corect; ambele iconițe se încarcă și rândurile arată bine pe ecran.

**Codex:** ambele iteme adăugate și republicat, cu o notă nouă „Cum se adună Norocul". Sincronizare: **38 = 38** id-uri, iar cele trei iconițe de noroc decodează la exact dimensiunile fișierelor originale.

---

## Session log — 2026-07-20 (item nou: Unusual Clover + statul NOROC)

**Cerut de Răzvan:** `upgrade_43` — Unusual Clover (Rare), **+5 Luck**. 5 noroc = −2.5% common, −2.5% uncommon, +2% rare, +2% epic, +1% legendary; în același timp +2% la fiecare item cu șansă (crit 15% → 17%).

**Norocul face DOUĂ lucruri diferite, în două fișiere:**
1. **Înclină rarităţile** (`levelup.gd`): `LUCK_TAKE` ia 0.5 puncte de la common și uncommon per punct de noroc, `LUCK_GIVE` împarte ce s-a luat în raportul **2:2:1** (rare:epic:legendary). Deci la 5 noroc iese exact ce s-a cerut.
2. **Umflă șansele itemelor** (`player.gd`): `LUCK_CHANCE_PER = 0.004` → +0.4 puncte procentuale per punct (5 noroc = +2%). Se aplică la crit, instakill, Broken Watch și Plugged In.

**Decizie de design pe care am luat-o singur (spune dacă vrei altfel):** norocul umflă doar șansele itemelor pe care **LE AI**. Fără Adrenaline, criticul rămâne 0%, nu 2% — altfel norocul ți-ar strecura mecanici pe care nu le-ai ales niciodată. De aia `crit_chance_now()` și `instakill_chance_now()` întorc 0 când itemul lipsește.

**`minf` din `_sanse_cu_noroc()` NU e cosmetic.** La 60+ noroc, common ar deveni **negativ** — iar un segment negativ pe „roata norocului" ar face ca raritatea de după el să înghită diferența, adică exact invers decât te-ai aștepta. Cu clamp la 0, ce se ia se și dă, deci **totalul rămâne 100 oricât noroc ai** (verificat până la 80: se saturează la C 0 · U 0 · R 44 · E 39 · L 17).

**Verificat cu cifre exacte:**
- calculat: 5 noroc → C 27.50 · U 27.50 · R 22.00 · E 17.00 · L 6.00, total 100.00 — exact ce s-a cerut;
- tras real, 120.000 de rânduri cu 5 noroc: abatere maximă **0.16 puncte procentuale**;
- crit 15% → **17%** la 5 noroc, **19%** la 10; instakill 5% → 7%;
- fără Adrenaline\Hacksaw: **0%**, adică norocul chiar nu inventează șanse.

**Regresie de layout prinsă pe screenshot:** rândul nou „Luck" a făcut 13 rânduri în panoul de STATS, iar ultimul („Damage Taken") ieșea peste ramă — panoul are **înălțime fixă** și rândurile nu se micșorează singure. Spațierea a scăzut de la 7 la 3. **Dacă mai adaugi un stat, verifică marginea de jos a panoului.**

**Panoul arată acum valorile CU noroc** (`crit_chance_now()` în loc de `crit_chance`), plus un rând „Luck" — altfel ar fi scris 15% după ce criticul real devenise 17%.

**Codex:** actualizat și **republicat** (item + nota „Raritatea chiar contează acum"), iconița injectată base64. Sincronizare verificată: 36 = 36 id-uri, zero diferențe.

---

## Session log — 2026-07-20 (raritatea chiar contează + aureola cu 2px la stânga)

**Cerut de Răzvan:** raritatea să însemne ceva — Common 30% · Uncommon 30% · Rare 20% · Epic 15% · Legendary 5%. Plus aureola de la Stolen Halo mutată cu 2px la stânga.

**Până acum raritatea era DOAR culoare.** `_show_choices()` făcea `pool.shuffle()` + `slice(0, 3)`, adică alegere uniformă din toată lista. Efectul secundar perfid: cu cât o categorie avea mai PUȚINE iteme, cu atât fiecare item al ei ieșea mai des — dar categoria per total ieșea proporțional cu câte iteme are. Legendary (4 din 35) apărea în **11.4%** din rânduri.

**Acum se trage întâi raritatea, apoi un item din ea** (`_trage_raritate()` → `_trage_unul()` → `_trage_iteme()`, cu `RARITY_CHANCE` sus în `levelup.gd`). Consecință importantă: **câte iteme are o categorie nu-i mai schimbă șansa**. Adaugi un Legendary nou → Legendary rămâne 5%, doar se împarte între mai multe iteme.

**Cât s-a schimbat de fapt echilibrul** (uniform → ponderat): common 17.1% → **30%**, uncommon 25.7% → 30%, rare 22.9% → 20%, epic 22.9% → **15%**, legendary 11.4% → **5%**. Adică Legendary apare de peste **două ori mai rar**, iar Epic cu o treime mai rar. Rundele devin simțitor mai lente în putere — e exact ce s-a cerut, dar merită știut dacă începe să pară anemic.

**Verificat statistic**, pe 60.000 de rânduri: abatere maximă **0.24 puncte procentuale** față de țintă, **0** rânduri cu item dublat, și toate cele **35** de iteme apar (niciunul blocat de logica nouă).

**Plasa de siguranță:** dacă raritatea trasă n-are niciun item liber, se re-trage de `RARITY_TRIES` ori, apoi se ia orice a rămas. Nu se poate declanșa azi (cea mai mică categorie are 4 iteme, iar noi alegem 3), dar dacă cineva golește o categorie, rândul nu rămâne gol — ar bloca alegerea.

**Aureola:** `halo_side` de la `-2.0` la `-4.0` în `player.gd`. **Atenție, valoarea NU e în pixeli de ecran direct** — se împarte la scale-ul player-ului (2). Verificat: `-4.0` → poziție locală `-2.00` → **`-4.00` px pe ecran**, deci exact 2px mai la stânga decât înainte.

---

## Session log — 2026-07-20 (item nou: Undying Spirit + mecanica LIMBO)

**Cerut de Răzvan:** `upgrade_41` — „Undyind Spirit" (**typo, l-am scris `Undying Spirit`**). Când mori te duce într-o lume fără structuri, alb-negru, cu mulți inamici deodată, de dificultatea de acum 1 minut; reziști 1 minut și te întorci unde ai rămas, fără inamicii care erau pe tine.

**Decis cu el (întrebat explicit, nu presupus):** o singură dată pe rundă · te trezești cu **50%** din viața maximă · dacă mori în Limbo e **Game Over definitiv**.

**Descrierea din joc e doar „Second chance"** — cerută scurtă intenționat, ca să nu strice surpriza. Explicația întreagă stă în codex, nu pe cardul de level up.

**Cum e făcut — NU se încarcă altă scenă.** Rămânem în aceeași lume și o dezbrăcăm (`limbo.gd`, nod `Limbo` în `main.tscn`, CanvasLayer pe `layer = 5` — peste HUD, sub Game Over-ul de pe 20):
- generatoarele de decor (`Props`, `Rocks`, `DesertStructures`, `Statues`) sunt oprite, ascunse **și golite**;
- spawner-ul normal e oprit (grup nou `"spawner"`), ca să nu curgă inamici de dificultatea reală;
- `Difficulty` primește `frozen` + `mult_time_override`;
- shader alb-negru peste ecran (`limbo_bw.gdshader`).
Avantajul: nu se pierde nimic din starea rundei (upgrade-uri, XP, poziție).

**Capcana cea mai urâtă — golirea generatoarelor.** Nu e destul să le ascunzi (hitbox-urile rămân, te lovești de copaci invizibili) și nu e destul să le ștergi copiii: fiecare ține un dicționar `_loaded` cu chunk-urile puse. Dacă nu-l golești odată cu ele, la revenire crede că bucățile alea există deja și **lumea rămâne goală pe veci**. Verificat: 50 structuri → 0 în Limbo → 50 înapoi.

**Dificultatea „de acum un minut"** e un override curat în `difficulty.gd`: `_mult_time()` alimentează DOAR multiplicatorii (viață/viteză/spawn), pe când ce se vede pe ecran (cronometru, anunțul de Final Swarm) rămâne pe `time`. Astfel timpul rundei poate sta înghețat fără să se strice HUD-ul. Măsurat: la minutul 3:00 `enemy_hp_mult` normal = **2.66**, în Limbo = **2.11** (adică exact 2:01).

**Cronometrul de Limbo — desenat de `limbo.gd`, NU de HUD.** Numără invers de la 1:00, mare (64 vs 44) și roșu aprins; HUD-ul își ascunde cronometrul lui cât ești acolo (oricum e înghețat, ar fi stat blocat degeaba).
- **De ce nu în HUD:** filtrul alb-negru e pe `layer = 5`, adică PESTE HUD (layer 0) — deci îi mănâncă și lui culoarea. Prima variantă chiar așa a ieșit: cronometrul se mărea corect, dar apărea **gri**, oricât roșu îi dădeam. Testul l-a prins, nu ochiul. Acum eticheta stă în aceeași CanvasLayer cu overlay-ul, adăugată DUPĂ el → se desenează peste filtru și rămâne roșie. **Orice vrei colorat în Limbo trebuie pus acolo, nu în HUD.**
- `ceil` la afișare, altfel la intrare ar scrie 0:59 în loc de 1:00.

**Bug găsit de test, nu de mine:** la moartea ÎN Limbo, `_process` ieșea devreme și lăsa `Difficulty.frozen` + spawner-ul oprit agățate peste ecranul de Game Over. Acum există `_abort()`, care eliberează starea globală dar NU te mută și NU stinge alb-negrul (mori acolo, cu atmosferă cu tot).

**Testat pe jocul real** (`main.tscn` instanțiat, rundă dusă la minutul 3, player omorât): intrare (viață 50/100, 0 structuri, 40 inamici, dificultate 2:01, cronometru înghețat) → ieșire după minut (structuri regenerate, dificultate repornită, **întors exact pe poziția morții**, inamici șterși) → **a doua moarte = Game Over real**. Prima rulare a arătat calea de moarte-în-Limbo, fiindcă player-ul de test nu se apără; ca să pot testa și întoarcerea, l-am făcut rezistent DUPĂ verificarea vieții de intrare.

**Codex — actualizat ȘI republicat** pe același URL (item + nota „Limbo nu e o a doua viață"). Iconița `upgrade_41.png` a fost injectată base64 în `const ICONS={...}` din `codex.html` (13092 caractere; verificat că decodează înapoi în exact cei 9817 octeți ai PNG-ului original).
- **Capcană la injectare:** verificarea „există deja iconița?" nu se poate face căutând `upgrade_41.png` în tot fișierul — numele apare și în `ITEMS`, deci pare mereu prezent și nu injectezi niciodată. Caută `"upgrade_41.png":"data:`.
- **Verificare de sincronizare** (merită rulată la fiecare item nou): extrage id-urile din `levelup.gd` și din `codex.html` și compară-le cu `comm`. Acum: 35 = 35, zero diferențe.

---

## Session log — 2026-07-20 (BUG: structuri înfipte una în alta — cactus în casă, piatră în cactus, statuie în piatră)

**Cerut de Răzvan:** screenshot cu un cactus crescut prin casa abandonată + „poate așa interacționează și alte structuri între ele".

**Nu am ghicit — am măsurat.** Test care rulează generarea REALĂ pe 2809 chunk-uri și caută hitbox-uri care se intersectează. Start: **2 suprapuneri din 519 structuri** (rare, de asta a apărut abia acum). Apoi un al doilea test, între sisteme diferite. Patru bug-uri, toate din aceeași familie: *fiecare sistem se verifică doar pe el însuși*.

**1. Regula de departajare se aplica și caselor.** `_too_close()` avea o regulă „cine are cheia de chunk mai mică câștigă", ca doi cactuși vecini să nu dispară amândoi. Dar casele/monumentele **nu sunt sărite niciodată**, deci un cactus lângă o casă dintr-un chunk cu cheia „mai mare" pur și simplu o ignora. **Ambele** suprapuneri din test veneau de aici. Acum: în fața unei structuri „special", cactusul se dă la o parte MEREU; regula de ordine rămâne doar cactus-cactus.

**2. Distanțele se măsurau între puncte necomparabile.** Nodul e coborât cu `sort_shift`, iar colliderul are propriul offset — diferite per tip (monument −156px, cactus −48px). Testul folosea pozițiile brute. A doua suprapunere avea monumentul cu poziția brută într-un chunk și hitbox-ul în cel de dedesubt. Acum `_footprint_center()` dă centrul real de hitbox și distanța se măsoară între alea.

**3. Raza de căutare era prea mică.** Vecinii se luau pe ±1 chunk (512px), dar distanța minimă cactus-casă e **691px** — o casă putea cădea în al doilea chunk și să scape neverificată. Acum `_neighbor_radius()` o calculează din cea mai mare distanță minimă dintre tipuri.

**4. Casele și monumentele nu se verificau ÎNTRE ELE deloc** — erau puse la întâmplare în deșert. Acum `_desert_specials()` le generează pe deșert întreg (nu pe chunk, cu cache per macro-celulă), cu `SPECIAL_TRIES` încercări fiecare. Dacă deșertul e prea mic, **nu sar structura** (casele sunt garantate), ci aleg poziția cea mai depărtată. Prag separat `min_gap_specials = 1.2` — cu pragul de cactus (3.0) n-ar încăpea două case într-un deșert mic.

**Între sisteme (măsurat separat):**
- **Pietrele intrau în cactuși** (3 cazuri): `rocks.gd` se excludea din deșert **pe chunk** (`is_desert_chunk`), dar cactușii apar și pe gradientul de la margine → rămânea o fâșie unde intrau amândoi. Acum verifică **pe poziție** (`desertness > 0.0`), exact ca la copaci în `props.gd`.
- **Statuile intrau în pietre** (3 cazuri): `statues.gd` se ferea doar de copaci. Acum și de pietre (`_langa_piatra`, `min_dist_rock = 150`).
- Copacii erau deja curați (excluși din deșert pe poziție).

**Rezultat, tot măsurat:** 0 suprapuneri pe toate cele patru combinații. Costul: 511→496 cactuși, 820→680 pietre (cele de pe nisip), 65→64 statui. Casele și monumentele își păstrează numărul garantat (4 și 4). Poză de sus peste un deșert cu casă: spațiu curat în jur, densitatea neschimbată.

**De reținut pentru orice sistem nou de generare:** dacă pui obiecte în lume, nu e destul să te ferești de tine însuți. Familia asta de bug-uri reapare la fiecare sistem adăugat.

---

## Session log — 2026-07-20 (fundalul de meniu: trecere lină între cadre)

**Cerut de Răzvan:** „animația de background nu e smooth deloc".

**Cauza:** sursa are **10 cadre pe secundă**, iar jocul redă la 60 — deci fiecare cadru stă 6 cadre redate și apoi sare. Nu era o problemă de fps al jocului.

**Soluția — cross-fade între cadre.** Un al doilea `TextureRect` (`_bg_next`) exact peste primul ține **cadrul următor**, iar `modulate.a` îi urcă de la 0 la 1 pe durata unui cadru de sursă (`_frame_t / step`). `_tick_bg()` a fost spart în `_advance_frame()` (mișcă starea) și `_peek_next_frame()` (doar se uită înainte, fără s-o mute) — necesar fiindcă la capetele ping-pong-ului „următorul" nu e `_frame_i + 1`, ci se întoarce.

**Capcana reală, care a mâncat o rundă: shaderul de blur ignora `modulate`.** `menu_blur.gdshader` făcea `COLOR = texture(...)`, adică **scria peste** COLOR-ul de intrare, care conține transparența pusă din cod. Stratul de sus se desena mereu opac → cross-fade-ul nu avea niciun efect, deși codul GDScript era corect. Fix: `vec4 mod_col = COLOR;` la început, `* mod_col` la final, pe **ambele** ramuri (și pe scurtătura fără blur). **`MODULATE` nu există în Godot 4.7** — am încercat întâi așa și shaderul a picat la compilare; Godot cade atunci pe shaderul implicit, care respectă modulate, deci **măsurătorile ies brusc „bune" dar fără blur**. Dacă vezi netezime perfectă și imagine clară în același timp, caută `SHADER ERROR` în stdout.

**Măsurat, nu privit:** diferența medie de luminozitate între cadre redate consecutiv.
- Înainte: 34 din 41 de cadre **identice**, apoi salt (raport maxim/mediu **7.4**) — exact tiparul sacadării.
- După: diferențe distribuite egal, 0.03–0.11, raport maxim/mediu **1.9**.
- Blur-ul confirmat separat (altfel „netezimea" putea veni din shaderul picat): contrastul local scade cu **74%** față de imaginea curată. **Banda de măsurat trebuie să fie fără UI** — prima oară am eșantionat o zonă în care apare logo-ul și ieșea că blur-ul *crește* claritatea cu 700%.
- Poză la alpha 0.56 (mijlocul amestecului, pe fundal **neblurat**, unde s-ar vedea cel mai tare): fără imagine dublă. Mișcarea între cadre e mică, deci amestecul nu se citește ca fantomă.

**De știut:** shaderul se aplică acum corect pe orice `modulate` pus pe fundal — dacă vrei vreodată să stingi fundalul în fade, merge direct.

---

## Session log — 2026-07-20 (butoanele de meniu: culori de lemn în loc de cyan)

**Cerut de Răzvan:** culoarea principală a butoanelor `#9e603f`, secundara `#594232`.

**Interpretare:** principala = **umplutura**, secundara = **conturul** (principala e cea care ocupă suprafața). Dacă voia invers, se schimbă între ele cele două constante.

**Unde:** `BTN_MAIN` / `BTN_SECOND`, constante sus în `menu.gd`, folosite în `_menu_button()`. Deci prind toate butoanele mari — inclusiv BACK-urile din celelalte panouri. `hover`\`pressed` nu sunt culori noi de întreținut: aceleași două, cu `.lightened(0.10)` / `.lightened(0.20)`. Textul a trecut de la alb-albăstrui la crem, fiindcă albul rece se bătea cu maro; `font_hover_color` era ACCENT (cyan) — evident nepotrivit acum.

**Butoanele au devenit OPACE.** Stilul vechi avea alpha 0.85–0.95, iar peste fundalul blurat butoanele de sus (peste cer) ieșeau vizibil mai deschise decât cele de jos (peste iarbă) — aceeași culoare, aspect diferit. Cu hex-uri cerute explicit, transparența ar fi însemnat că nu vezi niciodată culoarea cerută.

**NU s-au atins** butoanele de armă (`_build_weapon`, verde\cyan pe selecție) și cele de cumpărat din shop (verzi) — au stilurile lor. Dacă se vrea toată paleta pe lemn, alea sunt următoarele.

**Capcană de test, nu de joc:** `_shot()` din scriptul de verificare e o corutină; chemată **fără `await`**, poza se salva după ce apucam să schimb stilurile, așa că „poza normală" arăta de fapt hover+pressed. Am pierdut o rundă crezând că e bug de culoare. La orice `_shot()` care e urmat de alte schimbări: `await _shot(...)`.

**Verificat pe pixeli**, nu doar din ochi: umplutura `#9E603F` și conturul `#594232` exact, contur de 3px (scanare pe orizontală prin marginea butonului). Plus poză cu hover și pressed, ca să se vadă că se disting între ele.

---

## Session log — 2026-07-20 (intro meniu: fundal viu din prima + titlul urcă lin)

**Cerut de Răzvan (în două runde):** pauză de încă o secundă între titlu și butoane; apoi „animația de background să ruleze din prima, nu să aștepte" și „titlul să nu se teleporteze, să meargă smooth până în locul lui".

**Cronologia intro-ului acum:** `INTRO_CLEAR` 1.0s fundal animat curat → `INTRO_FADE` 0.6s intră blur + titlul (în mijlocul ecranului) → `INTRO_HOLD` 1.0s titlul stă singur → `INTRO_RISE` 0.7s titlul urcă la locul lui, cu butoanele aprinzându-se (`INTRO_BUTTONS` 0.35s) pe la jumătatea urcării. Meniul e complet pe la ~3.3s.

**Fundalul pornea înghețat** fiindcă `_animating` se punea pe `true` abia după `INTRO_CLEAR`, iar până atunci se afișa cadrul static de 720p (`bg_still.webp`). Acum `_bg_setup()` pune direct `_frames[0]` și `_animating = true`. **Compromisul acceptat:** prima secundă, cât imaginea e clară, se văd cadrele de 640×360 întinse la 720p, nu still-ul de 720p. Pe arta asta (plată, pictată) nu se observă — verificat pe screenshot. Still-ul rămâne doar ca rezervă dacă lipsesc cadrele.

**„Teleportarea" titlului era layout, nu animație.** Titlul și butoanele stăteau în același `VBoxContainer` centrat: cât butoanele erau `visible = false` nu ocupau loc, deci cutia era scundă și titlul ieșea în mijloc; când apăreau butoanele, cutia creștea și titlul sărea sus dintr-un cadru. Pauza de 1s adăugată mai devreme doar a făcut saltul mai vizibil. Două schimbări:
- **Butoanele își țin locul tot timpul** — rămân `visible`, doar cu `modulate.a = 0` și `disabled = true` (`_set_buttons_enabled()`). Layout-ul e final din primul cadru, deci nimic nu mai sare. `disabled` (nu `mouse_filter`) fiindcă blochează și focus/tastatură, nu doar mouse-ul.
- **Titlul se mișcă singur, în interiorul unui slot fix.** Nu poți anima poziția unui copil de container (containerul i-o rescrie la fiecare layout), așa că `_title_group` a devenit un `Control` simplu de `TITLE_SIZE × TITLE_SIZE` care ține locul în VBox, iar `_title_mover` (logo-ul, ancorat FULL_RECT în el) e mutat liber. `_title_rise_offset()` calculează cât de jos pornește: exact cât să fie centrat pe ecran. Tween cubic EASE_IN_OUT până la `position:y = 0`.
- **Offset-ul se calculează după `await get_tree().process_frame`** — înainte de primul layout toate pozițiile sunt zero și ar ieși un offset greșit.

**Skip la apăsare pe ecran** (`_input()` + `_skip_intro()`): orice touch\click\tastă cât `_intro_running` e true duce meniul direct în starea finală. Două capcane, ambele rezolvate:
- **Tween-urile pornite trebuie omorâte**, altfel continuă să scrie peste valorile puse de skip și meniul „se dezface" înapoi. De aia se țin în `_intro_tweens`.
- **Corutina `_play_intro()` trăiește mai departe după skip** — `await`-urile pe timer nu se pot anula. După fiecare `await` are acum `if not _intro_running: return`, altfel ar reaprinde butoanele sau ar repoziționa titlul peste starea finală.
- Butoanele se activează abia din **cadrul următor** (`await get_tree().process_frame`), ca apăsarea care a dat skip să nu ajungă din greșeală pe START.

**Verificat vizual** cu screenshot-uri la 0.25s / 0.85s (fundalul se mișcă — cadre diferite), 2.0s (titlu centrat, fără butoane), 2.9s (titlu la jumătatea urcării), 3.1s (butoane pe la jumătatea fade-ului) și 3.7s (meniu final, identic cu cel dinainte). **Skip testat la 0.4s / 1.3s / 2.9s** (înainte de fade, în timpul fade-ului, în timpul urcării) — toate trei ajung la exact aceeași stare: `title y=0.0`, `blur=3.00`, `alpha butoane=1.00`, toate cele 5 butoane active. Plus o rulare fără skip, ca să nu fi stricat drumul normal.

---

## Session log — 2026-07-19 (Garda: rafală la 10s + contur negru pe bila de lightning)

**Cerut:** „o dată la 10 secunde un special attack care aruncă atacul lui normal de 3 ori unul după altul foarte rapid" + „la fiecare frame din animația de atac a gărzii un stroke negru de 2px".

**Rafala** (`garda.gd`): `special_interval` 10s, `special_shots` 3, `special_gap` 0.12s.
- **Derulată cu un contor din `_physics_process`, NU cu `await`.** Dacă garda moare în mijlocul rafalei, o corutină și-ar relua firul pe un nod deja eliberat; contorul dispare odată cu nodul. (Am ales asta din start tocmai ca să nu apară bug-ul.)
- **Ținta se recitește la fiecare bilă** → rafala te urmărește dacă fugi, nu pleacă toate trei spre locul unde erai.
- Cât ține rafala, atacul normal tace (`return`), iar după ea `_atk_cooldown` primește o pauză, ca bila normală să nu se lipească de coada rafalei.
- **Măsurat pe 13s:** normale la 2438/4452/6472/8500ms (cadență 2s, neschimbată), rafală la **9556 / 9688 / 9820** (+132ms între bile — 120 configurat, restul e cuantizarea la 60fps), apoi normalul reia la 10903. Zero erori „flushing queries", deși bilele se adaugă în timpul fizicii.

**Conturul negru** — „animația de atac a gărzii" = **cele 10 cadre ale bilei de lightning** (`boss/lightning_burst_003_large_violet/`). Garda **nu are** animație proprie de atac: are doar `summon` + mers pe 8 direcții. Dacă Răzvan voia altceva, asta e presupunerea de corectat.
- Scriptul: `scratchpad\stroke.ps1` (PowerShell + System.Drawing, ca la tăiatul GIF-urilor — n-avem ImageMagick/Python). Pune negru opac unde era transparent și există pixel opac la distanță ≤ R, **disc, nu pătrat** (colțuri rotunjite). Pixelii originali nu se ating. Masca se citește din desenul ORIGINAL, altfel negrul proaspăt ar genera și mai mult negru.
- **PNG-urile modificate TREBUIE reimportate** (`--headless --import`), altfel jocul rulează cadrele vechi din cache. Vezi și nota din `joc-bzn-run-verify`.
- **Capcană PowerShell:** parametrul `-Out` s-a ciocnit cu variabila `$out` din script (PowerShell nu ține cont de majuscule) → obiectul devenea String și tot scriptul crăpa în cascadă. Redenumit `$OutPath`. La fel, array-urile nu trec corect prin `-File`; cu `-Command` merg.
- **Rezultatul e discutabil vizual și i-am arătat comparația.** Arta are o grămadă de scântei de 1-2px; un contur de 2px le transformă în bulgări unde negrul e mai mare decât scânteia. Inelul mare arată bine conturat. Am lăsat **2px, cum a cerut**, și am pregătit varianta de 1px — dacă zice, se reaplică din originalele din git într-o comandă.

---

## Session log — 2026-07-19 (Panic Button: cutremur + undă de șoc, stil Mama Mega)

**Cerut:** „când dai Panic Button să fie un cutremur și o rază care vine dinspre player, aia dă damage-ul (ca la Binding of Isaac — Mama Mega)".

**Damage-ul îl dă acum UNDA, nu itemul.** `shockwave.gd` (nod nou) se umflă din player și lovește fiecare inamic **când frontul ajunge la el** — cei de lângă tine mor primii, apoi valul se rostogolește spre margini. Verifică distanțele în fiecare cadru, nu o dată la spawn: inamicii se mișcă, iar unul care fuge spre margine trebuie prins când îl ajunge valul. Ține un dicționar de `instance_id` ca nimeni să nu încaseze de două ori. Rulează în `_process`, nu în fizică — aceeași capcană „flushing queries" ca la Thunder God.

**Cutremurul e un mecanism nou, nu `add_shake` mai mare.** `add_shake` e un vârf de trauma care la `shake_decay = 4` se stinge în ~0.15s: bun pentru un critic, inutil pentru un cutremur. `start_quake(dur, strength)` **reîncarcă** trauma în fiecare cadru cât ține, slăbind spre final. Măsurat: trauma la 0.15s = **0.68** (înainte era ~0 acolo), la 0.70s = 0.15, la 1.30s = 0.

**Raza e calculată, nu constantă:** `_raza_ecran()` = jumătatea de diagonală a zonei vizibile (viewport ÷ zoom-ul camerei) + 64px. Dă **1008px** la setările de acum. O constantă s-ar fi stricat la alt zoom sau altă rezoluție de telefon.

**Acoperirea nu s-a schimbat în practică**, deși unda are acum o rază finită iar varianta veche lovea toată harta: inamicii apar la `spawn_distance` = **700px** și vin spre tine, deci sunt mereu sub 1008. Dacă vreodată crește `spawn_distance` peste ~950, Panic Button începe să rateze inamici — atunci se leagă `_raza_ecran()` de el.

**Două capcane de măsurătoare/vizual, ambele prinse prin verificare:**
1. **Prima măsurătoare a ordinii loviturilor a ieșit falsă** (60px și 400px lovite în același milisecund). Cauza: primul cadru după încărcarea scenei are `delta` uriaș, unda sărea direct la jumătate. După ce am lăsat framerate-ul să se așeze: 60px → +23ms, 200 → +52, 400 → +136, 700 → +260. **Orice test de animație pornit imediat după încărcarea scenei minte.**
2. **Grosimile din `_draw` sunt mari intenționat** (80→24px). Prima încercare, 26→6px, ieșea ca niște fire abia vizibile — fiindcă `atmosphere.gd` pune o vignetă peste toată lumea (CanvasLayer 3), iar unda e pe sol sub ea, deci culorile se spală; plus camera pe zoom 0.7 subțiază tot cu ~30%. Dacă se schimbă vigneta sau zoom-ul, acolo se reglează.

**Verificat vizual** la mijlocul măturării: inelul se citește clar peste tot ecranul.

---

## Session log — 2026-07-19 (umbră la cactuși + `ground_shadow.gd`)

**Cerut:** „adaugă umbră la toți cactușii ca la copaci".

**Codul de umbră a ieșit din `props.gd` în `ground_shadow.gd`** (fișier nou, funcții statice) în loc să fie copiat. Nu era doar desenul elipsei: și scanarea pixelilor care găsește conturul opac (`used_rect`) și **banda de trunchi** (`trunk_rect`) — adică exact reglajul greu de pe 2026-07-19, care așază umbra pe trunchi, nu pe mijlocul coroanei. Două copii ale acelei măsurători s-ar fi desincronizat la prima ajustare.

- `props.gd` păstrează aceleași `_used` / `_trunk` / `_trunk_center_x` / `_base_y` ca **scurtături** — le folosește și hitbox-ul, nu doar umbra, deci n-am vrut să rescriu apelanții.
- **Fără `class_name`** în `ground_shadow.gd`. Am încercat întâi cu `class_name GroundShadow` și rularea directă a crăpat: `Identifier "GroundShadow" not declared` — numele globale se înregistrează doar când proiectul e **deschis în editor**, iar eu rulez jocul din linia de comandă. Fiecare utilizator îl ia cu `const GroundShadow := preload("res://ground_shadow.gd")`, ca la `LEAFFALL`. **De ținut minte pentru orice script nou partajat.**

**Umbra e per-tip, prin cheia opțională `shadow` din `CONFIG`** (`desert_structures.gd`): dacă lipsește, structura n-are umbră. Doar cactusul o are. Casa și monumentul n-au fost cerute — și oricum o elipsă turtită sub un perete drept arată prost; dacă le vrei, cheia e acolo.

**Reglaj:** `width` 0.85 la cactus vs **0.60** la copac. Nu e o valoare aleasă la ochi — lățimea e o fracție din conturul obiectului, iar cactusul e mult mai îngust decât un copac, deci aceeași fracție dădea o pată de nimic sub el.

**Verificat vizual** (3 cactuși + un copac pe nisip): umbrele cad centrat pe bază, în același stil, iar **copacul a rămas identic** după refactor.

---

## Session log — 2026-07-19 (Thunder God pe Stingător + BUG: Plugged In era mort de tot)

**Cerut:** „vreau să meargă Thunder God și cu Stingătorul". Era a treia armă rămasă pe dinafară (mergea deja pe glonț și pe sabie).

**Un singur lanț pe puls, dintr-un inamic lovit la întâmplare** — nu câte unul din fiecare inamic prins de aură. Aura lovește tot ce prinde deodată, deci un lanț de fiecare ar da N×N arcuri per puls (10 inamici = 90 de arcuri, de câteva ori pe secundă): ilizibil și greu. Un lanț per puls păstrează regula celorlalte arme: **un impact = o descărcare**. Inamicii morți din puls sunt filtrați (`is_instance_valid`) înainte de a alege sursa.

**BUG găsit în drum — Plugged In nu făcea NIMIC de când există (2026-07-17).** `thunder_burst` începea cu `if thunder_stacks <= 0: return`. Dar Plugged In lasă `thunder_stacks` pe 0 — el trece doar rostogolirea din `thunder_active_on_hit()`. Deci: rostogolirea de 10% ieșea true, se chema `thunder_burst`, și burst-ul ieșea imediat pe ușă. Zero arcuri, zero damage. Itemul era decor pur.

- **Cauza de fond:** decizia „se declanșează?" era luată în **două** locuri. `thunder_active_on_hit()` e singura poartă și e chemată de toți cei 3 apelanți; verificarea duplicată din `thunder_burst` doar contrazicea poarta.
- **Fix:** guard-ul acceptă acum oricare sursă (`thunder_stacks <= 0 and plugged_in_stacks <= 0`).
- **Verificat empiric, în ambele sensuri:** cu Plugged In la 100% (10 stack-uri) și aura pe 8 inamici → **0 arcuri cu codul vechi, 2 cu cel nou**. Thunder God dădea 2 în ambele cazuri (2 și nu 7 fiindcă `thunder_range` = 200px, iar inamicii de pe partea opusă a cercului sunt mai departe — corect).

**Lecție:** când o poartă de decizie e deja centralizată, verificarea „de siguranță" repetată în aval nu e gratis — aici a omorât un item întreg, în tăcere, timp de 2 zile.

---

## Session log — 2026-07-19 (Thunder God: arcul stă lipit de inamici)

**Reclamația lui Răzvan:** „thunder god lasă animația în urmă, vreau să urmărească inamicii (să stea ca o frânghie între ei lipită)".

**Cauza:** `_spawn_electric_arc` întindea arcul **o singură dată**, la spawn: calcula poziția/unghiul/lungimea din pozițiile de atunci și le scria fix pe `AnimatedSprite2D`. Inamicii se mișcă în continuare cele ~0.5s cât ține animația (14 cadre @ 30fps) → arcul rămânea plutind în urma lor.

**Rezolvarea:** `electric_arc.gd` (fișier nou), pus pe sprite-ul arcului. Ține cele două **noduri** de la capete și în `_process` reface în fiecare cadru `global_position` (mijlocul), `rotation` și `scale.y` (= distanța / înălțimea cadrului). Aceeași matematică de dinainte, doar că rulată continuu, nu o dată.

- **Capătul de origine** (inamicul lovit) se recuperează din `exclude_id` cu `instance_from_id` în `thunder_burst`. Poate fi deja **mort** — `thunder_burst` e `call_deferred`, exact motivul pentru care lucrează pe poziție + id (vezi log-ul din 2026-07-17). Dacă e mort, `src_node` rămâne `null`.
- **Capăt mort = poziție înghețată**, nu arc dispărut: `electric_arc.gd` actualizează `from_pos`/`to_pos` doar când nodul e `is_instance_valid`, altfel păstrează ultima valoare. Așa arată natural când moare un inamic în timpul descărcării.
- `_spawn_electric_arc(from, to, n_from := null, n_to := null)` — nodurile sunt opționale, deci un apel vechi cu doar 2 puncte încă merge (arc fix, ca înainte).

**Verificat** cu o scenă temporară: două noduri mutate după spawn → mijlocul arcului și lungimea lui se potrivesc **exact** cu noile poziții (375,325 vs 375,325; lungime 570.09 vs distanță 570.09). Și `player.gd` compilează.

**Nu am atins** damage-ul, raza (200px), `thunder_active_on_hit` sau Plugged In — doar vizualul.

---

## Session log — 2026-07-19 (artă nouă de copaci)

**Ce a făcut Răzvan:** a șters `harta/trees/spr_tree_1..16.png` și a pus `Tree Variant 1..7.png`. Deci **16 variante → 7**, și canvas **64x64 → 128x128**.

**Capcana:** dublarea canvasului NU înseamnă că împarți `tree_scale` la 2. Ce contează e cât din canvas ocupă desenul, iar arta nouă e mult mai „plină":

| | canvas | desen vizibil | ocupare |
|---|---|---|---|
| vechi | 64x64 | ~40x49 | 62% / 77% |
| nou | 128x128 | ~97x120 | 76% / 94% |

Deci raportul real e **~1.85**, nu 2.25. `tree_scale`: 4.5 → **1.85**, ca să rămână ~180x220px pe ecran, exact ca înainte.

**`hitbox_factor` a trebuit și el mutat**, fiindcă e fracție din lățimea **canvasului**, nu din copacul vizibil: 0.20 → **0.24**, ca hitbox-ul să rămână la ~114px lățime reală (era 115). Cele 4 laturi din `main.tscn` (`hitbox_north/south/east/west`) sunt fracții din `base_w`, deci se traduc singure — nu le-am atins.

**`sort_anchor` a rămas 0.35.** Verificat prin măsurare, nu ghicit: linia de sortare cade la **31%** din înălțimea copacului vechi și **34%** din a celui nou. Diferență neglijabilă.

**Metoda de măsurare** (utilă data viitoare): conturul opac real al unui PNG se scoate cu PowerShell + `System.Drawing`, scanând alpha > 8 — vezi comenzile din această sesiune. `get_used_rect` din Godot dă același lucru, dar cere să rulezi engine-ul.

**De verificat dacă apar reclamații:** `LEAF_ZONE_*` (zona în care cad frunzele) au fost derivate din desenul lui Răzvan peste copacii **vechi**. Sunt fracții din conturul vizibil, deci se traduc în principiu, dar coroana nouă are altă formă — dacă frunzele par că pică pe lângă copac, acolo e reglajul.

**Verificat vizual** în `main.tscn`: copacii apar la scara corectă față de player, cu pietre și restul lumii nemodificate.

**Hitbox-urile și umbrele se măsoară acum din TRUNCHI, nu din canvas** (2026-07-19, după ce Răzvan a zis că hitbox-urile „sunt ca pula" — avea dreptate).

**Ce era greșit:** `hitbox_factor` era fracție din lățimea **canvasului**, iar poziția pe Y venea din `sort_anchor` × înălțimea canvasului. Pus pe desen cu `--debug-collisions`, ieșea o **bară lată plutind prin mijlocul coroanei**: te blocai în frunze și treceai prin trunchi. Umbra avea aceeași boală — centrată pe mijlocul conturului întreg, adică al coroanei, deci la copacii cu coroana lăsată într-o parte cădea pe lângă trunchi.

**Fix:** `_trunk(tex)` scanează banda de jos a copacului (ultimele `TRUNK_BAND` = 18% din înălțimea vizibilă) și returnează întinderea pixelilor opaci — adică trunchiul cu rădăcinile. De acolo:
- `_hitbox_w()` = lățimea trunchiului × `hitbox_factor` (acum **0.85, fracție din trunchi**, nu din canvas);
- cutia se așază **cu marginea de jos pe rădăcină**, centrată pe mijlocul trunchiului (`_trunk_center_x`, `_base_y`);
- umbra ia **lățimea din coroană** (ea aruncă umbra) dar **poziția din trunchi**.

**Consecință importantă:** rămâne **`tree_scale` singura valoare legată de dimensiunea texturii**. La următoarea schimbare de artă doar ea trebuie recalculată; hitbox-ul și umbra se potrivesc singure.

**Am șters cele 4 reglaje de laturi din `main.tscn`** (`hitbox_north/south/east/west` = -0.1 / -0.5 / 0.1 / -0.3). Erau calibrate pentru cutia veche și, fiind fracții din `base_w`, pe geometria nouă ar fi deformat-o (`south -0.5` tăia jumătate din trunchi). Acum sunt 0; exporturile rămân, pentru reglaj fin.

**`_min_dist()` folosește același `_hitbox_w()`** — distanța dintre copaci și cutia de coliziune nu mai pot ajunge să nu fie de acord.

**Reglajul final l-a făcut Răzvan singur, în editor**, peste cutia derivată din trunchi:
- `hitbox_east` = `hitbox_west` = **0.5** → cutia iese **dublul** lățimii derivate. Trunchiul gol se simțea prea subțire când intrai în el.
- `hitbox_north` **0.2** + `hitbox_south` **−0.2** (al doilea pe nodul `Props` din `main.tscn`) → mută cutia în sus fără să-i schimbe înălțimea.
- `sort_anchor` 0.35 → **0.355**.

Astea sunt **gust, nu matematică** — cutia derivată din trunchi e baza pe care o modifică. Dacă se schimbă iar arta, baza se recalculează singură, dar aceste patru valori rămân și s-ar putea să nu mai fie potrivite.

**Apoi Răzvan i-a vrut cu 1.5x mai mari** → `tree_scale` 1.85 → **2.775**, dar s-a răzgândit în aceeași zi și i-a vrut înapoi → **1.85**. `hitbox_factor` NU s-a atins: `base_w` îl înmulțește cu `tree_scale`, deci hitbox-ul crește singur odată cu copacul, ceea ce e corect.

**Umbre la copaci** (tot atunci): `_make_shadow()` în `props.gd`. Un `GradientTexture2D` radial negru, turtit, **construit o singură dată în cod și refolosit** de toți copacii — nu e fișier de artă. Reglaje `@export`: `shadow_alpha` / `shadow_width` / `shadow_squash` / `shadow_shift_y`.
- **`z_index = -1`** e cheia: ține umbra pe sol, sub copac, sub player și sub ceilalți copaci, indiferent de sortarea pe Y. Aceeași soluție ca la urmele de foc.
- Lățimea se ia din **conturul vizibil** (`_used()`), nu din canvas — deci rămâne corectă dacă se schimbă iar arta.
- Prima încercare (alpha 0.30, miez până la 55%) ieșea prea difuză, arăta a vignetă. Reglat la **alpha 0.42, miez până la 72%** — se citește ca umbră, nu ca pată.
- `_used()` e helper nou; `_leaf_zone()` folosea același cod de cache, acum îl împart.

---

## Session log — 2026-07-19 (logo animat în loc de titlul-text)

**Cerut de Răzvan:** titlul scris cu text („ăla basic") să fie înlocuit cu logo-ul din `menu/Title/` — 4 cadre, mers **înainte-înapoi, destul de încet**.

**Făcut:** `_build_title()` + `_tick_title()` în `menu.gd`. Ping-pong la `TITLE_FRAME_TIME = 0.4` s/cadru (1→2→3→4→3→2→…), afișat la `TITLE_SIZE = 240`. Dacă lipsesc cadrele, cade înapoi pe vechiul titlu-text.

**Cadrele au fost redenumite** din `frame 1.png` … `Frame 4.png` în `title_1..4.png`. Motivul: spațiu în nume + `F` mare la al patrulea. Pe Windows merge, dar **Android are sistem de fișiere case-sensitive** — `Frame 4.png` ar fi crăpat la export, tăcut.

**Capcana de layout (a mușcat de două ori):** ecranul de referință e **1152×648** — proiectul nu setează `window/size/viewport_*`, deci e default-ul Godot. Cele 5 butoane ocupă singure **346px** (5 × 58 + 4 × 14 separare). La primele două încercări (logo 340, apoi 260) **butonul LEADERBOARD ieșea din ecran**. Regula: `TITLE_SIZE` + spacer ≤ ~274. Acum 240 + 16 = 256, cu ~23px marjă. **Dacă mai adaugi un buton în meniul principal, verifică marginea de jos.**

**Scos:** subtitlul „C Y B E R  S U R V I V O R" — numele e deja în logo, textul cyan se bătea cu stilul de lemn, și eliberează înălțime. Comentariul din `_build_main()` spune cum se aduce înapoi.

---

## Session log — 2026-07-19 (fundal animat în meniu + intro cu blur)

**Cerut de Răzvan:** `menu\main menu background.mp4` să ruleze la infinit în meniul principal, ca strat de jos, sub butoane. Plus: 1 secundă imaginea curată (fără titlu/butoane) → blur gaussian → apare titlul → imediat butoanele.

**Ce s-a făcut:** exact secvența de mai sus, în `menu.gd` (`_play_intro()`), cu blur-ul din `menu/menu_blur.gdshader` pus ca material pe fundal. Reglaje: `INTRO_CLEAR` / `INTRO_FADE` / `INTRO_BUTTONS` / `MENU_BLUR`. Titlul și butoanele stau acum în două containere separate (`_title_group`, `_main_buttons`) ca să poată fi stinse/aprinse independent.

**Capcana mare — Godot NU poate reda mp4.** Engine-ul are doar **Ogg Theora**; H.264 nu e inclus. Am convertit cu ffmpeg și **toate variantele de `.ogv` au ieșit corupte** (blocuri magenta/verzi după câteva secunde). Am izolat vina, nu am ghicit:
- mp4-ul sursă decodează **curat** cap-coadă;
- `.ogv`-ul crapă în **propriul decodor ffmpeg** (`error in unpack_block_qpis`, rată de eroare 0.92);
- persistă la `-b:v` și la `-q:v`, cu `-threads 1` și cu decodare single-thread.

Deci encoderul `libtheora` din build-ul Gyan 8.1.2 produce bitstream stricat. **Nu mai pierde timp pe Theora.**

**Soluția aleasă de Răzvan:** secvență de cadre în loc de video.
- `menu/bg_frames/` — 60 × WebP 640×360, 10 fps, 6 secunde, redate **ping-pong** (înainte apoi înapoi) ca reluarea să nu aibă tăietură. Derulate manual în `_process()`.
- `menu/bg_still.webp` — un singur cadru 720p, clar, pentru secunda de intro.

**De ce două rezoluții:** cadrele animate se văd **doar blurate** (blur-ul pornește la 1s și nu mai pleacă), deci 640×360 nu se observă. 60 de cadre la 720p ar fi însemnat **~440 MB VRAM** — inacceptabil pe renderer-ul Mobile. Așa: 0.8 MB pe disc, ~53 MB VRAM.

**Gotchas:**
- mp4-ul sursă (79 MB) e în `.gitignore` — există doar local la Răzvan. Cadrele generate sunt cele comise.
- Regenerarea cadrelor cere ffmpeg (`winget install Gyan.FFmpeg`); comenzile exacte sunt în acest log și în README.
- WebP-urile noi trebuie importate înainte de o rulare directă: `godot --headless --path <proj> --import`.
- `_bg_setup()` cade elegant înapoi pe gradientul vechi (`_gradient_bg()`) dacă lipsesc cadrele.

**Verificat vizual** cu screenshot-uri la 0.5s / 1.4s / 2.3s / 8s: intro curat, blur + titlu, butoane, și fără artefacte târziu în animație.

---

## Session log — 2026-07-19 (BUG: fâșii de iarbă prin deșert)

**Simptom** (screenshot de la Răzvan în `debugging/`): un culoar vertical verde tăia deșertul în două, cu pietre crescute pe el.

**Cauză:** fiecare macro-celulă își plasează peticul de deșert **independent**. Când două petice vecine se opreau la exact 1 chunk unul de altul, rămânea un culoar. Pe el:
- `desertness` (ce desenează shaderul) ieșea **0.79** → podeaua arăta aproape-deșert, dar cu iarbă transpărând = fâșia verde;
- `is_desert_chunk` (logica) zicea **false** → creșteau pietre/copaci acolo.

Deci NU era o desincronizare shader↔CPU (amândouă erau de acord); era geometria peticelor.

**Fix:** `EDGE_SNAP = 2` în `biome_map.gd` + `_snap_axis()`, oglindit ca `snap_axis()` în `biome.gdshader` (uniformă nouă `edge_snap`, trimisă din `ground.gd`). Dacă marginea unui petic ajunge la ≤2 chunk-uri de granița macro-celulei, o **lipim** de graniță. Efect: distanța dintre două petice vecine e ori **0** (se unesc), ori **≥3 chunk-uri** (culoar lat, arată intenționat). Nu mai poate ieși 1 sau 2.

**Măsurat pe 360.000 de chunk-uri:**

| EDGE_SNAP | culoare de 1 chunk | de 2 chunk-uri | deșert din lume |
|---|---|---|---|
| 0 (cum era) | 294 | 201 | 19.5% |
| 1 | 0 | 142 | 20.3% |
| **2 (ales)** | **0** | **0** | **21.6%** |

**Gotchas:**
- **Lipirea mărește deșerturile** — 19.5% → 21.6% din lume (+2 puncte). Ăsta e prețul; dacă vreodată pare prea mult deșert, `EDGE_SNAP = 1` recuperează jumătate dar lasă culoare de 2 chunk-uri.
- **Matematica trebuie schimbată în AMBELE locuri simultan.** `_snap_axis` apare acum în toate cele 4 funcții din `biome_map.gd` (`is_desert_chunk`, `desertness_at_chunk`, `desert_inset_chunk`, `desert_rect_of_macro`) și în shader. Verificat că sunt de acord: **0 nepotriviri** logic↔vizual pe 57.600 de chunk-uri.
- Confirmat vizual pe chunk-ul (−281, 121), exact unde era culoarul: acum `desertness = 1.000`, `is_desert_chunk = true`, deșert compact fără pietre.

---

## Session log — 2026-07-19 (statui 3% + buton mare de interacțiune, pentru telefon)

**Done:**
- **`statue_chance` 10% → 3%** în `statues.gd`. Măsurat: **2.95%** pe 19.600 de chunk-uri.
- **Butonul „Summon" mutat din lume pe ecran.** Înainte fiecare statuie își desena un butonaș deasupra capului: mic, se mișca odată cu camera, greu de nimerit cu degetul pe telefon. Acum e **UN SINGUR buton mare** (240×150), fix în **stânga ecranului**, la mijlocul înălțimii + 64px mai jos (unde ajunge degetul mare).
- **`interact_ui.gd` (nou)**, `CanvasLayer` pe layer 5 (peste lume și vignette, sub level up/game over). În fiecare cadru caută statuia **cea mai apropiată** care e în raza ei și n-a fost încă invocată; butonul apare doar atunci. Stilizat cyberpunk cyan, ca meniul, și scoate același sunet de click.
- **`statue.gd` curățat:** nu-și mai face buton propriu. Se anunță în grupul `"statue"` și expune `poate_invoca()` + `invoca()`. `_process`-ul ei a dispărut de tot (verificarea distanței se face acum o singură dată, în UI, nu o dată per statuie).

**Verificat prin rulare:**
- Butonul e **ascuns** când nu e nicio statuie în rază, **apare** când te apropii și țintește exact statuia corectă.
- Poziția pe ecran: (44, 313), mărime 240×150 — stânga, aproape de mijloc.
- După apăsare: `poate_invoca()` devine false, butonul dispare, iar **bossul apare** (0 → 1 Garda în lume). Confirmat și cu poze înainte/după.

**Gotchas:**
- Un singur buton pentru toate statuile e important și pentru performanță: înainte **fiecare** statuie încărcată își făcea propriul `_process` cu verificare de distanță.
- Poziția pe verticală e `deplasare_jos` în px sub mijlocul ecranului. Prima variantă folosea o fracție înmulțită cu o înălțime de ecran hardcodată (640) — greșit pe alte rezoluții, schimbat în pixeli.

---

## Session log — 2026-07-19 (hartă random la fiecare rundă + statui generate pe chunk-uri)

**Done:**
- **Start aleator.** `spawner.gd::_muta_player_aleator()` aruncă player-ul într-un punct random (±100.000 px pe fiecare axă) la începutul fiecărei runde. Punctul e salvat în `GameSettings.run_spawn`. Evită deșertul: încearcă până la 40 de puncte și îl ia pe primul cu `BiomeMap.desertness_at_chunk() <= 0`, ca să nu te trezești într-o zonă goală.
- **`statues.gd` (nou)** — statui generate procedural pe chunk-uri, ca pietrele/copacii: **10% șansă per chunk, maxim una**, poziție deterministă din `hash(key) ^ SEED_SALT`. Statuia fixă din `main.tscn` a fost ștearsă și înlocuită cu nodul `Statues`.
- **Statuile se feresc de copaci:** până la 12 poziții încercate în chunk, verificate față de copacii din chunk-ul propriu + cele 8 vecine (prin `props._chunk_trees_raw()`, funcție pură deja existentă). Dacă niciuna nu e bună, chunk-ul rămâne fără statuie.
- `enemy_spawn_offset` (−66.415, reglat de Răzvan în main.tscn) mutat ca default în `statue.gd`, altfel se pierdea odată cu nodul din scenă.

**Verificat prin rulare:**
- 964 statui pe 10.000 de chunk-uri = **9.64%** (10% minus ~0.4% chunk-uri prea aglomerate de copaci).
- **0** statui mai aproape de un copac decât pragul; cea mai apropiată la 191 px (prag 190).
- 615/615 chunk-uri dau același răspuns la a doua cerere (determinism).
- 0 statui ieșite din chunk-ul lor (deci exact una per chunk).
- 3 rulări consecutive → 3 puncte de start complet diferite, cu 1 / 6 / 4 statui în jur.

**Gotchas:**
- **De ce start aleator și NU o sămânță de lume?** Matematica de biomuri din `biome_map.gd` (`_hash`) trebuie să rămână **identică bit cu bit** cu `hashu()` din `biome.gdshader` — altfel deșertul desenat nu mai coincide cu locul unde blocăm copacii. O sămânță ar fi trebuit băgată în ambele, în lockstep. Mutarea punctului de start dă exact același rezultat (lume nouă la fiecare rundă) cu zero risc de desincronizare CPU↔shader.
- **`spawn_range` nu poate crește oricât:** coordonatele 2D din Godot sunt float32, iar la valori foarte mari apar tremurături de precizie. 100.000 px e sigur (~0.008 px precizie) și oricum acoperă zeci de macro-celule de biom, adică variație mai mult decât suficientă.
- **`randomize()` explicit** în `_muta_player_aleator()`, ca să nu pornim de la aceeași secvență la fiecare rulare.
- **Acum pot exista mai multe statui în jurul tău** → poți invoca mai mulți boși. E consecința firească a cerinței; dacă deranjează, se limitează din `statue.gd`.

---

## Session log — 2026-07-19 (Y-sort statuie, PARTEA 2 — regula reală: arta trebuie să coboare sub linia de sortare)

**Context:** reparația de mai jos (baza artei pusă pe originea nodului) **nu era ce voia**. Răzvan a cerut „exact efectul de la copaci". Diagnosticat prin comparație directă: copac și statuie unul lângă altul, cu player-ul REAL la același baleiaj de Y (+60 … −90), două poze.

**Regula pe care am ratat-o prima dată:**
- Sprite-ul player-ului (`player.tscn` → `AnimatedSprite2D`, fără `offset`) e **CENTRAT** pe punctul lui de sortare → se întinde **~64px SUB** el.
- Deci un obiect a cărui artă se termină fix pe linia lui de sortare **nu poate acoperi niciodată** player-ul complet: în clipa în care trece în spate, îi rămân picioarele afară, sub obiect. Se vedea clar la coloana −30: statuia tăia player-ul în două.
- **Copacii n-au problema asta** fiindcă `sort_anchor = 0.35` le coboară arta **73.8px sub** linia de sortare — mai mult decât jumătatea player-ului. De-aia „efectul de la copaci" arată bine.
- Măsurat: copac **+73.8px** sub origine (32% din înălțime), statuie era **+0.0px** (0%). Acum statuia e la **+74.0px** (38% din înălțimea ei, care e mai mică).

**Done:**
- `statue.gd`: constanta **`ACOPERIRE_JOS = 74.0`** + `_aseaza_pe_origine()` calculează `offset.y` ca baza artei să cadă cu atât sub originea nodului (per variantă, fiindcă V2 se termină la 113 iar V1/V3 la 112).
- Mutate cu aceeași valoare, ca **nimic să nu se miște vizual**: `CollisionShape2D.position.y` −73.6 → **+0.4**, `Statue.position.y` (main.tscn) −220 → **−294**, `enemy_spawn_offset.y` −140.415 → **−66.415**.
- Verificat în joc că cele trei repere au rămas identice: baza artei **−220**, centrul hitbox-ului **−293.6**, punctul de apariție al bossului **−360.415**.

**Gotchas:**
- **Regula generală pentru orice obiect nou care trebuie să acopere player-ul:** arta lui trebuie să coboare sub linia de sortare cu **mai mult decât jumătatea sprite-ului player-ului (~64px)**. Nu e o chestie de „unde e baza obiectului".
- Nu confunda cu problema din partea 1 (banda în care intri prin obiect): aia cere ca linia de sortare să NU fie sub baza artei. Cele două împreună înseamnă: linia de sortare undeva **în interiorul** artei, cam la 1/3 de jos.
- **Hitbox-ul (`size`) rămâne al lui** — 130×40, neatins. I s-a mutat doar `position`, cu exact aceeași valoare cu care s-a mutat arta.

---

## Session log — 2026-07-19 (Y-sort statuie: nu mai intri prin ea pe la sud — INCOMPLET, vezi partea 2)

**Problema:** originea nodului Statue (= linia de Y-sort) era **sub** baza artei, la −26.4 px. Rezultat: o bandă de 26 px în care erai deja vizual sub statuie, dar tot desenat **în spatele** ei → părea că intri prin ea. Verificat înainte de reparație: 5 statui cu câte un marker la Y diferit — la −40 și −20 markerul era ascuns în spatele piedestalului.

**Done:**
- **Baza artei pusă exact pe originea nodului.** În `statue.tscn`: `Sprite2D.offset.y` −60 → **−49** și `CollisionShape2D.position.y` −100 → **−73.6**. Ambele mutate cu **aceeași** valoare (26.4 px), deci hitbox-ul lui Răzvan rămâne lipit de statuie exact cum l-a reglat — doar numărul din editor s-a schimbat. Efect secundar acceptat: statuia stă cu 26.4 px mai la sud în lume.
- **`_aseaza_pe_origine()` în `statue.gd`** — recalculează `offset.y` din `get_used_rect()` pentru varianta aleasă la rulare. Necesar fiindcă **cele 3 variante nu se termină la același pixel** (V2 la 113, V1/V3 la 112): cu un `offset` fix din scenă, două din trei rămâneau descentrate cu 2.4 px. Acum e corect prin construcție, la orice artă viitoare.

**Gotchas:**
- **Godot nu are „offset de sortare" per nod** — sortează după Y-ul global al nodului. Singura soluție e ca originea nodului să fie chiar pe linia de contact cu solul, iar arta să fie împinsă în sus din `offset` (exact trucul folosit deja la copaci în `props.gd`, cu `sort_anchor`).
- **Dacă muți `offset`, mută și `CollisionShape2D.position` cu aceeași valoare**, altfel hitbox-ul se dezlipește de statuie. Notă pusă și în capul lui `statue.gd`.
- **NU atinge hitbox-ul lui** (`size`) — și-l reglează singur (acum 130×40).

---

## Session log — 2026-07-19 (statuile micșorate de 1.8×)

**Done:**
- `statue.tscn` → `Sprite2D.scale` **3.0 → 1.6666667** (3 ÷ 1.8). Statuia pe ecran: 144×237 px → **80×132 px**.
- Cele 3 variante împart aceeași scenă, deci aveau deja același scale și același hitbox — n-a fost nimic de uniformizat, doar de confirmat (verificat prin rulare: toate 3 raportează scale 1.667 și hitbox 130×60).

**Gotchas:**
- **HITBOX-UL NU SE ATINGE.** Răzvan a cerut explicit să și-l regleze singur (`statue.tscn` → `CollisionShape2D`). A rămas 130×60, adică acum e mai lat decât statuia (80 px). Nu-l „repara" din reflex.
- Micșorarea coboară baza statuii față de originea nodului (de la 39 px deasupra ei la ~22 px), fiindcă `offset` se scalează odată cu sprite-ul. Lăsat intenționat nemodificat; dacă vrea statuia plantată exact ca înainte, `offset.y` trebuie −70.4 în loc de −60.
- Butonul „Summon" se ajustează singur — `_statue_top_y()` citește `sprite.scale.y`, deci n-a trebuit atins.

---

## Session log — 2026-07-19 (frunzele: zona luată din desenul lui Răzvan + puse PESTE copac)

**Done:**
- **Frunzele trec deasupra copacului.** Erau pe `z_index = -1` (moștenit de la urmele de foc/gheață) și unele intrau în spatele coroanei. Acum `z_index = 1`.
- **Zona nu mai vine din hitbox, ci din desenul lui.** Răzvan a pus `harta/Tree Leaf Area.png` — un screenshot cu **dreptunghiuri roșii desenate de mână peste doi copaci diferiți**. Le-am măsurat din imagine și am scos proporțiile:
  - lățime: **0.99** și **1.10** din lățimea copacului → `LEAF_ZONE_W = 1.0`
  - marginea de sus: **0.34** și **0.29** din înălțime → `LEAF_ZONE_TOP = 0.31`
  - marginea de jos: **1.12** și **1.11** → `LEAF_ZONE_BOTTOM = 1.11` (puțin SUB rădăcină)
  - Deci zona acoperă trunchiul + coroana de jos, nu iarba de lângă copac — interpretarea mea anterioară („la sud de copac") era greșită.
- `props.gd::_leaf_zone()` calculează dreptunghiul din **conturul vizibil** al texturii (`get_used_rect`), nu din canvas, fiindcă texturile de copaci au margini transparente iar desenul lui era raportat la copacul care se vede. Rezultatul e pus în meta `leaf_zone` (a înlocuit `hitbox_rect`).
- Reglaje ajustate pentru zona nouă, mult mai înaltă: `NR_FRUNZE` 6→8, viteze 22–45, iar `PRAG_STINGERE` 0.55→**0.8** (altfel frunzele se stingeau pe la mijlocul cutiei, nu jos lângă sol cum ceruse).

**Gotchas:**
- **Cum am măsurat desenul:** pixeli roșii (`R>150, G<90, B<90`) → **componente conectate** (flood fill), nu un simplu split pe X: logo-ul roșu de pe tricoul player-ului din screenshot contamina gruparea. Cele două dreptunghiuri ies ca cele mai mari 2 componente (2390 și 2180 px).
- **Conturul copacului din screenshot** l-am separat de iarbă cu regula **`R - B > 10`**: iarba are R≈B (58,84,57), coroana e galben-verzuie (60,93,43 → diferență 17) iar trunchiul maro (109,62,40 → 69). Pragurile pe „verde" nu merg, iarba e tot verde.
- **`get_used_rect()` e scump** (decomprimă textura) → cache pe textură în `_used_rect_cache`, altfel s-ar chema la fiecare copac generat, la fiecare chunk.
- Verificat vizual: am desenat zona calculată peste 3 copaci de forme diferite și se suprapune peste dreptunghiurile lui.

---

## Session log — 2026-07-18 (frunzele MUTATE: din overlay pe ecran → sub copaci)

**Done:**
- **Răzvan s-a răzgândit** față de sesiunea de mai jos: nu mai vrea overlay pe tot ecranul. Acum frunzele cad **doar sub copaci**, sunt **de 2× mai mici**, **doar spre SUD** și **se sting până la transparent** aproape de sol. Overlay-ul din `atmosphere.gd` a fost scos complet.
- **`leaffall.gd` (nou)** — se agață ca fiu al unui copac. Zona de cădere se calculează din **hitbox-ul copacului** (meta nouă `hitbox_rect` pusă în `props.gd::_make_tree`): lățimea hitbox-ului × `LATIME_FACTOR`, pornind puțin deasupra marginii lui de SUD. Fiecare frunză are viteză, legănat, rotire și pauză proprii; când ajunge jos repornește în alt loc, după o pauză.
- **Șansa de 10%** (`leaf_chance` în `props.gd`) se aruncă **în `_chunk_trees_raw()`, din același `rng` determinist** ca pozițiile copacilor → același copac are (sau n-are) frunze de fiecare dată când reintri în zonă. Verificat: 2034 din 2034 de chunk-uri identice la a doua cerere; 486 din 4613 copaci = **10.5%**.

**Gotchas:**
- **Zarul de frunze trebuie aruncat ÎNAINTE de filtrul de deșert** (`continue`), altfel numărul de apeluri `rng` diferă între copacii din iarbă și cei blocați în deșert, iar pozițiile din chunk-urile vecine nu mai coincid. Comentariul din capul funcției despre ordinea apelurilor rng e serios.
- **`setup(hitbox)` se cheamă ÎNAINTE de `add_child()`** — `_ready()` are deja nevoie de zonă ca să împrăștie frunzele; invers, ar porni toate din (0,0).
- **Prima încercare cădeau prea departe** (`CADERE_FACTOR = 2.0` → 184px sub copac): arăta ca o pată galbenă separată pe iarbă, nu ca frunze care cad din copac. Acum `START_SUS = 0.25` + `CADERE_FACTOR = 0.75` → ~69px, strâns la baza copacului.
- **`z_index = -1`** (ca urmele de foc/gheață) ca frunzele să nu acopere player-ul.
- **Nu itera cu `for f in _frunze` dacă înlocuiești elemente** — `_frunze.find(f)` pe dicționare nu e de încredere. Mers pe index.
- **Frunzele în pauză trebuie așezate imediat** (`_aseaza()` în `_frunza_noua`), altfel rămân la (0,0) cu alpha 1 până le vine rândul. Sunt invizibile, deci nu se vedea în joc, dar starea era incoerentă și pica la verificare.

---

## Session log — 2026-07-18 (overlay de frunze peste tot ecranul — ÎNLOCUIT, vezi mai sus)

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
