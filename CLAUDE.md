# Context for AI assistants

**Read `README.md` first** — it has the full project overview, architecture, current state, and (most importantly) **how to work with the project owner**, who is a complete beginner learning Godot.

Quick rules:
- **Reply in Romanian.** The owner is a beginner; teach in small, testable steps and be concrete about the Godot UI.
- **Godot 4.7 + GDScript.** Indentation is **TABS** — never mix tabs/spaces (Godot errors out). When code is involved, prefer writing `.gd` files directly to avoid copy-paste/tab problems.
- **Node lookups use groups:** `"player"` and `"enemy"` (via `get_tree().get_first_node_in_group(...)` / `get_nodes_in_group(...)`); cast results with `as Node2D` before using `global_position`.
- This is a **survivors-like / bullet-heaven** game (Vampire Survivors style), cyberpunk theme, for Android. See the roadmap in `README.md`.
- **Repo activ:** `C:\Users\stefan-razvan.dogaru\joc-bzn` (clonă pe `main`, remote `JocBZN/joc-bzn`) — verificat pe 2026-08-17, e SINGURA clonă de pe disc. Notele vechi care zic „Desktop\joc-bzn" sau „Downloads\joc-bzn-main" sunt depășite (folderele alea nu mai există). **Godot: `Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe`**, nu e în PATH — se cheamă cu calea întreagă.
- **Există un CODEX al upgrade-urilor**, artifact pe claude.ai: `https://claude.ai/code/artifact/490e047c-2f80-45c5-b6a6-9af326065a4e`. Când schimbi ceva în `levelup.gd` (item nou, raritate, efect, iconiță) sau în `game_settings.gd` (META), **actualizează-l și pe el** — altfel rămâne în urmă în tăcere. **De pe 2026-07-17 e generat data-driven** din `codex.html` (în repo): editezi array-ul `ITEMS` / `SYN` de sus (efectele reale din cod), iconițele+chenarele se re-encodează base64 și se injectează în placeholder-ul `/*__ASSETS__*/` cu scriptul PowerShell (vezi session log 2026-07-17 „Codex regenerat”), apoi republici pe același URL cu `url=`. Mult mai simplu decât chirurgia pe base64. **De pe 2026-07-28 codexul are și o secțiune „Statusuri de start"** (prima, sub titlu): tabelele `ARME` + `BASE`. Ea se strică ÎN TĂCERE dacă umbli la valorile implicite din `player.gd` — `speed`, `max_hp`, `contact_damage`, `xp_to_next`, tabelul `ARME`, `sword_base_damage`, `scythe_base_damage`. Cifrele de acolo NU se citesc din cod: se scot **rulând** o scenă care instanțiază player-ul cu fiecare armă și tipărește `stat_lines()`, cu `GameSettings.upgrades` golit doar în RAM (altfel prinzi și magazinul permanent din salvarea lui Răzvan). **⚠️ Randează-l ÎNTÂI în Chrome headless** (`--headless=new --enable-logging=stderr --log-level=0 --screenshot=...`): tot conținutul e generat din JS, deci o singură ghilimea greșită într-un string face pagina complet albă, fără niciun semn. S-a întâmplat (vezi log-ul din 2026-07-26 „codexul arată textul EXACT din joc"). Și încă ceva: câmpul `game:` (textul exact de pe cardul din joc) e **generat din `levelup.gd`**, nu scris de mână — dacă schimbi o descriere, o schimbi în `levelup.gd` (`desc`) și regenerezi, nu invers.
- ⚠️ **ARTIFACTUL CODEXULUI NU POATE FI REPUBLICAT de pe contul de lucru** (`razvanstefan.dogaru@gmail.com`, sesiunile Claude Code din `C:\Users\stefan-razvan.dogaru`). Verificat pe 2026-08-17: `Artifact action:list scope:all` îl întoarce ca **(shared)**, adică e publicat de pe ALT cont și doar împărtășit încoace — iar artifact-urile shared se pot citi, nu rescrie (`WebFetch` pe el dă „served to you as a public (non-member) reader"). Deci: **`codex.html` din repo rămâne sursa de adevăr și se actualizează normal**, dar pagina de pe claude.ai o reîmprospătează Răzvan de pe contul lui. Nu publica o versiune nouă pe alt URL — ar despărți codexul în două.
- **Jocul e în 9 limbi (din 2026-07-27).** Textele afișate se scriu **în ENGLEZĂ direct în cod** — Godot le traduce singur pe Label/Button, pe baza tabelului din `i18n.gd`. Când adaugi un text nou, adaugi și rândul în `TRAD`. `tr()` se folosește **doar** la textele cu `%d`/`%s` (pe o etichetă simplă ar STRICA schimbarea limbii). Verifică cu `godot --headless --path . res://tool_check_i18n.tscn` înainte de commit.
- **Testele care lasă player-ul să moară scriu în leaderboard-ul REAL** (`show_gameover` → `add_score` → `user://scores.save`). M-a prins de trei ori pe 2026-07-27. Ori ții inamicii departe, ori cureți scorul fals după verificare.
- **⚠️ Și un test care schimbă ceva în `GameSettings` DOAR ÎN RAM poate ajunge în salvarea reală** (prins pe 2026-08-04 cu `op_start`): jocul cheamă `_save()` de la sine, iar `_save()` scrie TOATE valorile din memorie. Deci: ori nu atingi `GameSettings` înainte să pornești `main.tscn`, ori pui valoarea înapoi ȘI salvezi. Verifică la final ce-a rămas în fișier.
- **Uneltele care au nevoie de autoload-uri se rulează ca SCENĂ, nu cu `--script`** — altfel dau „Identifier not found: GameSettings".
- **Generator nou în `World` (main.tscn) → trece-l în `WORLD_NODES` din `nether.gd`, `limbo.gd`, `ender.gd` ȘI `prison.gd`** (a patra listă din 2026-08-17). Sunt patru liste separate; dacă lipsește dintr-una, generatorul rămâne aprins acolo și-i vezi obiectele într-o dimensiune în care n-au ce căuta. S-a întâmplat de trei ori (EGT-uri, portaluri). **Singura excepție (din 2026-08-14): `Dubiosi`** — omul în palton apare NUMAI în Nether, deci lipsește dinadins din lista lui `nether.gd`, iar regula lui e scrisă invers, la el în generator (`dubiosi.gd` se uită la `nether.active` și se golește singur când nu ești acolo). În `limbo.gd` și `ender.gd` e trecut normal.
- **NU da `git push` decât dacă Răzvan îți cere explicit** (regulă din 2026-07-16, o înlocuiește pe cea de mai jos din log-ul de sesiune, care zicea să dai push automat). Restul finisajului rămâne automat: după ce termini o serie de schimbări, actualizezi CLAUDE.md + README și faci commit local (mesaj în română) — dar `main`-ul de pe GitHub îl atinge doar el, când zice.

---

## Session log — 2026-08-17 (PUȘCĂRIA — a patra dimensiune + THE WARDEN, boss cu 3 faze)

**Cerut de Răzvan:** „vreau să adaug o dimensiune nouă finală ca o pușcărie și aș vrea să nu fie accesibilă decât după ce joci toate celelalte dimensiuni. Prison bg-ul pentru podea, prison statue pentru a spawna boss-ul, final_boss_directions e static sunt cele 4 poziții, final_boss_walking_animations sunt animațiile de mers — trebuie să le extragi singur din poză, și am 3 animații pentru atacurile boss-ului. Boss-ul va avea 3 faze: primul doar cu un atac, al 2lea cu 2 atacuri și al 3lea cu toate cele 3 și să devină mai rapid. Folosește enemy-ii care există deja, doar fă-i mai OP deocamdată."

**Fișiere noi:** `prison.gd`, `prison_statue.gd` + `.tscn`, `final_boss.gd` + `.tscn`, `prison_inel.gd`, `prison_bolovan.gd`, `prison_laser.gd`, `harta/prison/` (49 PNG-uri tăiate). **Atinse:** `portals.gd`, `portal_ender.gd`, `ender.gd`, `nether.gd`, `limbo.gd`, `ground.gd`, `atmosphere.gd`, `spawner.gd`, `hud.gd`, `player.gd`, `i18n.gd`, `tool_check_i18n.gd`, `main.tscn`.

### Cum se ajunge acolo — regula „doar după celelalte dimensiuni"

**Nu e o verificare la ușă, e chiar lanțul lumii.** `portals.gd` avea două vârste; acum are **trei**, pe ACELEAȘI locuri din hartă (poziția e deterministă și nu se uită la vârstă):

> portal Nether → *(cade Saratalin)* → fântână Ender → *(cade Celesto)* → **poartă de pușcărie**

Deci până nu-i bați pe amândoi, poarta pur și simplu nu există. `ender.gd::_inchide_fantana` nu mai cheamă `portals.opreste()`, ci `treci_pe_prison()` — închiderea definitivă s-a mutat cu o dimensiune mai încolo, în `prison.gd::_inchide_poarta`.

- **N-am făcut artă nouă de poartă**, fiindcă n-a venit niciuna: e tot `portal_ender.tscn`, cu un steag `prison` pus ÎNAINTE de `add_child` (își citește pielea în `_ready`). Se deosebește prin **culoare** (`prison_tint`, verde-piatră) și prin eticheta de deasupra.
- ⚠️ **`eticheta()` întoarce text SIMPLU, fără `%s` și fără `tr()`** — `interact_ui.gd` îl pune ca atare pe Label, iar Godot îl traduce singur. Dacă i-aș fi lipit tasta („Press E to…"), cheia căutată ar fi fost textul deja compus și n-ar mai fi existat în tabel: rămânea englezesc în toate cele 9 limbi.

### Arta — partea cea mai grea a sesiunii

Cinci poze, din care **doar una era gata de folosit**. Ce a ieșit, în ordinea în care contează:

**1. Podeaua.** Măsurat că `prison_bg.png` e **tileabilă** (diferența margine-stânga/margine-dreapta 15, față de 60 între două coloane oarecare). Micșorată de la 1254 la **209** — factor ÎNTREG (1254 = 6 × 209), altfel cusătura se strică.

**2. Statuia.** Fundal gri-verzui plat (58,65,68), dar statuia e **tot gri**, deci o cheie pe culoare i-ar fi mâncat umbrele. Scoasă cu **flood fill de la margini**: se șterge doar fundalul LEGAT de bordură, interiorul rămâne orice culoare ar avea.

**3. Boss-ul — trei încercări până a ieșit bine.** Foile au fundal magenta, iar cea de mers e **JPEG**, cu text negru peste („FRONT WALK CYCLE", „FRAME 1").
   - **v1** (prag pe „magenta") → text rămas în cadre + franjuri roz pe lanțuri.
   - **v2** (cheie pe alfa + „unmixing", `fg = (P − (1−a)·BG)/a`) → **mai rău**: JPEG-ul nu amestecă liniar, ci lasă un halou de ringing, iar împărțirea la alfa mic l-a amplificat și a scos magenta APRINS. De reținut: **unmixing-ul e corect matematic doar pe surse fără compresie.**
   - **v3, cea bună:** cheie **BINARĂ** pe „magenta dominant" (`R > G+40 și B > G+40`) + **eroziune de 1px**, care mănâncă exact inelul contaminat. Plus o de-franjurare blândă (dacă și R, și B sunt peste G, le trag înapoi) — ⚠️ scrisă să NU atingă ochii roșii (la ei B rămâne mic) și nici muschiul verde (la el G e cel mare).
   - **Textul negru** nu se scoate cu cheia (nu e magenta): fiecare cadru se taie la **bbox-ul pixelilor COLORAȚI** (`max(R,G,B) > 70`), în care textul nu intră.

**4. ⚠️ Scara a trebuit NORMALIZATĂ între foi.** Pozițiile statice sunt desenate la ~540px înălțime, mersul la ~194 — dacă le lăsam așa, **boss-ul își schimba mărimea când se întorcea**. Fiecare foaie primește propriul factor (×0,256 și ×0,711), calculat ca personajul să iasă **138px** pe o pânză de 160. Și toate cadrele se așază cu **tălpile pe aceeași linie** și centrul pe aceeași coloană (lecția de la pompier).

**5. ⚠️ Boss-ul ARE DOAR 4 DIRECȚII**, nu 8 — atâtea sunt desenate. `_uita_spre` rotunjește la cel mai apropiat SFERT de cerc, iar pe diagonale câștigă orizontala: profilul spune limpede încotro merge, fața/spatele nu. Mersul lateral are 3 cadre, cel din față/spate are 4, deci `_build_frames` nu presupune un număr fix — încarcă până nu mai găsește fișier.

### Boss-ul: 3 faze, 3 atacuri

| fază | prag | ce face |
|---|---|---|
| 1 | 100% → 70% | doar **INELUL** de piatră — undă care pleacă din el, „dă-te de pe mine" |
| 2 | sub 70% | + **BOLOVANUL** care cade peste locul în care ești |
| 3 | sub 40% | + **RAZA**, ȘI devine mai rapid: viteză **×1,45**, atacuri de **1,5× mai dese**, 3 bolovani odată |

Pragurile sunt PROCENTE din viață (ca la Celesto/Saratalin), deci înseamnă același lucru la orice rundă. Viață **fixă 260 000**, nescalată — din același motiv.

- **Inelul:** damage-ul se dă **când frontul ajunge la tine**, o singură dată (`_lovit`). Fugi în afara razei maxime → nu te atinge deloc. Ăsta e tot rostul lui.
- **Bolovanul:** ținta se **îngheață la lansare** (unul care te urmărește până aterizează n-ar mai putea fi evitat), damage-ul e **la impact**, nu în cădere, iar pe pământ e desenat un **cerc de avertizare** care se strânge. Fără el atacul ar fi necinstit: vezi ceva căzând, dar nu ai de unde ști unde.
- **Raza:** direcția se îngheață la începutul încărcării, deci ai `timp_incarcare` să ieși de pe linie. ⚠️ Cadrele sunt desenate cu raza pornind din STÂNGA pânzei → `offset.x = jumătate din pânză`, ca originea nodului să cadă pe capătul din care pleacă; altfel s-ar roti în jurul mijlocului ei.
- **Contur roșu pe boss** (`contur_1px.gdshader`, ca la Celesto): e piatră gri-verzuie pe pavaj gri-verzui, deci fără el se pierde în fundal. Prins pe prima captură, nu în cod.

### Inamicii: aceiași, dar mai OP

Cerut explicit așa. `PRISON_FELURI` din `spawner.gd` trage la sorți din **toate cele 6 feluri existente**, iar `_ingroasa_pentru_puscarie()` le pune **×3 viață, ×1,25 viteză, ×1,6 damage** — cifrele stau în `prison.gd` (`ENEMY_POWER` / `ENEMY_SPEED` / `ENEMY_DAMAGE`), acolo unde se reglează dimensiunea. ⚠️ Se aplică ÎNAINTE de `add_child`, altfel viața e deja coaptă.

### Două bug-uri prinse RULÂND, nu citind

1. **`atmosphere.gd` ieșea din funcție dacă dimensiunea n-are shader propriu.** Pușcăria n-are (nu s-a cerut unul) → nici tenta nu se aplica, adică temnița arăta exact ca lumea normală. „Nu are shader" ≠ „shaderul lipsește de pe disc".
2. **Tween pe `shader_parameter/amount` pe un material FĂRĂ shader** = „The tweened property does not exist", și rupea tot lanțul de stingere la ieșire. `set_shader_parameter` pe un material fără shader **nu înregistrează nimic**, deci garda trebuie pusă pe `_dim_mat.shader != null`, nu pe parametru.

Plus: `load()` pe un cadru inexistent scrie o EROARE roșie înainte să întoarcă null — cu 4 direcții însemna 4 erori la fiecare invocare. Se verifică întâi cu `ResourceLoader.exists()`.

### Verificat RULÂND cap-coadă (scenă de test ștearsă după)

Lanțul: `ender=false/prison=false` → după Saratalin `ender=true` → după Celesto **`prison=true`** ✓ · intrare: copaci **49 → 0**, podea `grass → prison_bg.png`, `frozen=true`, `xp_bonus=4.0` ✓ · statuia la **933px** de poartă (inel cerut 750–1250) ✓ · **27 de inamici, toate cele 6 feluri**, `power_mult=3.0` ✓ · statuia scoate boss-ul, cadre **east=3 south=4 west=3 north=4** + pozele de stat pe loc ✓ · fazele **1 → 2 → 3**, viteza **62 → 90 (×1.45)** ✓ · toate trei atacurile chiar ies în lume ✓ · **poarta refuză să se deschidă cu boss-ul viu**, se deschide după ce cade ✓ · ieșire: copaci 49, podea iarbă, `frozen=false`, `xp_bonus=1.0`, `portals.oprit=true` ✓ · **zero erori în consolă** · boss **165px pe ecran față de 59px la un inamic** (×2,8).

`tool_check_i18n` → **„✔ TOTUL E TRADUS"**, 304 chei × 8 limbi (22 chei noi).

⚠️ **`scores.save` a fost REscris de joc** (nu de test): niciun scor fals adăugat, cel mai mic rămâne 39,5s, 330 monede, setările neatinse. Player-ul a fost făcut nemuritor înainte de orice, iar `GameSettings` n-a fost atins — dar jocul cheamă `_save()` de la sine, deci **data fișierului se schimbă oricum**. Verifică CONȚINUTUL, nu data.

### ⚠️ RUNDA A DOUA, în aceeași zi: „se buguiește, monstrul nu apare și mă bagă random în Limbo"

Răzvan a jucat-o și a raportat asta. **Nu-l băga nimeni din greșeală în Limbo — chiar murea**, în ~1 secundă de la aterizare, deci nu apuca nici să găsească statuia, nici să vadă boss-ul. Trei lucruri, toate găsite MĂSURÂND, nu citind:

**1. Pușcăria era imposibilă. Măsurat: 109–143 damage/secundă → un player cu 150 viață rezistă 1,4 secunde.**
- 🔑 **Ce-l omora era NUMĂRUL de inamici, nu cât lovește unul.** Ca să ajungi în pușcărie treci prin Nether ȘI Ender, deci ajungi târziu: la 8:00 `Difficulty.spawn_mult()` e **6,48** și viața inamicilor **×16,3**. Peste asta pusesem ×3 viață — adică nu-i mai puteai curăța, se adunau (27 pe hartă) iar damage-ul de contact se plătește **per inamic lipit de tine**, la fiecare 0,5 s.
- Și pusesem ×1.6 damage peste `damage_mult`-ul lor propriu (creatura Ender are 2.0) și peste `enemy_damage_mult()` (2,24 la minutul 8) — **trei multiplicatori care se înmulțesc**: 5 × 2,24 × 2,0 × 1,6 = 36 per creatură la fiecare jumătate de secundă.
- **Reglat:** `ENEMY_DAMAGE` 1.6 → **1.0**, `ENEMY_POWER` 3.0 → **1.25**, `ENEMY_SPEED` 1.25 → **1.10**, `BURST` 26 → **8**, plus **`SPAWN_MULT = 0.35`** (nou, citit de `spawner.gd::rata_curenta`). Statuia adusă de la 750–1250 la **380–620**, ca s-o vezi de la aterizare.
- 🔑 **Îngroșarea adevărată a pușcăriei nu e un multiplicator, ci că vin TOATE FELURILE DEODATĂ** — în lumea normală te bat mai ales polițiști, aici îți vin SWAT, pompieri și creaturi de Ender în același val.
- **Rezultat, remăsurat: 34 damage/secundă**, inamicii se țin la 5–11 în loc de 27.

**2. ⚠️ Prima măsurătoare a fost NEDREAPTĂ și era să mă ducă în direcția greșită.** Testam cu un player **fără niciun upgrade**, cu pistolul de start, aruncat în dificultatea de la minutul 8 — normal că se topea. Cine ajunge în pușcărie are un build. Cu unul realist (70 damage, cadență dublă, 3 proiectile, străpungere) cifra a scăzut de la 143 la 34. **Când măsori o dimensiune de final, dă-i player-ului build-ul cu care s-ar ajunge acolo.**

**3. ⚠️ Și a doua măsurătoare a ieșit falsă, în alt fel:** cu build bun player-ul urcă în nivel, iar **ecranul de Level Up pune tot arborele pe pauză** — inamicii îngheață, boss-ul stă pe loc, iar `upgrade_max_hp` te și vindecă, deci „damage-ul încasat" ieșea **negativ**. Se blochează cu `p.xp_to_next = 1_000_000_000`. (Capcana e scrisă de mult în CLAUDE.md; am reintrat în ea.)

**Două bug-uri adevărate, prinse tot rulând:**
- **BOLOVANUL NU FĂCEA DAMAGE NICIODATĂ.** Îmi copiam ținta în `_ready()`, dar cine îl naște face `add_child` și **abia apoi** îi pune poziția — deci `_ready` rula pe poziția veche. Atacul arăta perfect și lovea în alt punct. Acum ținta se citește la impact, din `global_position`. (Aceeași familie cu capcana din `celesto.gd::_coasa`: ce scrii DUPĂ `add_child` nu mai ajunge la `_ready`.)
- **`prison.gd::reia()` crăpa la întoarcerea din Limbo.** Statuia se șterge singură după ce scoate boss-ul, iar `_arata_obiect(n: Node2D, ...)` primea o referință MOARTĂ — Godot crapă la APEL („previously freed"), înainte ca `is_instance_valid` din corp să apuce să verifice. Parametrul e acum netipizat.

**Boss-ul mergea prea încet ca să conteze:** 62 px/s față de 215 ai player-ului, și — spre deosebire de Saratalin (cade peste tine) și Celesto (se teleportează) — **n-are cum să se apropie**. Urcat la **140** (faza 3: 203). Verificat: te ajunge din 595 px în 3 secunde.

---

### Rămas de făcut / de știut

- **Numele boss-ului („THE WARDEN") e ales de mine** — Răzvan nu i-a dat unul. Se schimbă în `final_boss.gd` (`@export var nume`) + rândurile din `i18n.gd`.
- **N-are shader de atmosferă propriu** (Nether are scântei, Ender are stele). Pușcăria are doar culoarea + vinieta. Se adaugă în `DIM_SHADERS` dacă se vrea.
- **N-are muzică proprie:** împrumută bucla Nether-ului, ca Ender-ul.
- **Boss-ul n-are animație de atac sau de moarte** (arta are doar mers), deci atacurile pleacă din clipa deciziei, iar moartea e un tween — exact ca la Celesto.
- **Statuia se pune de `prison.gd`, nu de un generator pe chunk-uri**, deci NU trebuie trecută în listele `WORLD_NODES` — capcana aia n-a fost atinsă aici.

---

## Session log — 2026-08-17 (2 iteme noi: Water and electrolytes · Big Black Cigar)

**Cerut de Răzvan:** „am pozele astea 2 în downloads, bagă-mi-le în joc la iteme. Electroliții se vor numi «Water and electrolytes» și va da health regen și speed, iar cigar va fi «Big Black Cigar» și va da damage mare dar va încetini ms-ul jucătorului."

**Atinse:** `Upgrades/upgrade_59.png` + `upgrade_60.png` (noi), `levelup.gd`, `i18n.gd`, `codex.html`, README. **Pool: 51 → 53 de iteme.**

### Arta — una era gata, cealaltă nu

- **`electrolytes.png` era deja bun:** 128×128, RGBA, fundal transparent. Copiat ca `upgrade_59.png`, fără nicio prelucrare.
- **`cigar.jpg` NU era folosibil:** 1200×896, JPG fără alfa, cu un **fundal de cărămidă** care trebuia scos.

**Cum s-a decupat, fiindcă „scoate fundalul închis" n-ar fi mers:** conturul țigării e negru PUR, adică **mai închis decât cărămida** — orice prag pe luminozitate ar fi mâncat exact conturul. Separatorul adevărat e **tenta**: cărămida e violetă (`B−G ≈ +12`: 27,21,33), pe când țigara, fumul și jarul sunt **neutre** (R≈G≈B) sau roșii. Deci regula e `(B − G) >= 5`, nu „e închis".

⚠️ **Dar nu s-a aplicat pe JPEG-ul brut.** Compresia lasă halou în jurul muchiilor, deci marginile ar fi ieșit cu franjuri. Poza e **pixel art mărit**: i-am detectat grila (energia de schimbare pe coloane/rânduri, testată pe perioade candidate → **perioadă 30px, offset 0 pe orizontală, 28 pe verticală**, scor de 2,4× peste următoarea variantă), apoi am reconstruit arta la rezoluția ei nativă, **40×28**, mediind centrul fiecărui bloc (9..21 din 30 — se sare peste muchii, unde stă zgomotul). Pe paleta curată de acolo, testul de tentă e exact.

Verificat ca **hartă ASCII** înainte de a scrie vreun PNG: silueta iese curat (fum în stânga sus, țigara pe diagonală, jarul jos-stânga) și **zero pixeli de cărămidă rămași** în fundal. Apoi decupat la bbox (25×22 blocuri) și mărit ×4 cu **NEAREST** → 100×88, centrat în 128×128. Scara întreagă e obligatorie: la o scară fracționară pixel art-ul iese cu rânduri de grosimi diferite.

### Statele — și de ce astea

| item | raritate | efect |
|---|---|---|
| **Water and electrolytes** | Uncommon | `hp_regen += 2` · `speed *= 1.10` |
| **Big Black Cigar** | Epic | `bullet_damage = round(bullet_damage * 1.40)` · `speed *= 0.75` |

- **Regenerarea e un întreg fix (+2), nu procent.** `player.hp_regen` e `int`, deci un procent s-ar pierde la rotunjire — aceeași capcană ca la 5G Tower (vezi log-ul din 2026-07-28). Wine dă +3 și e Common, dar te și vindecă pe loc; aici plusul e că vine la pachet cu viteza, de-aia Uncommon.
- **Viteza e procent pe valoarea CURENTĂ la amândouă**, deci se compune (ca Hellas / The Nightclub / Death Sentence). Măsurat: două luări de electroliți = **×1.21**, nu ×1.20.
- **Trabucul e cel mai mare plus de damage dintr-o singură luare** (+40% față de +35% la The Nightclub), și e singurul care plătește în **viteză de mișcare**, nu în cadență.
- ⚠️ **Încetinirea trabucului e o pierdere DUBLĂ**, și merită știut la balans: `speed_ratio()` măsoară viteza curentă față de cea de start, deci încetinirea taie și din **Diesel Power** și din **Megane's Katana**. Invers, electroliții îi umflă.
- ⚠️ **Fără plasă de siguranță pe viteză**, ca la Death Sentence: luat de multe ori te lasă aproape pe loc. Convenția casei, nu o scăpare.
- Trabucul scrie **direct în `bullet_damage`**, spre deosebire de Cigarette Pack, care adună în `cig_bonus` (procent citit la fiecare lovitură). Deci nu sunt același lucru la scară diferită.

### Verificat RULÂND jocul adevărat (scenă de test ștearsă după)

- `hp_regen` 0 → **2** → **4**; viteza 215 → 236.50 → **260.15** (×1.21, deci chiar se compune); iar regenerarea **chiar intră în viață**: hp 100 → **104** după `_regen()`, nu doar un număr în panou (bug-ul Cigarette Pack din 2026-08-04 a fost exact ăsta — statul mergea, panoul mințea).
- Trabucul: damage 15 → 21 → 29, raport **×1.400** exact; viteza **×0.750** la fiecare luare.
- **Poză din meniul REAL de level up:** ambele carduri cu chenarul de raritate corect și iconițele întregi, iar panoul de STATS arată compromisul cum trebuie — **DAMAGE verde, MOVE SPEED roșu, HP REGEN verde**.
- `tool_check_i18n` → **„✔ TOTUL E TRADUS"**, 283 chei × 8 limbi (4 chei noi: 2 nume + 2 descrieri).
- **`scores.save` neatins** (ultima modificare rămasă 2026-07-07): player-ul a fost făcut nemuritor ÎNAINTE de orice și `GameSettings` n-a fost atins deloc.

### De reținut

- 🧹 **Nota veche „`levelup.gd` are CRLF, deci Edit pe mai multe linii eșuează" e DEPĂȘITĂ.** Măsurat pe 2026-08-17: `levelup.gd` are 1046 terminații LF și **0 CRLF**, la fel `i18n.gd`. Se editează normal.
- **Iconițele de item sunt 128×128 și codul se bazează pe asta** (`chest_fx.gd` are chiar comentariul). Se afișează la 64×64 pe cardul de level up (celulă 88 − 12 margine ×2), ~92px la cufăr (cel mai mare loc din joc) și 48px în cazinou — deci 128 e destul peste tot, nu are rost mai mare. Pătrate obligatoriu (`STRETCH_KEEP_ASPECT_CENTERED` lasă benzi goale la dreptunghiuri) și **desenate gândind la 64**, fiindcă 128→64 e fix înjumătățire cu filtru NEAREST: detaliile de 1px dispar.
- **Numere libere de iconițe** (fișiere pe disc pe care nu le folosește niciun item): **1, 2, 12, 26, 27, 37, 46**. Următorul nefolosit: `upgrade_61.png`.
- ⚠️ **Chrome headless are nevoie de `--user-data-dir`** în mediul ăsta, altfel iese cu cod 0 și **nu scrie poza deloc** — arată exact ca o randare reușită dacă nu verifici că fișierul există. Codexul randat: **964.7 KB** (pagina albă ar fi ~154 KB), zero erori de consolă.
- **Codexul e actualizat în repo dar NU republicat** — vezi regula nouă de sus: artifactul e *shared*, nu al contului de lucru.

---

## Session log — 2026-08-15 (PRIMUL MINUT e al polițistului obișnuit — cotă garantată de 70%)

**Cerut de Răzvan:** „Vreau să vină în primul minut 70% din spawn să fie Faceless Police Officer. Și după primul minut cum e spawnul acum."

**Atinse:** `spawner.gd` (doar el).

**Cine e „Faceless Police Officer":** `ENEMY` / `enemy.tscn`, primul din `POLITISTI`, polițistul obișnuit. Numele vine din arta lui: GIF-urile `A_faceless_police_officer_in_walk_*.gif` stau direct în `homeless directii/`, iar cadrele tăiate din ele sunt în `homeless directii/frames/` → `enemy_frames.tres`. (Nu confunda cu `homeless directii/Police Skinny/`, care e alt inamic.)

### COTĂ, nu pondere — și de ce contează diferența

Reflexul ar fi să urci `pond_politisti[0]` până iese 70% pe hârtie. **Ar fi fost greșit.** De pe 2026-08-12 fiecare val înmulțește ponderile cu un număr aleator între `1/haos_amestec` și `haos_amestec` (adică ÷2,2 … ×2,2). Cu ponderi, „70%" ar fi însemnat oriunde între ~45% și ~85%, altfel la fiecare rundă — exact lucrul pe care o cerință cu procent în ea îl exclude.

Deci se rescrie ponderea, nu se reglează. `_cota_primului_minut(p)` rezolvă ecuația roții:

```
w0 / (w0 + restul) = cotă   →   w0 = restul * cotă / (1 − cotă)
```

`restul` se calculează DUPĂ ce s-au aplicat porțile de ceas, deci formula se auto-corectează: la 0:30 pompierul e închis (pondere 0), la 3:00+ ar fi deschis — dar regula e stinsă până atunci oricum. Dacă haosul valului umflă Skinny-ul, `restul` crește și `w0` crește odată cu el, deci cota rămâne 70%.

- 🔑 **Ceilalți nu se ating între ei** — se rescrie DOAR indexul 0. Deci în cei 30% rămași proporțiile valului sunt fix cele trase la sorți: un val „de SWAT" rămâne un val de SWAT, doar că se joacă într-o treime din spawnuri. Verificat: într-un val cu SWAT umflat ×2,2, raportul Skinny/SWAT e 0,404 la t=0 și 0,398 la t=60 — același.
- **Numărul TOTAL de inamici nu se schimbă.** Aici se alege doar CINE iese; CÂȚI vine din `rata_curenta()`, care nu știe de feluri.
- Reglabil din inspector: `primul_minut` (60,0) și `cota_politist_intai` (0,70). `primul_minut = 0` stinge regula complet.
- ⚠️ Capetele sunt tratate explicit: `cota = 1.0` sau „n-a mai rămas nimeni în roată" ar fi împărțit la zero. Se pun ceilalți pe 0 și `p[0] = maxf(p[0], 1.0)`, ca totalul să nu iasă 0 și să nu cădem pe ramura de avarie.

### A doua excepție de la „fără ore fixe"

Regula din 2026-08-12 („fără ore fixe, sorți curați") are acum **două** excepții, amândouă cerute, amândouă la capetele rundei: pompierul la 3:00 (`minut_politisti`) și cota primului minut. Restul rămân cum i-a vrut. Le-am scris pe amândouă în blocul „VALURILE", ca următorul care citește să nu creadă că cineva a strecurat înapoi vechiul `skinny_after`.

⚠️ Tot `Difficulty.time`, deci tot ceasul CRESCĂTOR: „primul minut" e `time < 60`. Și tot el îngheață în Limbo/Nether/Ender — aici e exact ce trebuie: un minut de joc în lumea normală rămâne un minut de joc în lumea normală, chiar dacă între timp ai fost dincolo.

### Verificat rulând (20.000 de trageri pe fiecare moment)

| | Faceless | Skinny | SWAT | Pompier |
|---|---|---|---|---|
| t=0 | **69,84%** | 20,06% | 10,10% | 0% |
| t=30 | **69,70%** | 20,06% | 10,23% | 0% |
| t=59,9 | **70,37%** | 19,73% | 9,90% | 0% |
| t=60 | 49,15% | 34,16% | 16,69% | 0% |
| t=120 | 49,22% | 33,53% | 17,25% | 0% |
| t=180 | 45,27% | 31,59% | 15,28% | 7,86% |

Și dovada că sortul valului nu mai contează în primul minut: pe un val cu SWAT umflat ×2,2 iese tot **70,11%** la t=0 (față de 29,25% la t=60); pe un val cu Faceless umflat ×2,2, tot **69,72%** (față de 82,55% la t=60). Rândurile de la t≥60 sunt identice cu cele de dinainte de schimbare, adică „după primul minut cum e spawnul acum" se ține.

Capetele de interval, fără erori: `cotă 1.0` → 100/0/0/0; `cotă 0.0` → 0/66,28/33,73/0; `primul_minut = 0` → 48,60/33,85/17,54/0 (regula stinsă, exact spawnul normal).

---

## Session log — 2026-08-15 (POMPIERUL — cel mai tare inamic al lumii normale, dar abia de la 3:00)

**Cerut de Răzvan:** „ți-am adăugat un folder nou în homeless directii — Firefighter — vreau să fie cel mai op din inamicii din lumea normală, doar că el nu se spawnează de la început, doar după ce trec 3 minute din joc."

**Atinse:** `enemy_firefighter.tscn` (nou), `spawner.gd`, `homeless directii/Firefighter/frames/` (48 PNG-uri noi).

### Poarta de 3 minute

`minut_politisti` — un `@export var Array[float]` nou, paralel cu `pond_politisti`: de la a câta secundă SCURSĂ intră fiecare fel în roată. `[0, 0, 0, 180]` — primii trei de la început, pompierul la 3:00.

- ⚠️ **`Difficulty.time >= 180`, nu `time_left() <= 180`.** Ceasul de pe ecran SCADE de la 10:00. „După ce trec 3 minute" e cronometrul care URCĂ. (La SWAT, „mai are 6:00" însemna `time >= 240` — aceeași capcană, altă față.)
- ⚠️ **Ceasul se citește în `_politist()`, la fiecare inamic născut — NU în `_val_nou()`.** Ponderile se trag la sorți o dată la 10–22 s (vezi „VALURILE"), deci un val pornit la 2:59 ar fi ținut pompierul afară până la 3:21. Așa intră fix la secunda 180.
- Un fel blocat întoarce pondere **0**, deci iese complet din roată. Nu i se „mută" felia nimănui după vreun calcul: ceilalți împart un total mai mic, ponderile lor RELATIVE rămân exact cele de dinainte, iar numărul TOTAL de inamici nu se schimbă (asta o face `rata_curenta()`, care nu știe de feluri).
- E **singura excepție** de la „fără ore fixe", regula pusă pe 2026-08-12 când au dispărut `skinny_after`/`swat_after`. A cerut-o explicit, și are sens tocmai fiindcă e cel mai tare.

### Statele — 225 HP, 210 viteză, damage dublu

Judecata mea peste „cel mai op", cu cifrele alese să spună o poveste verificabilă:

| | viteză | HP | dmg | XP |
|---|---|---|---|---|
| polițist | 120 | 30 | 1.0 | 1.0 |
| Skinny | 160 | 45 | 1.3 | 1.0 |
| SWAT | 160 | 150 | 1.3 | 3.0 |
| creatura Ender (după Celesto) | 380 | 50 | 2.0 | 1.0 |
| **POMPIER** | **210** | **225** | **2.0** | **5.0** |
| Garda (boss) | 70 | 300 | — | — |

- **225 = 75% din Garda**, la fel de stabil ca cei 50% ai SWAT-ului: `garda.gd` și `enemy.gd` își înmulțesc amândoi viața cu ACELAȘI `Difficulty.enemy_hp_mult()`, deci raportul se ține în orice secundă. Verificat la t=240: **952 față de 1269** = 0,750.
- **210 = cel mai iute polițist**, peste creatura din Nether (190). **Nu** peste cea din Ender (380) — dinadins: 225 HP + damage dublu la 380 viteză n-ar fi „greu", ar fi „imposibil". Vrea și viteza aia? `speed` din `enemy_firefighter.tscn`.
- **`damage_mult = 2.0`** — cel mai mult din joc, la egalitate cu creatura Ender.
- **`xp_drop_mult = 5.0`** — același raționament ca la SWAT (3.0 pentru 5× viața polițistului): 7,5× viața trebuie să lase mai mult, altfel e timp pierdut curat. Rămâne sub raportul de viață, ca la el.
- **Pondere de bază 0,18**, cam jumătate din a SWAT-ului → **~8% din polițiști** după 3:00. Ținut mic: e cel mai gras lucru care nu e boss.
- ⚠️ **NU intră în îngroșarea de după Nether** (`escaped_power_mult = 2`) — condiția din `_spawn_enemy` e pe `ENEMY`/`ENEMY_SKINNY`, deci îl ocolește de la sine. Dublat ar fi ajuns la **450**, adică 150% din viața boss-ului. „Cel mai tare din lumea normală" e una, „mai tare decât boss-ul" e alta.

### Arta — 7 GIF-uri primite, 8 direcții livrate

GIF-uri de 6 cadre, tăiate cu `tool_taie_gifuri.ps1` + `--headless --import`. Două lucruri **nu erau gata de folosit**, amândouă găsite măsurând, nu privind:

1. **Lipsea `north-east`** (celelalte 7 erau toate acolo, md5-uri diferite). Făcut prin **oglindirea lui `north-west`** — ambele arată spatele cu butelia, deci întoarcerea dă exact poza care lipsea. Oglindirea păstrează centrul și tălpile (silueta e la 16..47 pe o pânză de 64, simetrică).
2. **`south` era desenat la altă scară ȘI pe altă pânză** (92×92, siluetă 47 px, față de 64×64 și 56–58 la restul). Două probleme într-una: pânza diferită ar fi mutat tălpile cu 6 px (12 pe ecran, adică o săltare la fiecare întoarcere), iar scara ar fi făcut pompierul să se micșoreze cu 17% exact când vine spre tine. **`Idle_rotations_8dir.gif` a fost arbitrul**: toate cele 8 poze de acolo au silueta de ~59 px, deci `south`-ul alergând era cel greșit, nu celelalte. Mărit ×1,213 (64→78 nearest) și decupat înapoi la 64×64. Rezultat: **30×58**, identic cu `east`/`west`.

**Toate 8 direcțiile au acum: pânză 64, centru_x 31,5, tălpi la y=61.** Asta e proba că nu sare și nu se leagănă când se întoarce — nu „arată bine în poză".

- **Mărimea:** siluetă 58 × `scale = 2.0` = **116 px pe ecran**, adică cel mai înalt polițist (Skinny și SWAT au amândoi 104). Cel mai tare trebuie și să se vadă că e cel mai tare.
- **`stop_dist = 47`** = jumătate din cea mai lată poză (32 × 2) + jumătatea player-ului (15). Plafonul dur rămâne 54.
- ⚠️ **`Idle_rotations_8dir.gif` a rămas în folder** (e arta lui). Dacă mai rulezi vreodată `tool_taie_gifuri.ps1` pe folderul ăsta, scoate 8 fișiere `run_8dir_*.png` — direcția se ia din coada numelui. Se șterg, nu strică nimic.

**Verificat rulând:** cele 48 de cadre randate în grilă (8×6, orientări corecte — spatele cu butelia la `north`, profil curat la `east`/`west`, diagonalele la fel), fundal transparent, fără cadre lipsă la instanțiere prin `enemy.gd`; cei patru polițiști aliniați pe același pământ, cu pompierul vizibil cel mai înalt; **4000 de trageri la zar** pe fiecare moment → **0,00% la t=0, 60 și 179; 8,3% la t=180**; și o rulare a jocului ADEVĂRAT cu ceasul împins la 200 — pompier viu în lume, alergând spre player cu animația direcției potrivite, fără nicio eroare în consolă.

**Rămas neatins dinadins:** hoarda monumentului (`monument.gd::FELURI`) n-a primit pompier, exact ca SWAT-ul — acolo toți primesc ×3 viteză și ×3 damage, iar un tanc de 225 HP în plus e o schimbare de echilibru pe care n-a cerut-o. Se adaugă cu **un rând** dacă vrea.

---

## Session log — 2026-08-15 (steagurile de la LANGUAGE, centrate cu adevărat)

**Cerut de Răzvan:** „centrează bine la limbi steagurile cu textu."

**Atinse:** `menu.gd` (funcție nouă `_steag_centrat`, folosită în panoul LANGUAGE și la butonul din colț).

- **Cauza:** steagul era pus ca `Button.icon` + `expand_icon`. Butonul își împarte lățimea între iconiță și text, iar **spațiul pentru text îl rezervă și când textul e gol** — steagul stătea la 18 px de marginea stângă și la 33,6 de cea dreaptă, adică împins cu ~8 px. Se vedea imediat, fiindcă numele limbii de dedesubt e centrat cinstit.
- **Leacul:** un `TextureRect` copil al butonului, ancorat `PRESET_FULL_RECT` cu o margine, `EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED` și `MOUSE_FILTER_IGNORE` (clicul trebuie să treacă mai departe la buton). Se centrează singur, exact, pe amândouă axele.
- **Marginile sunt alese să nu iasă jumătăți de pixel:** 9 în panou (casetă 114×56 → steag 84×56, rămâne 30 pe orizontală = 15+15) și 8 la butonul din colț (casetă 36×36 → steag 36×24, rămâne 12 pe verticală = 6+6). Cu 8 în panou ieșeau 29 px, adică 14,5 — un pixel în plus într-o parte.
- Butonul din colț a pierdut și cele patru `content_margin` puse pe stylebox: erau acolo doar ca să facă loc iconiței, iar acum steagul e nod separat și nu le mai vede.
- ⚠️ **`_refresh_lang_button()` scrie acum în `_lang_steag.texture`, nu în `_lang_btn.icon`.**

**Verificat rulând meniul** (scenă de test ștearsă după), pe geometria nodurilor, nu pe praguri de culoare: steag **84×56** în butonul de 132×74, cu **24,0 stânga / 24,0 dreapta / 9,0 sus / 9,0 jos** la toate cele 9 limbi; la butonul din colț centrele coincid la virgulă (1048,0 și 1048,0). Plus poze cu panoul și cu meniul principal.
- 🧪 **Notă pentru data viitoare:** măsurarea „unde e steagul" citind pixeli din poză e înșelătoare — pragul de culoare pierde zonele închise (steagul Germaniei ieșea 35 px înălțime în loc de 56, din cauza dungii negre) și prinde fundalul verde al limbii selectate. Geometria nodurilor e sursa de adevăr.

---

## Session log — 2026-08-15 (Settings: aceeași mărime pe KEYBINDS și pe GRAPHICS)

**Cerut de Răzvan:** „când dau între keybinds și graphics se schimbă mărimea ferestrei, dar eu vreau doar o mărime consistentă la ambele."

**Atinse:** `settings_ui.gd` (o funcție nouă, `_egalizeaza_paginile`).

- **Cauza:** comutarea taburilor face `visible = false` pe pagina inactivă, iar un `Control` ascuns nu mai intră în socoteala containerului. Blocul se strângea pe pagina deschisă, iar **rama de aramă se croiește după conținut** (`PanelContainer` + `StyleBoxTexture`, vezi `menu.gd::_rama_container`) — deci sărea și ea. La fel în pauză, care folosește același `SettingsUI`.
- **Leacul:** amândouă paginile primesc `custom_minimum_size` = cea mai mare dintre mărimile lor minime (`get_combined_minimum_size()`), și pe lățime, și pe înălțime. Pagina mai mică rămâne centrată în spațiul rezervat. Se calculează o singură dată, în `_ready` — dacă mai adaugi rânduri într-o pagină, se recalculează singur.
- Nimic nu crește peste ce era: KEYBINDS era oricum pagina cea mai mare ȘI cea deschisă implicit, deci rama rămâne exact cât era înainte pe ea.

**Verificat rulând meniul** (scenă de test ștearsă după): rama **520×474** și blocul **436×342**, IDENTICE pe ambele pagini (diferență `(0, 0)`); două poze care arată bara de taburi și butonul BACK stând pe loc la comutare.

---

## Session log — 2026-08-15 (TUFELE — Bush + Tall Bush, decor numai în pădure)

**Cerut de Răzvan:** „ți-am adăugat în folderul harta 2 imagini noi — Bush și Tall Bush — vreau să se spawneze doar în pădure, nu fac nimic sunt ca copacii."

**Atinse:** `bushes.gd` + `bush.tscn` + `tall_bush.tscn` (NOI), `main.tscn`, `nether.gd`, `limbo.gd`, `ender.gd`.

- **Generator nou `bushes.gd`** pe nodul `World/Bushes`, copiat după `props.gd`/`rocks.gd`: chunk-uri de 512 px, determinist (`hash(key) ^ SEED_SALT`), încărcare/descărcare pe rază de 3 chunk-uri. Decor pur — fără loot, fără interacțiune.
- 🆕 **SPRE DEOSEBIRE de copaci și pietre, tufele au SCENE** (`bush.tscn`, `tall_bush.tscn`). Prima variantă construia nodurile din cod, ca `props.gd`; Răzvan a întrebat „bushes de ce nu au tscn" și apoi le-a cerut explicit, ca să poată muta coliziunea cu mouse-ul. **Consecința, spusă și lui:** mărimea, cutia de coliziune și umbra nu se mai calculează din pixelii texturii — sunt puse de mână în scenă. Dacă schimbă `scale` la `Sprite2D`, trebuie să potrivească singur și `CollisionShape2D` și `Umbra`. De-aia `bush_scale` / `hitbox_*` / `shadow_*` / `sort_anchor` **nu mai există** ca `@export` în `bushes.gd`.
  - **Convenția scenei:** originea rădăcinii (`StaticBody2D`) e linia de sortare pe Y (≈35% din înălțime, de la pământ); `Sprite2D` are `offset` care așază desenul față de ea, deci generatorul pune pur și simplu `bush.position = pos`, fără nicio corecție de tip `sort_shift`. Nodurile se cheamă `Sprite2D`, `Umbra`, `CollisionShape2D`; codul le caută pe nume, cu căutare de rezervă dacă le redenumește.
  - **Lățimea tufei** (pentru distanța minimă între ele) nu se mai poate lua dintr-un `@export`: se măsoară o dată la pornire, în `_masoara_scenele()`, instanțiind fiecare scenă, citind `used_rect(textura) × scale` și aruncând nodul. 30.6 px și 22.5 px azi.
  - `solid = false` nu mai construiește altfel nodurile: doar pune `disabled = true` pe `CollisionShape2D`, ca scena să rămână neatinsă.
- 🚫 **„Nu vreau să se suprapună cu alte obiecte. Vreau să aibă un spațiu între ele de spawnare"** (a treia cerere din aceeași zi). Două schimbări de fond:
  - **Verificarea nu mai e pe cercuri, ci pe DREPTUNGHIURI VIZIBILE.** Distanța centru-centru cu rază = jumătate din LĂȚIME zicea „e bine" pentru o tufă înaltă care intra cu vârful peste ce era deasupra — și chiar așa ieșea în măsurători (1 suprapunere tufă↔tufă, 4 tufă↔copac). Acum umflăm dreptunghiul tufei cu `spatiu_liber` în toate părțile și cerem `Rect2.intersects() == false` cu al oricui.
  - **Față de copaci se măsoară COROANA ÎNTREAGĂ, nu trunchiul.** Regula „o tufă sub coroană arată firesc" (moștenită de la `rocks.gd`) era exact sursa suprapunerilor.
  - Cele patru reglaje vechi (`min_gap_hitboxes`, `tree_clearance`, `rock_clearance`) s-au strâns într-unul singur, **`spatiu_liber` = 24 px**, măsurat margine-la-margine. `struct_clearance` a rămas separat (structurile spun doar poziția, nu și mărimea) și a urcat la 140. `path_clearance` 1 → 2 tile-uri.
  - `bushes_per_chunk` 3 → **6**, ca să compenseze: cu regula strictă, un copac blochează o suprafață mare în jurul lui, iar din ~3 încercări pe pătrat treceau prea puține.
  - Formula dreptunghiului unui copac/pietre pornește de la poziția lor BRUTĂ. `props.gd`/`rocks.gd` pun `sprite.offset.y = h*(sort_anchor-0.5)` și apoi ridică nodul cu `sort_anchor*h*scara` — **cele două se anulează**, deci `_cutie_prop()` n-are `sort_anchor` în ea. Poziția brută e chiar punctul în care obiectul atinge pământul.
  - ⚠️ Când măsori suprapuneri într-o scenă de test, **sari peste frunzele care cad**: sunt Sprite2D-uri într-un nod separat sub copac, iar dacă le numeri ca „copaci" ies suprapuneri false (52 de „copaci" în loc de 21).
- **Doar în pădure:** aceeași verificare ca la copaci, `BiomeMap.desertness_at_chunk(pos) > 0.0` → sărim poziția. Deci nimic nici pe nisip, nici pe gradientul de tranziție.
- **Solide, ca și copacii** (`solid = true`, cutie mică fix la bază). E `@export`, deci se trece pe `false` din inspector dacă vrea să treacă prin ele.
- **Reglaje:** `bushes_per_chunk = 3` (maxim, deci ~1,5 în medie — mai dese decât copacii), `bush_scale = 0.6` → 54 px (Bush) și 67 px (Tall Bush) pe ecran, lângă un player de ~62 px și copaci de ~258 px. Umbra de la bază e aceeași din `ground_shadow.gd`.
- **Tufele cedează în fața TUTUROR** (sunt ultimele venite): copaci, pietre, poteci și orice frate din `World` care expune convenția `chunk_<x>_pos(key) -> Vector2`. Lista aia **se descoperă singură** prin `get_method_list()`, deci prinde automat și generatoarele viitoare. Excepție scrisă în cod: `Chests` — cuferele stau lângă poteci (de care ne ferim oricum), iar funcția lor are nevoie de nodul `Paths`, pe care ele îl caută abia la primul `_process` (ar crăpa dacă am întreba mai devreme). Din același motiv `bushes.gd` nu generează nimic până nu are el însuși `Paths`.
- **Trecut în `WORLD_NODES` din `nether.gd`, `limbo.gd` ȘI `ender.gd`** — regula de mai sus. `preload_all.gd` NU trebuia atins: scanează `res://harta` recursiv, deci a luat singur cele două PNG-uri.
- ⚠️ **PNG-urile n-aveau `.import`** (Răzvan le-a pus pe disc, nu prin editor). Rulat `--headless --import` înainte de orice test, altfel `preload` crapă.

**Verificat rulând lumea adevărată** (scenă de test ștearsă după): 61 de tufe încărcate în jurul player-ului, **0** în deșert sau pe gradient, **0** pe potecă, cea mai mică distanță între două tufe 76 px; mutat player-ul în inima unui deșert (3,5 chunk-uri adâncime) → **0** tufe acolo; screenshot pe iarbă cu tufele lângă copaci și pietre, la mărimea potrivită. **După trecerea pe scene, rulat din nou:** 59 de tufe, 0 în deșert, 0 pe potecă, 0 fără coliziune, nodurile ies `TallBush [Umbra, Sprite2D, CollisionShape2D]`, mărimile pe ecran identice (61×54 și 45×67 px) — deci scenele redau exact ce construia codul înainte. **După regula de suprapunere, măsurat pe dreptunghiuri:** 31 de tufe / 27 de copaci / 22 de pietre în jur, **0 suprapuneri** peste tot, cel mai mic spațiu rămas 24,4 px (tufă↔tufă), 26,2 px (tufă↔copac), 24,3 px (tufă↔piatră), 150,4 px (tufă↔structură) — adică exact `spatiu_liber`, nici sub.

---

## Session log — 2026-08-15 (mărimea armei, toată pe procente: Pufferfish +10%, Double Dose +5%)

**Cerut de Răzvan:** „Pufferfish vreau să dea +10% size nu +10 size și double dose să scrie nu bigger projectiles ci +5% weapon size."

**Atinse:** `levelup.gd`, `player.gd`, `i18n.gd`, `codex.html` (+ artifact-ul republicat).

- **Pufferfish: `weapon_size_px += 10` → `weapon_size_mult *= 1.10`**, descriere „+10% Weapon size". Cei 10 px se raportau la `BULLET_BASE_PX` (27), deci prima luare dădea de fapt **~+37%**, iar fiecare repetare tot mai puțin (aditiv pe px, împărțit la aceeași bază). Acum e procentual și **se compune**, ca Rat's Burger: două luări = ×1.21.
- **Double Dose: `bullet_scale += 0.3` → `weapon_size_mult *= 1.05`** (`+5 damage` a rămas), descriere „+5% Weapon size +5 damage". ⚠️ **Nu e doar text:** înainte umfla DOAR proiectilul (și era oricum tăiat de `BULLET_SIZE_CAP` la pistol/cuțit); acum crește mărimea ARMEI, deci lucrează și la tăietura sabiei, lama coasei și dârele de foc/gheață. Pentru pistol e o pierdere curată (plafonul lui e 1.0), pentru corp la corp e un câștig nou.
- **Toate trei intră acum în același `weapon_size_mult`**, deci se înmulțesc între ele: Pufferfish ×2 + Double Dose + Rat's Burger = 1.10² × 1.05 × 1.30 = **165%** (măsurat).
- 🧹 **`weapon_size_px` și `bullet_scale` nu mai sunt schimbate de niciun upgrade.** Le-am lăsat în `player.gd` (rămân reglaje din inspector, iar formulele `weapon_size_scale()` / `bullet_size_scale()` le folosesc mai departe), dar cu comentariul actualizat — altfel data viitoare cauți degeaba cine le mișcă.
- **i18n:** cheia „+10 Weapon size" → „+10% Weapon size", iar „Bigger Projectiles +5 damage" → „+5% Weapon size +5 damage", cu cele 8 traduceri refăcute.

**Verificat rulând** (două scene de test, șterse după): `weapon_size_scale()` 1.0000 → 1.1000 → 1.2100 (Pufferfish ×2) → 1.2705 (+ Double Dose) → 1.6517 (+ Rat's Burger), `weapon_size_px` rămâne 0 și `bullet_scale` 1.00; screenshot cu ecranul de Level Up unde cele trei cartonașe scriu „+10% WEAPON SIZE", „+5% WEAPON SIZE +5 DAMAGE", „+30% WEAPON SIZE". `tool_check_i18n` → „✔ TOTUL E TRADUS". Codexul: cardurile Pufferfish/Double Dose rescrise + nota statului „Weapon Size"; verificat că `id|iconiță|raritate` și textele `game:` sunt identice cu `levelup.gd` (51 iteme, zero diferențe).

---

## Session log — 2026-08-14 (statusul „Damage Taken", scos din joc + Vodka refăcută)

**Cerut de Răzvan:** „Vreau să scoți statusul de damage taken din joc. La Vodka vreau acum să îi dea +3 Damage, Reflect 10% of damage taken."

**Atinse:** `player.gd`, `casino.gd`, `levelup.gd`, `i18n.gd`, `codex.html` (+ artifact-ul republicat).

**1. „Damage Taken" nu mai e status.** A ieșit din cele trei locuri unde trăia ca status: rândul din panoul de la level up (`player.stat_lines`), reperul lui din `_stats_base` și intrarea `dmgtaken` din cazinou (lista `STATS` + `_valoare` / `_afisare` / `_aplica`, deci nu mai poate fi nici pariat la ruletă).
- ⚠️ **Cifra a rămas, statul a plecat.** `player.contact_damage` (5) e de unde pornește damage-ul de contact — fără el inamicii n-ar mai face damage deloc. L-am scos din `@export` (nu mai are ce căuta în inspector, nimic nu-l mai schimbă) dar l-am lăsat `var`, nu `const`, ca scenele de test cu grile mari de dummy-uri să-l poată pune pe 0 (vezi nota veche din log-ul de la grile).
- Nu era în META (`game_settings.gd`), deci magazinul permanent n-a trebuit atins.

**2. Vodka: `-3 Damage taken` → `+3 Damage, Reflect 10% of damage taken`.** `p.bullet_damage += 3` și `p.reflect_pct += 0.10`.
- 🔑 **Reflexia e ACEEAȘI mecanică cu Old Reliable** (`reflect_pct`, aplicat în `player._take_contact_damage`, ramură separată de Mike's Hedgehog), deci cele două **se adună**: verificat prin rulare, 0.10 + 0.15 = 0.25. Nu blochează lovitura, doar o întoarce, și are minim 1 damage — plasa aia era deja acolo pentru Old Reliable.
- ⚠️ De remarcat pentru balans: Old Reliable e **Common** și dă 15%, Vodka e **Uncommon** și dă 10% + 3 damage. Așa a fost cerut; dacă pare pe dos, cifra se schimbă într-un singur loc (`"vodca"` din `_apply`).

**3. Codexul.** `codex.html`: cardul Vodka rescris (cu `isNew: true`, deci apare cu eticheta „nou" — nu e item nou, dar tot ce scrie pe el e nou), nota de la Old Reliable spune acum că se adună cu Vodka, rândul „Damage Taken" scos din tabelul „Statusuri de start", iar cifra (5 la fiecare 0.5 s sub 60px) mutată în nota de la Max HP, ca informația să nu se piardă. Republicat pe același URL.

**Verificat rulând** (scenă de test peste `main.tscn`, ștearsă după): panoul de statusuri are acum 12 rânduri și niciunul „Damage Taken"; cartonașul Vodka scrie „+3 DAMAGE, REFLECT 10% OF DAMAGE TAKEN" pe un rând; `bullet_damage` 24 → 27, `reflect_pct` 0 → 0.1, `contact_damage` neatins; `casino.gd` compilează. `tool_check_i18n` → „✔ TOTUL E TRADUS". Codexul randat în Chrome headless: 102 carduri, pagina nu e goală.

---

## Session log — 2026-08-14 (monumentul: „Swarm has started" + cronometrul hoardei sub cel al rundei)

**Cerut de Răzvan:** „Când apeși pe monument spawner vreau să scrie «Swarm has started» și să ai sub timer-ul normal să scrie «Swarm Timer:» (și timpul cât e rămas)."

**Atinse:** `monument.gd`, `hud.gd`, `i18n.gd`.

- Bannerul de la invocare zice acum **„Swarm has started"** în loc de „THE MONUMENT AWAKENS" (subtitlul „Double XP. Triple speed. Triple damage." a rămas). Cheia veche a ieșit din `i18n.gd`.
- **Cronometrul hoardei** — `hud.swarm_label`, exact sub cel al rundei (`offset_top = 14 + TIMER_SIZE + 14`), roșu ca Final Swarm, corp 24. Scrie „Swarm Timer: 0:10" și numără invers cât curge hoarda, adică `spawn_duration` (10 s) — atât ține hoarda, nu există altă durată de măsurat. Rotunjit în SUS (ca la Nether), ca prima cifră să fie 0:10 și ultima 0:00.
- ⚠️ **Cine numără: monumentul, nu HUD-ul.** `monument.gd::_scoate_hoarda` avea deja un ceas propriu, adunat din delta cadrelor și oprit pe pauză (Level Up) — un al doilea ceas în HUD ar fi arătat alte cifre decât hoarda care chiar curge. Deci monumentul cheamă `hud.swarm_timer(cât a mai rămas)` la fiecare cadru.
- ⚠️ **Stingerea merge pe „tăcere", nu pe un semnal de final** (`SWARM_TTL = 0.4`): bucla hoardei se poate rupe la mijloc (mori, dai restart, dispare lumea) și atunci n-ar mai apuca nimeni să anunțe „gata". Așa, dacă monumentul tace 0,4 s, HUD-ul stinge singur eticheta. Nu se stinge nedorit pe pauză, fiindcă și HUD-ul stă (`PROCESS_MODE_INHERIT`), deci TTL-ul nu scade.
- Se ascunde odată cu cronometrul rundei în Limbo/Nether/Ender — acolo dimensiunea își desenează propriul ceas fix în locul ăla și s-ar fi suprapus.

**Verificat rulând** (scenă de test peste `main.tscn`, ștearsă după: Celesto marcat ca învins, monument pus lângă player, `invoca()`): banner-ul apare, „SWARM TIMER: 0:09" stă sub „9:57", la 5 secunde scrie 0:05, iar după ce se termină vărsatul eticheta e `visible = false` cu ultimul text 0:00; 108 inamici în lume. `tool_check_i18n` → „✔ TOTUL E TRADUS".

---

## Session log — 2026-08-14 (Dubiosu: doar în Nether, fără iteme, 1v1 de barbut)

**Cerut de Răzvan:** „Vreau shady guy să se spawneze doar în nether. Scoate de tot upgrade-urile de la el. Vreau să fie un 1v1 de barbut. Mai întâi dă el un roll și apoi te întreabă dacă îl bați primești bonus pe un stat random. +25% la un stat dacă câștigi și dacă pierzi -25% la un stat random + 10% difficulty."

**Atinse:** `dubiosi.gd` (rescris), `dubios_menu.gd` (rescris pe jumătate), `dubiosu.gd`, `nether.gd`, `player.gd`, `spawner.gd`, `levelup.gd`, `i18n.gd`, `tool_check_i18n.gd`.

**1. Apare doar în Nether.** Generatorul e acum singurul din `World` care merge PE DOS față de toate celelalte: „Dubiosi" a fost scos din `WORLD_NODES` din `nether.gd` (ca să NU se stingă la intrare), iar regula lui stă la el acasă — `dubiosi.gd::_process` se uită la `nether.active` și, dacă nu ești acolo, își golește chunk-urile și tace. ⚠️ Golirea trebuie să șteargă și `_loaded`, altfel la următoarea intrare generatorul crede că bucățile alea există deja și Nether-ul rămâne gol pe veci (aceeași capcană ca la `nether.gd::_toggle_generator`). În `limbo.gd` și `ender.gd` a rămas trecut normal — acolo nu are ce căuta.
- **Șansa a urcat de la 2% la 5% pe chunk** (`dubios_chance`): Nether-ul ține 7 minute și umbli pe o bucată mică de hartă, la 2% puteai să-l faci întreg fără să dai peste niciunul.
- **Ferelile de decor au dispărut** (copaci, pietre, statui, EGT, Alba-Neagra): în Nether toate alea sunt oprite ȘI golite, deci se ferea de obiecte invizibile. În locul lor: `_prea_aproape` — nu se așază la mai puțin de 320 px de portalul de întoarcere sau de structura lui Saratalin. ⚠️ Verificarea sare peste dubioșii NOȘTRI (`is_ancestor_of`): doi oameni din chunk-uri vecine s-ar fi anulat pe rând, după ordinea de încărcare, și unul ar fi clipit când te plimbi.

**2. Itemele lui — scoase de tot din joc.** Cursed Tome, Iron Helmet, Blame Circle și Arcane Magic nu mai există nicăieri: nici lista, nici efectele, nici cheile de traducere. Odată cu ele au plecat și cârligele lor din restul jocului, care rămâneau moarte: `player.spawn_rate_mult` / `damage_taken_mult` / `damage_dealt_mult` (+ locurile lor din `spawner.gd`, `player.take_damage` și `player.damage_mult`), toată mașinăria `_start_state` / `NU_SE_RESETEAZA` / `_prinde_starea_de_start` / `reset_la_start` din `player.gd` (exista DOAR pentru Arcane Magic) și `levelup.uita_unic`. Codexul n-a avut nevoie de nimic: itemele astea n-au apucat să intre în el.

**3. Barbutul.** Masa are acum **patru zaruri**: 0-1 ale lui (stânga), 2-3 ale tale (dreapta), fiecare aruncat de la el de-acasă. Curgerea: deschizi → o clipă de masă goală (`PAUZA_EL`) → dă EL → apar suma lui, miza și două butoane → **ROLL** sau **WALK AWAY** → dai tu → se socotește. Mai mare = câștigi (+25% la un status), mai mic = pierzi (-25% la un status **și** `Difficulty.add_trade_penalty(0.10)`, exact mecanismul de la Alba-Neagra și de la statuia Ender), **egal = se dă mâna din nou** de la capăt.
- `_z` (perechea care zboară) nu mai e paralel cu `_zaruri`: fiecare intrare ține `"i"`, adică ce zar de pe masă e — altfel n-ai putea arunca doar jumătate din masă.
- **Zarurile care n-au fost aruncate în mâna asta nu se văd.** Lăsate pe masă arătau fețe care nu însemnau nimic (rămase din mâna trecută), iar ochiul le citea ca pe o sumă care contează. Cutia de scor a celui care n-a dat stă stinsă, nu goală, ca panoul să nu-și schimbe înălțimea.
- ⚠️ **Becul de deasupra mesei a trebuit lărgit de la 40° la 58°.** Stă la ~4,65 deasupra postavului, deci la 40° balta lui de lumină avea raza ~1,7 — iar zarurile de la marginile mesei (±2,02) cădeau complet în afara ei și ieșeau vizibil mai închise, de parcă erau de altă culoare.
- Statusurile care pot fi atinse au rămas cele de la Blame Circle (`STATS`): Damage, Attack Speed, Move Speed, Max HP, Weapon Size — doar de-astea care nu pot fi zero la începutul rundei (din 0, și +25% și -25% fac tot 0, și ai fi crezut că pariul e stricat).

**⚠️ WALK AWAY e gratis, și e o gaură ȘTIUTĂ.** I-am arătat-o lui Răzvan înainte (îi vezi suma ÎNAINTE să te hotărăști, deci joci doar când el a dat mic și pleci când a dat mare — jucat perfect, pariul iese aproape mereu în favoarea ta) și a ales-o oricum. Dacă se răzgândește: ori scoți butonul din `_build`, ori îi pui un preț în `_pe_pleaca` (ex. numai `PEDEAPSA`, fără minusul pe stat). Singurul cost de acum: omul se consumă la deschidere, deci un WALK AWAY îl arde.

**Verificat rulând** (două scene de test, șterse după): meniul dus prin toate ramurile — câștig, pierdere reală (Max HP 100→75, `trade_penalty` 1.0→1.1), pierdere forțată (Attack Speed 0,75→1,0 interval, penalty →1.21), egalitate → ROLL AGAIN → mână nouă cu masa curată, WALK AWAY → meniul închis și jocul repornit; plus capturi în toate stările. Spawn-ul: cu șansa forțată la 100%, **0 dubioși în lumea normală**, 46-48 în Nether (unul blocat de fereala de portal — cel mai apropiat la 325 px, prag 320), **0 înapoi în lume**, și o poză cu ei pe cărămidă, cu „Press E to interact". `tool_check_i18n` → „✔ TOTUL E TRADUS".

⚠️ **Capcană de harness, nu de joc:** dacă scena de test e `PROCESS_MODE_ALWAYS` și instanțiezi `main.tscn` ca **copil** al ei, jocul moștenește „ALWAYS" și merge mai departe peste pauza meniului — te trezești cu player-ul mort de inamici cât te uiți la zaruri. Pune `main.process_mode = PROCESS_MODE_PAUSABLE` explicit.

---

## Session log — 2026-08-13 (Aruncarea zarurilor, refăcută: gravitație adevărată, zar tocit, lumină de studio)

**Cerut de Răzvan:** „Zarurile nu se aruncă aesthetic, se văd urât. Poți te rog să le faci ca un studio de game development profesionist? Vreau să simți că ești acolo în experiența de barbut. Vreau animația să fie smooth."

**Atins:** doar `dubios_menu.gd` (partea de aruncare + lumea 3D). Efectele itemelor, împărțeala pe perechi și restul meniului — neatinse.

**Cum am judecat:** nu din ochi. Am scos aruncarea ca **film cadru cu cadru** (o scenă de test temporară care fotografiază `SubViewport`-ul la fiecare 100 ms și le lipește într-o singură planșă) și am citit planșa. Fără ea nu se vedea niciunul dintre cele patru lucruri de mai jos. ⚠️ Prima planșă a ieșit înșelătoare fiindcă lua **un cadru din N**, iar jocul mergea la 140 fps: acoperea doar prima treime a aruncării. Se ia pe **timp**, nu pe cadre.

**1. ⚠️ BUG-UL DE FOND: ordinea vârfurilor era pe dos, iar zarul se umbrea singur.** Triunghiurile din `_mesh_zar` erau scrise în sensul acelor de ceasornic văzut din afară, iar materialul avea `CULL_DISABLED` — deci zarul intra în harta de umbră cu AMBELE fețe și fața lui de sus se umbrea pe ea însăși. De aici veneau zarurile cenușii și „plate", cu lumina lipsă fix de unde bătea cel mai tare. Acum ordinea e `[0,2,1,0,3,2]` + `CULL_BACK`. **Dacă vreodată zarul se face negru sau dispare, ăsta e primul lucru de verificat.** Al doilea (tot umbră): lumina direcțională împrăștia harta de umbră pe 100 de unități în 4 felii pentru o masă de 2 unități → pete cenușii cu muchie dreaptă peste fețele luminate; se repară cu `directional_shadow_max_distance = 16` + `SHADOW_ORTHOGONAL`.

**2. Mișcarea.** Înainte: zarurile alunecau lateral cu o singură frânare de 0,35 s, se roteau cu viteză fixă și se răsuceau brusc pe fața finală. Rezultat: ajungeau pe loc în prima treime și **stăteau nemișcate o jumătate de secundă**, nu atingeau niciodată masa (saltul era un sinus care le RIDICA, nu o cădere), și făceau amândouă același lucru în același moment. Acum:
- **pe verticală, gravitație adevărată** (`GRAVITATIE`, `RESTITUTIE`): fiecare săritură e mai mică și mai deasă decât precedenta — ritmul „tac … tac .. tac.tac" de la barbut;
- **ciocnitura se calculează pe COLȚUL cel mai de jos al zarului rotit** (`_cel_mai_jos`, 8 colțuri), nu pe centrul lui, deci zarul chiar cade pe un colț și se răstoarnă de pe el;
- **pe orizontală drumul rămâne desenat de mână** (frânare până la locul lui). Dinadins: o simulare adevărată se oprește unde vrea ea, iar fereastra e o fâșie de 560×190 — un zar ieșit din cadru sau urcat peste celălalt strică tot ecranul. Ce dă senzația de fizică e săritura și rotația, nu traiectoria laterală;
- **fiecare zar are ale lui**: întârziere, înălțime, viteză de rotație, durată. Se opresc decalat — și tocmai asta deosebește o aruncare de o animație.

**3. ⚠️ Rotația finală se alege ACUM, nu la începutul aruncării.** Asta era a doua cauză a smuciturii: ținta se trăgea la plecare cu o răsucire oarecare, deci de multe ori zarul avea de făcut o jumătate de tură ÎNAPOI ca s-o prindă. Acum, când s-a terminat de sărit, se caută dintre 48 de așezări (toate arată aceeași cifră) cea mai apropiată de cum stă zarul chiar atunci (`_cea_mai_apropiata`, prin `|dot|` de quaternioni) — ultima mișcare e mereu scurtă, ca o cădere pe fața pe care oricum era gata să cadă, cu o trecere mică peste țintă și înapoi (`_rasturnare`).

**4. Cum arată.** Zarul nu mai e cub tăios, e **cutie rotunjită** (`_pe_rotunjit`: strângi punctul într-un cub mai mic, îl scoți la raza `r` — mijlocul feței rămâne plat, muchia devine sfert de cilindru, colțul optime de bilă), iar tocitura e ce prinde lumina. Bulinele sunt **scobite**, nu pete lipite: peretele dinspre lumină întunecat, fundul mai deschis, buza de jos-dreapta cu o dungă de lumină. ⚠️ Deschiderea crește cu PĂTRATUL distanței de centru — liniar ieșeau buline cenușii, ca șterse cu guma. Lumina e pe trei surse (cheie caldă cu umbră / umplutură / contur rece din spate) plus un **bec deasupra mesei** care face o baltă de lumină și lasă marginile în întuneric. Sub fiecare zar e o **pată de umbră de contact** care se strânge și se întunecă pe măsură ce zarul coboară — umbra „adevărată" cade oblic și nu-ți spune niciodată dacă zarul ATINGE masa.

**5. Cum se simte.** Fiecare ciocnitură dă un tic (ton și tărie după cât de tare a lovit) și un **ghiont de cameră** care se stinge în ~0,1 s. ⚠️ Ticurile NU merg prin `Audio.play`: acolo același sunet nu se pornește mai des de `MIN_GAP_MS`, iar ultimele sărituri vin la o zecime de secundă una după alta — s-ar fi auzit doar prima. Meniul are trei boxe ale lui, altfel ultima săritură își tăia sunetul precedent. La final, suma și cartonașul primesc un „pumn" de mărime (`_pumn`).

**Reglaje, dacă vrei altfel:** `GRAVITATIE` / `RESTITUTIE` (cât de vioaie e săritura), `OPRIRE` (cât de devreme se lasă pe față — mai mare = răsturnare finală mai vizibilă), `T_ORIZONTAL` (cât ține drumul lateral, per zar), `LOCURI` (unde se opresc; ⚠️ depărtarea pe Z e ce împiedică al doilea zar să treacă PRIN primul când îl depășește), `ROTUNJIME`, și energiile celor patru lumini.

**Verificat rulând:** film cadru cu cadru al aruncării (de 5 ori, cu reglaje între), fiecare lumină izolată pe rând (așa a ieșit la iveală auto-umbrirea), toate cele 6 cifre puse pe rând în sus și numărate bulinele (1…6 corect), ecranul întreg în cele trei stări (așteptare / aruncare / rezultat), și un boot curat al jocului real. Aruncarea ține acum ~1,3 s, față de ~1,45 s înainte. Fișierele de test — șterse.

---

## Session log — 2026-08-13 (Dubiosu: nu mai alegi, DAI CU ZARURILE — două zaruri 3D în chenare de aramă)

**Cerut de Răzvan:** „ți-am pus în folderu Upgrade Dubios un fișier nou - Dice.max - e un fișier 3d cu niște zaruri. Vreau ca meniul de la dubios să fie schimbat cu Border EGT făcut profesional și în loc să îți alegi tu itemele vreau să dai cu zarul să îți pice random un item dintre upgrade-urile de la dubios."

**Atinse:** `dubios_menu.gd` (rescris pe jumătate), `dubiosu.gd` (comentariu), `i18n.gd` (2 chei), `tool_check_i18n.gd` (1 ignorat). Fără fișiere noi.

**⚠️ `Dice.max` NU se poate folosi.** E format 3ds Max (fișier OLE compound, 384 KB) — Godot nu-l citește, și nici Blender. Trebuie exportat din 3ds Max ca **glTF Binary (`.glb`)** în `harta/Upgrade Dubios/Dice.glb`. Codul îl caută acolo (`MODEL_ZAR`) și, dacă îl găsește, îl folosește în locul cubului desenat în cod; până atunci merge cu cubul. **Când apare modelul, verifică pe ce direcție cade fiecare față** — `_baza_pentru()` presupune 1 sus, 6 jos, 3 pe +X, 4 pe −X, 5 pe +Z, 2 pe −Z; altă numerotare = zarul se oprește pe cifra greșită (itemul rămâne corect, el vine din pereche, dar cifra de pe masă minte). Modelul e scalat automat la `MARIME_ZAR` și centrat pe originea nodului (`_potriveste_marimea`), fiindcă un export din 3ds Max vine des în centimetri.

**1. Chenarele.** Meniul a trecut de pe planșa lui verde (`harta/Upgrade Dubios/Border Dubios.png`) pe **arama casei** (`harta/EGT/Border EGT.png`), aceeași ca meniul principal, pauza, cazinoul, Alba-Neagra și level up. Planșa verde a rămas pe disc, nefolosită. ⚠️ La ramele puse PESTE ceva (masa de zaruri, cartonaș, chenarul iconiței) `draw_center = false` e obligatoriu: celulele EGT au mijlocul plin, bleumarin, nu transparent — aceeași capcană ca la `alba_menu.gd`.

**2. Cine iese la zaruri — și de ce NU după sumă.** Cele 36 de perechi sunt egal probabile, dar **sumele nu**: 2…12 ies în proporția 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1. 36 ÷ 4 = 9, iar cumulatele sumelor sar de la 6 la 10 — **nu există nicio tăietură în sume care să dea patru felii de câte 9**. Orice hartă „suma 2-4 → itemul X" ar fi făcut un item de trei ori mai rar decât altul, exact contra regulii că toate patru sunt de aceeași calitate. Deci itemul îl dă **perechea**: perechile se numerotează 0…35 și se ia restul la 4 → **fix 9 perechi = 25% pentru fiecare item**. Zarurile rămân zaruri adevărate (ce vezi pe masă chiar s-a tras, nimic nu e trucat), iar pe ecran scrie și suma, ca la barbut.

**3. Masa de zaruri.** Un `SubViewport` cu lumea LUI (`own_world_3d`), randat la dublu și strâns la loc într-un `TextureRect` (fără asta muchiile ies zimțate, fereastra e mică). ⚠️ `render_target_update_mode` stă pe **DISABLED cât meniul e închis** — altfel jocul ar plăti o randare 3D în fiecare cadru al rundei pentru un ecran pe care nu-l vede nimeni. Cubul se construiește de mână cu `SurfaceTool` (6 fețe, UV-uri într-o planșă 3×2 desenată în cod), **nu cu `BoxMesh`**: `BoxMesh` își împarte UV-urile cum vrea el, iar noi trebuie să știm EXACT ce cifră stă pe ce direcție, altfel n-am putea opri zarul pe fața care a ieșit.

⚠️ **Camera stă DEPARTE (≈11 unități) cu unghi mic, nu aproape cu unghi mare.** Prima încercare era la 6,8 și **tăia zarurile de jos**: fereastra e o fâșie de 560×190, deci pe verticală încape foarte puțin. La `fov` 33 și distanța 11 se văd ~2,2 unități pe înălțime — zarul (0,9) plus saltul, cu aer împrejur.

⚠️ **Lumina a doua NU are voie să fie `ACCENT` plin.** Prima încercare avea arama la energie 0,45 și a scos zaruri **cărămizii**, nu de os. Acum e 0,25 și decolorată; zarul rămâne fildeș, arama doar îl atinge. Tot așa, umbra neatinsă ieșea un triunghi negru cu muchii tăiate cu cuțitul (`shadow_blur = 2.0`, `shadow_opacity = 0.62`), iar postavul e mare de tot (40×30) ca marginea lui din spate să nu intre în cadru.

**4. Cum decurge.** Deschizi → zarurile stau pe masă pe fețe la întâmplare (altfel te întâmpină de fiecare dată aceeași pereche și arată a poză) → **ROLL THE DICE** → vin aruncate din stânga, se rostogolesc 0,95 s, se așază 0,5 s pe fața care a ieșit → apare suma → cartonașul itemului crește în ecran și efectul se aplică → **CONTINUE** închide. ⚠️ Cartonașul nu e ascuns de tot cât aștepți, ci lăsat **stins** (alpha 0,22): locul lui e ținut oricum ca panoul să nu-și schimbe înălțimea la jumătatea aruncării, dar gol de tot lăsa o gaură mare între masă și buton, de parcă meniul era neterminat.

ESC tot nu închide (omul s-a consumat deja când a scos marfa), iar butonul e blocat cât se rostogolesc. Sunetul: `dice_roll_*.wav` / `dice_shake_*.wav` **au existat cândva în proiect și s-au pierdut** (au rămas doar urme în `.godot/imported`, sursele nu sunt nici în git) — până revin, ticul de zar căzut e împrumutat de la cheia de cufăr.

**Neatins dinadins:** efectele (`_apply`, `_blame_circle`, `_arcane_magic`, `_acelasi_fel`) sunt exact cele de dinainte. S-a schimbat doar CUM ajungi la item.

**Verificat rulând** (`test_dubios.tscn`, temporar, șters după): toate 6 fețele se opresc chiar pe cifra cerută (verificat matematic, nu din ochi — se caută ce față ajunge pe +Y după `_baza_pentru`), împărțeala perechilor iese **9/9/9/9 din 36**, plus capturi de ecran la repaus, în timpul rostogolirii și la rezultat. `tool_check_i18n` → „✔ TOTUL E TRADUS".

---

## Session log — 2026-08-12 (spawn aleator în lumea normală + damage/viteză îngroșate)

**Cerut de Răzvan:** „vreau inamicii în lumea normală să se spawneze random (inamicii diferiți în sine nu mai vreau să aibă un timp anume la care se spawnează și câți, vreau din prima să fie spawn rate-ul și sprite-urile random). Damage-ul, hp-ul și movement speed-ul vreau să scaleze cu timpul, să fie puțin greu."

**Atinse:** `spawner.gd`, `difficulty.gd`. Fără fișiere noi.

**1. Valurile.** Până acum fiecare polițist avea ora lui fixă și felia lui fixă: Skinny de la 1:00 cu 35%, SWAT de la 4:00 cu 20%. Adică fiecare rundă arăta identic în aceleași minute. Acum, la fiecare **10–22 s**, `_val_nou()` trage la sorți **odată** două lucruri: **amestecul** (fiecare fel primește ponderea lui de bază × un factor aleator între 1/2.2 și 2.2) și **ritmul** (un multiplicator peste rata de spawn). Toți trei sunt pe masă **de la secunda 0**; `skinny_after`/`skinny_share`/`swat_after`/`swat_share` au dispărut.

🔑 **Ponderile de bază NU sunt egale** (1.0 / 0.7 / 0.35) și asta e o decizie, nu o scăpare: un SWAT are de 5 ori viața unui polițist obișnuit, deci la șanse egale jumătate din runda de la 0:10 ar fi fost tocat buști — adică „imposibil", nu „greu", care e ce s-a cerut. Ponderile de bază spun cine e regula, sorțul de la fiecare val spune cât se abate valul ăsta de la ea. Ieșit pe 200.000 de inamici: **49,2% obișnuit / 33,4% Skinny / 17,4% SWAT** în medie, dar un val singur mută SWAT-ul între **4,4% și 39,4%**.

⚠️ **`ritm_min`/`ritm_max` (0.55–1.45) sunt așezate ca MEDIA să fie exact 1.0** (măsurat 1.0031 pe 1000 de minute simulate). Ritmul aleator e TEXTURĂ, nu o îngroșare pe furiș — dificultatea rămâne în întregime în `difficulty.gd`, altfel curbele de acolo n-ar mai însemna nimic și n-ai mai ști pe ce reglezi. Ritmul **alunecă** spre valoarea nouă în 1,2 s în loc să sară: un salt s-ar citi ca un lag, o alunecare se simte ca o maree.

⚠️ **Ritmul se aplică DOAR în lumea normală** (`_in_lumea_normala()`). Nether-ul și Ender-ul au fiecare formula lui, calibrată pe promisiuni exacte („aici nu e niciodată mai gol decât lumea la 2:00"), iar un multiplicator care se plimbă între 0.55 și 1.45 peste ea ar face promisiunile alea false o parte din timp.

⚠️ **Cronometrul valurilor merge pe `delta`, NU pe `Difficulty.time`** — ăla stă pe loc în Limbo, Nether și Ender, deci valurile ar fi înghețat acolo și te-ai fi întors în lume cu exact amestecul și, mai rău, cu ritmul blocat pe cifra de la plecare.

**2. Curbele.** Din cele trei cerute, **viața scala deja cel mai tare din tot jocul** (×31,9 la minutul 10) — pe ea am lăsat-o în pace tocmai fiindcă e motorul principal; urcată și ea, inamicii ar fi depășit orice build și ieșea „imposibil", nu „greu". Plate erau celelalte două, și pe alea le-am urcat:

| | înainte, la 10:00 | acum, la 10:00 |
|---|---|---|
| viață | ×31,9 | ×31,9 *(neatinsă)* |
| damage de contact | ×2,00 (și ×1 fix în primele 1:30) | **×2,75**, crescând de la secunda 0 |
| viteză | ×1,35 (liniar) | **×1,53**, compus după 1:30 |

⚠️ **Damage-ul se plătește PER INAMIC LIPIT DE TINE** (`player._take_contact_damage` trece prin toți din `contact_range`), deci ×2,75 cu trei pe tine = 41 de damage la fiecare jumătate de secundă din cei 100 de bază. De-asta s-a oprit la 2,75 și nu la 3+: pedeapsa pentru înconjurat se înmulțește oricum cu numărul lor, iar ăla urcă separat prin `spawn_mult()`.

⚠️ **Viteza s-a oprit la ×1,53 din cauza lui 160 vs 215:** Skinny și SWAT pleacă de la 160, player-ul de la 215. La ×1,35 abia îl ajungeau, la ×1,53 îl întrec (245) — ceea ce e chiar ideea (la minutul 10 fuga nu mai e un răspuns), dar orice cifră peste asta scoate fuga din joc cu mult înainte de Final Swarm.

⚠️ **Partea liniară a vitezei s-a mutat de pe `_phase1_minutes()` pe `_lin_minutes()`.** Dacă o lăsam să curgă pe toate cele 10 minute ȘI adăugam compunerea peste ea, cele două s-ar fi adunat de două ori și viteza ieșea ×1,8 în loc de ×1,53.

**Verificat rulând:** 200.000 de inamici pentru amestecul mediu, 400 de valuri pentru cât variază, 1000 de minute simulate pentru media ritmului, plus `main.tscn` ADEVĂRAT — la 6 s deja polițiști + Skinny amestecați, **la 14 s toate trei felurile, SWAT inclusiv** (imposibil înainte de 4:00), captură de ecran de la 9:45 cu toate trei pe ecran, zero erori la rulare.

---

## Session log — 2026-08-12 (Magnetul de XP)

**Cerut de Răzvan:** „ți-am pus o poză nouă în folderul xp — se numește magnet. Vreau să aibă un stroke de 1 pixel negru și să aibă drop rate de la inamici de 0.5%. Atunci când e ridicat de pe jos trage tot xp-ul de pe hartă și îl dă la player."

**Fișiere noi:** `magnet.gd` + `magnet.tscn`, `xp/magnet_contur.png`. **Atinse:** `xp.gd`, `enemy.gd`, `tool_contur_foaie.gd`.

**Conturul.** Nu l-am desenat de mână și nici nu l-am pus cu shader: `magnet.png` e 128×128, exact ca `key.png`, deci a intrat ca încă o linie în `tool_contur_foaie.gd` (culoare nouă, `NEGRU`) și scoate `xp/magnet_contur.png`. **Sursa lui Răzvan rămâne neatinsă**, deci unealta poate fi rulată de câte ori vrea fără să se îngroașe conturul — dacă ar scrie peste sursă, a doua rulare ar contura conturul.

**Obiectul de pe jos** e clonă de `key.gd`, nu de `xp.gd`: la cheie și la magnet cade unul la ~200 de morți, deci nu se strâng niciodată grămadă și n-au nevoie de contopirea în bule din `xp.gd`. Drop 0.5% în `_drop_xp`, independent de restul (poți primi și XP rar, și cheie, și magnet), căzut cu 22 px în DREAPTA — cheia cade în stânga, ca să se vadă amândouă dacă pică odată.

**Sugerea XP-ului.** Magnetul cheamă `atrage_la_player()` pe fiecare gemă din grupul „xp". Gema iese din grup pe loc (nu mai intră în contopiri cât zboară, și un al doilea magnet n-o mai pornește a doua oară) și zboară spre player accelerat, 3000 px/s² până la 2400 px/s.

⚠️ Zborul urmărește player-ul **cadru cu cadru**, nu pe o traiectorie calculată o dată (un tween spre poziția de la plecare ar fi ratat, fiindcă player-ul se mișcă). ⚠️ XP-ul se dă **la sosire**, nu tot deodată la ridicarea magnetului: așa bara se umple pe măsură ce curg gemele, ăsta e tot spectacolul itemului. ⚠️ Și **fără sunet** pe gemă: `_on_body_entered` (care sună) iese devreme cât gema e în zbor, altfel pe o hartă plină ar fi bubuit de sute de ori într-o secundă.

**Verificat rulând:** 31 de geme împrăștiate până la 3000 px (una la −1800, +900), magnet cules → **toate 31 adunate, 0 noduri rămase, XP exact 120 din 120**; captură de la zoom-ul REAL al camerei din joc (0,7), unde se vede conturul negru; captură din timpul sugerii, cu spirala de geme care curge spre player. `main.tscn` headless fără erori.

---

## Session log — 2026-08-12 (Dubiosu: marfa lui — 4 iteme care nu există nicăieri altundeva)

**Cerut de Răzvan:** „vreau dubiosu, când apeși E pe el, să îți dea 3 variante de iteme (ca upgrade-urile normale) doar că pe astea nu le găsești în upgrade-uri normale. Toate sunt aceeași calitate (**nu vreau să scrii asta undeva**). Ai un border în folderul Upgrade Dubios ca să faci tot meniul, inclusiv rama de la iteme."

**Fișiere noi:** `dubios_menu.gd`. **Atinse:** `dubiosu.gd` (interacțiune), `dubiosi.gd` (ține minte pe cine ai golit), `player.gd` (3 statusuri noi + copia stării de start), `spawner.gd`, `levelup.gd` (`uita_unic`), `pause.gd`, `main.tscn`, `i18n.gd` (11 chei × 8 limbi), `tool_check_i18n.gd`.

**Meniul.** Aceeași construcție ca ecranul de Level Up, dar cu planșa verde din `harta/Upgrade Dubios/` (tot 5×4 celule de 64px) și **fără rând de raritate** — calitatea lor nu se scrie nicăieri, cum a cerut. Nu există nici măcar câmp „rar" în listă: „aceeași calitate" înseamnă, pentru Arcane Magic, „tot din lista asta", deci n-are nevoie de un nume. Verdele (`#2C8A4D`) e **măsurat** din planșă, nu ales din ochi (regula casei). Un om îți scoate marfa **o singură dată**, iar ESC NU închide meniul: omul se consumă la deschidere, deci un ESC ar fi însemnat un om irosit.

**Cele patru iteme.** Cursed Tome (+25% spawn rate, cumulat) intră în `spawner.rata_curenta()`, nu în `_spawn_tick` — altfel Limbo, care își naște singur inamicii din formula aia, l-ar fi ignorat. Iron Helmet: **chiar 100%**, `take_damage` iese din funcție la `damage_taken_mult <= 0`, deci ești nemuritor; prețul (×0.75 damage dat) se compune. ⚠️ Reflectul (Old Reliable, Mike's Hedgehog) pleacă ÎNAINTE de linia aia, deci cască + Old Reliable = nemuritor cu spini. Blame Circle alege două statusuri **diferite** dintr-o listă în care niciunul nu poate fi 0 la start (dublu din 0 tot 0 face, ar fi părut item stricat) și lasă meniul deschis 1,8 s ca să apuci să citești ce ai pățit.

**Arcane Magic — partea grea.** Nu se poate face desfăcând efectele: `_apply` scrie direct în statusuri, iar din „viteza e 275" nu mai afli ce a adunat-o acolo. Deci `player.gd` ține `_start_state`, o copie a **tuturor** variabilelor de script, luată pe ultima linie din `_ready` (după armă, META și OP start, înainte de orice item), iar `reset_la_start()` o pune înapoi și meniul rejoacă peste ea o listă nouă. Se copiază toate variabilele, nu o listă scrisă de mână, altfel fiecare item nou care atinge un câmp nou ar fi început să fie uitat în tăcere.

⚠️ **Ce NU se resetează**, cu motivul lângă, în `NU_SE_RESETEAZA`. Cel periculos e **`xp_to_next`**: e amestecat — îl taie Grinder / Tome of Knowledge, dar îl și înmulțește cu 1,2 fiecare nivel. Pus înapoi la valoarea de la nivelul 1, ai fi urcat zece niveluri pe loc. E singurul efect de item pe care resetul nu-l desface. La fel `undying_used` (altfel itemul devenea „mai dă-mi o viață"). Itemele „unice" pierdute ies din carantina din `levelup.gd` (`uita_unic`), altfel Undying Spirit ar fi rămas interzis toată runda fără să-l ai. Și Arcane Magic **se exclude pe el însuși** din tragere, exact ca Lucky Die la cufere — altfel s-ar chema la nesfârșit.

**Itemele dubiosului sunt invizibile** pentru cazinou și pentru masa de schimb a statuii Ender: amândouă caută id-ul cu `levelup.item_dupa_id`, care întoarce null, și sar peste. Așa și trebuie — nu se pariază și nu se schimbă.

**Verificat rulând**, cu player adevărat: două tomuri → ×1,5625; casca → 50 damage încasat, viața neschimbată, `damage_mult` 1,0 → 0,75 → 0,5625; Blame Circle → „Move Speed doubled, Max HP down 25%" cu cifrele chiar mutate; Arcane Magic pe `[bere, seringa, jean_bomb, undying_spirit, cursed_tome]` → 5 iteme noi cu **exact aceleași rarități** (common, uncommon, legendary, legendary, dubios) și statusurile întoarse la bază (dmg 51→24, maxHP 135→100, spawn 1,25→1,0); E pe om → meniul se deschide și omul rămâne consumat. Plus două capturi din meniu, `tool_check_i18n` ✔ 278 chei × 8 limbi și `main.tscn` rulat headless fără erori.

⚠️ **Codexul de upgrade-uri (`codex.html` + artifactul) NU are încă itemele astea.** Nu erau în `levelup.gd`, deci n-au intrat automat nicăieri.

---

## Session log — 2026-08-12 (Dubiosu: NPC nou în lume, deocamdată fără treabă)

**Cerut de Răzvan:** „în folderu harta ai o poză nouă — dubiosu. Vreau să fie un npc ca Alba Neagra (să și aibă efect de respirat) — momentan nu vreau să facă nimic."

**Fișiere noi:** `dubiosu.gd` + `dubiosu.tscn` (omul), `dubiosi.gd` (generatorul). **Atinse:** `main.tscn` (nodul `Dubiosi` în `World`), `nether.gd` / `limbo.gd` / `ender.gd` (`WORLD_NODES`).

**Omul.** `StaticBody2D` cu sprite, exact tiparul de la `alba.gd`: arta coboară `ACOPERIRE_JOS = 74` px sub originea nodului (originea e linia de Y-sort, deci player-ul care trece prin fața lui e desenat peste el), iar respirația e `scale.y` ×1,018 dus-întors în 2,3 s, cu `offset.y` tras în jos în paralel cu `talpă × (k−1)/k` — fără asta un `Sprite2D`, care se scalează din centru, i-ar băga tălpile în pământ la fiecare inspirație. **Măsurat:** talpa se mișcă **0,11 px** pe o respirație întreagă, adică deloc.

**⚠️ Nu face nimic, INTENȚIONAT.** Nu e în grupul `"interactable"` și n-are `invoca()`, deci `interact_ui.gd` nici nu se uită la el: nu apare „Press E to interact". Un prompt care nu face nimic arată a bug. Când o să primească o treabă: `add_to_group("interactable")` + `invoca()` (+ `poate_invoca()` dacă se consumă) în `dubiosu.gd`, ȘI `_folosite` + `marcheaza_folosit` în `dubiosi.gd`, copiate din `albas.gd` — fără ele ar reveni întreg de fiecare dată când chunk-ul se descarcă și se regenerează.

**Generatorul** e `albas.gd` cu altă sămânță (`0xD0B1`) și 2% pe chunk, ferit de copaci, pietre, statui, EGT-uri **și de oamenii de Alba-Neagra** (`min_dist_alba = 260`, întrebat prin `chunk_alba_pos`, care răspunde înainte să existe nodul). Fără listă de „folosiți", că n-are ce consuma.

**Cifrele artei** (măsurate, nu ghicite): poza e 128×128, desenul ocupă x 31…97, y 8…123 → `offset.y = -12.75` scris în scenă pentru editor (jocul îl recalculează oricum). Mărimea e aceeași ca la omul de Alba-Neagra (`art_scale = 1.6` × scara nodului 0,8). ⚠️ Poza era **neimportată** (fără `.import`), deci un `load()` dintr-o rulare directă ar fi dat „No loader found" — rulat `--headless --import`.

**Verificat:** captură cu el lângă omul de Alba-Neagra și lângă player, pe iarbă (Y-sort și tălpile bune), talpa măsurată pe 8 momente ale respirației, densitatea generatorului **48 din 2500 de chunk-uri** (≈1,9%, țintit 2%), un dubios chiar născut în cele 49 de chunk-uri din jurul player-ului, plus `main.tscn` rulat headless fără nicio eroare.

---

## Session log — 2026-08-12 (Alba-Neagra: meniul, adus la simetrie)

**Cerut de Răzvan:** „e puțin asimetric meniul în Alba Neagra, fă-l bun profesionist."

**Ce era strâmb, de fapt.** Panourile laterale erau de lățimi diferite (210 în stânga, 280 în dreapta), iar scena stătea între ele cu spații egale de 24 px. Marginile față de ecran ieșeau egale (26 și 26), deci la prima vedere părea în regulă — dar **mijlocul scenei cădea pe 541, nu pe 576**, adică cu 35 px la stânga față de titlul care stă exact deasupra ei. Așa ceva se vede ca „ceva nu e drept" fără să-ți dai seama ce, fiindcă ochiul compară omul cu paharele cu textul de deasupra lui, nu cu rama de afară. Pe deasupra, panoul din stânga era o cutie mică plutind la jumătatea înălțimii, față de o coloană întreagă în dreapta: toată greutatea desenului cădea într-o parte.

**Caroiajul nou** (scris în comentariul din `_layout`, cu suma alături, ca să nu se strice la următoarea reglare):
`26 ┃ panou 262 ┃ 24 ┃ SCENĂ 528 ┃ 24 ┃ panou 262 ┃ 26 = 1152`. Panourile sunt acum **egale și amândouă pe toată înălțimea** (112 → 624), iar mijlocul scenei cade fix pe 576, pe aceeași axă cu titlul, cu linia cu romb și cu rândul de stare. Mărirea artei rămâne ×4 — e limitată de înălțimea scenei, deci lățimea schimbată n-o atinge.

**Cele două panouri au aceleași benzi pe înălțime**, ca să se citească drept o pereche: capul la 132 („ROUND 1" ↔ „PRIZE LADDER", aliniate la același mijloc), conținutul 164–388 (indiciul/premiul ↔ cele 5 trepte), o **linie despărțitoare la 398 în amândouă**, apoi josul 412–566 (avertismentul de risc ↔ butoanele). Linia e nouă (`_despartitor`) și e acolo ca jumătatea de jos a panourilor să arate a bandă cu rost, nu a loc rămas gol.

**O gaură nouă, astupată.** Într-un panou înalt s-a văzut ce nu se vedea în cel mic: după prima ghicire reușită, banda din mijloc rămânea **complet goală** (indiciul „Two in a row…" se șterge de îndată ce ai un premiu de luat). Acum scrie **„One more for RARE"** — cheie nouă în `i18n.gd`, cu numele rarității tradus separat și scris cu majuscule, exact ca pe butonul „TAKE UNCOMMON" de vizavi. ⚠️ La șirul de 6 nu mai există treaptă următoare: `PREMII[7]` ar crăpa, deci textul e păzit de un `PREMII.has(_sir + 1)`.

**Verificat** cu o scenă de test care instanțiază meniul și fotografiază șase stări (intro / de ales / câștigat / șir maxim / pierdut / premiul cu nume lung în panou) — inclusiv cazul care ar fi crăpat. `tool_check_i18n` ✔ 267 chei × 8 limbi.

---

## Session log — 2026-08-12 (Alba-Neagra: titlul, panoul din stânga, dificultatea)

**Cerut de Răzvan:** „partea din stânga de la Alba Neagra e prea mare doar pentru un scris și o imagine de la item când câștigi. Și sus nu vreau să scrie Alba Neagra, vreau să scrie doar *Where is the ball?*. Și fă-l să fie mai greu puțin."

**1. Titlul.** `„A L B A   N E A G R A"` → `"Where is the ball?"`, cheie care exista deja în `i18n.gd`. Numele jocului de stradă românesc nu se traduce, deci în celelalte 8 limbi titlul era o formulă goală; acum e întrebarea jocului și se traduce peste tot. ⚠️ Scris **fără spații între litere** — cu ele nu s-ar mai potrivi cheia din tabel și titlul ar rămâne englezesc în toate limbile.

Întrebarea era însă scrisă și pe rândul de stare de sub titlu, cât alegi — ar fi apărut de două ori, una sub alta. Acolo scrie acum ce ai de **făcut**: cheie nouă `"Pick a cup"`, cu cele 8 traduceri (vocabularul e cel deja folosit: *Becher / vaso / стакан / gobelet / カップ / kubek / bardak*).

**2. Panoul din stânga: 280×512 → 210×242**, centrat pe înălțimea scenei. Trucul care l-a făcut atât de mic: **premiul se desenează PESTE indiciu și peste avertismentul de risc**, în același loc din panou. Cele două se văd doar cât joci, premiul apare abia la final — `_ia_premiul` ajunge în starea „gata", unde ambele sunt oricum goale — deci nu sunt niciodată pe ecran în același timp. `_actualizeaza` le și ascunde explicit, ca aspectul să nu depindă de asta. Așa panoul e cât conținutul lui, nu cât suma lucrurilor care s-ar putea nimeri în el.

Restul, ca urmare: scrisul cu un punct mai mic (24/14/13), numele premiului cu `autowrap` (în 174 px „Cursed Sword Mastery" nu mai încape pe un rând), iar scena a luat lățimea rămasă: `Rect2(260, 112, 562, 512)`, cu același spațiu de 24 px față de ambele panouri. ⚠️ Scena **nu** e centrată pe ecran și nici nu trebuie: panourile nu sunt la fel de late. Centrate rămân titlul și linia de sub el, care se uită la toată rama. Mărirea artei rămâne ×4 — e limitată de înălțimea scenei, nu de lățime, deci lățimea în plus n-o schimbă.

**3. Mai greu:** 4 + 2 mutări pe rundă → **5 + 3**, durata unei mutări 0,42→0,17 s → **0,36→0,14 s**, iar bila stă descoperită la început 0,75 → **0,5 s** (era timp de gândit, nu de văzut). Runda 1: 5 × 0,36 s (amestecul măsurat: 3,12 s cap-coadă). Runda 6: 20 × 0,16 s. ⚠️ Sub ~0,12 s pe mutare jocul nu devine mai greu, devine **imposibil**: paharele sar dintr-un loc în altul fără să apuci să le vezi drumul, deci rămâne ghicit din trei. Dacă vrei și mai greu, adaugă mutări, nu viteză.

**Verificat:** patru capturi din meniul real (intro / ales / premiu câștigat / totul în germană — limba cu scrisul cel mai lat, încape), o rundă jucată cap-coadă, `tool_check_i18n` ✔ (266 chei).

---

## Session log — 2026-08-12 (Alba-Neagra: paharele, decupate ca lumea)

**Reclamat de Răzvan:** „paharele sunt decupate prost. Vreau să fie decupate fix cu stroke-ul negru pe care îl au deja. Copiază paharul din stânga și dă copy-paste în celelalte locuri."

Prima variantă de decupaj (log-ul de mai jos) pornea de la „ce e aproape alb e pahar" și cârpea restul cu umplere de găuri. **Ideea era greșită din start.** Paharul e desenat cu un **contur închis**, deci silueta lui nu se definește după culoare, ci geometric:

1. pornim dintr-un pixel aproape alb (numai paharele au așa ceva pe tăblie);
2. umplem în lături tot ce **nu e contur** — ne oprim singuri în linia neagră, indiferent cât de închise sunt umbrele dinăuntru;
3. adăugăm conturul: pixelii închiși **lipiți** de interior.

⚠️ **Pragul de contur trebuie să fie 0.35, nu 0.20.** Conturul paharului NU e negru uniform: pe stânga (rândul 90 din poză) e un gri de ~0,25. Cu 0,20 umplerea se scurgea prin el pe toată masa — de aici veneau decupajele stricate. Tăblia e ≥ 0,5, deci 0,35 desparte curat.

⚠️ **Conturul se ia cu UN SINGUR pixel în jur, nu urmărind linia neagră.** Sus, conturul paharului e lipit de muchia neagră a mesei, care traversează toată poza; dacă urmărești linia, decupezi jumătate de masă odată cu paharul. Crestăturile de un pixel (unde conturul e desenat pe doi pixeli, unul negru și unul gri) se astupă separat, cu o regulă geometrică: un pixel închis înconjurat pe **3 din 4** laturi de mască e tot contur. Cu 2 laturi ar prinde din nou muchia mesei.

⚠️ **La ștersul paharelor de pe masă, sursele de petic trebuie să excludă TOATE paharele deodată.** Peticul copie material din pixelii de pe același rând, în oglindă; dacă nu marchezi întâi cele trei pahare (plus un pixel de franj în jur) ca „sursă interzisă", paharul din stânga se peticește cu pixeli din paharul din mijloc și pe masă rămân cioburi negre. Și se peticește **pe lățimea măștii pe rândul ăla**, nu pe toată caseta — sus paharul e îngust și are mâinile omului lângă el.

**Rezultat:** `cup.png` e acum 14×16, o siluetă închisă cu contur negru pe tot conturul, iar meniul desenează **același pahar** pe toate cele trei locuri (cum a cerut). Constante noi în `alba_menu.gd`: `SLOT_X [45, 64, 83]`, `CUP_W 14`, `TALPA 96`.

**Și un reglaj găsit uitându-mă la rezultat:** ridicarea paharului 16 → **10**. Bila are 9 px, deci 10 o descoperă toată, iar talpa paharului rămâne pe tăblie. La 16 paharul urca cu totul în mâinile omului și părea că-l ține în palme, nu că-l ridică de pe masă.

**Verificat:** poza de control (original | scenă peticită cu paharul pus de 3 ori | masa goală, toate mărite ×6) + trei capturi din meniul real (așezate / ridicate / bila la vedere), `tool_check_i18n` ✔.

---

## Session log — 2026-08-12 (meniul Alba-Neagra, refăcut de la zero)

**Cerut de Răzvan:** „ți-am șters aproape tot de la Alba Neagra în afară de obiectul principal. Când începi jocu vreau să fie o variantă zoomed in de la poza Alba Neagra. Taie tu cups și fă animația. Fă meniul să pară că e făcut de un studio mare care face jocuri constant și arată foarte profesionist. Vreau să fie wow. Să fie premium meniul. Folosește elemente de la Border EGT."

**1. Arta.** Din folder rămăsese doar `Alba Neagra.png` (128×128, omul din lume). Meniul arată acum ACEEAȘI poză, mărită de 4 ori. `tool_alba_assets.gd` a fost rescris: nu mai taie din poza mare a mesei (ștearsă), ci din poza omului, și scoate `scene.png` (omul cu masa, fără pahare) + `cup.png` (un pahar, 13×16). Tipărește la final cifrele pentru `alba_menu.gd` (`SLOT_X`, `CUP_W/H`, talpa), ca să nu le mai măsoare nimeni de mână.

⚠️ **Decupajul descris aici (prag de „aproape alb" + umplere de găuri) a fost ÎNLOCUIT** — vezi log-ul de mai sus, „paharele, decupate ca lumea". Ce rămâne valabil de aici:
- Paharul are pe el umbre de **exact aceeași culoare ca tăblia** (155), deci orice prag pe culoare îl taie ciuruit. De asta silueta se ia geometric, nu după cât e de deschis.
- Verificarea care chiar prinde greșelile: **pui paharul decupat înapoi pe scena peticită, în cele trei locuri, și compari cu originalul.** Un pahar izolat pe fundal gri arată oricum ciudat și nu-ți spune nimic.

**2. Meniul.** Rescris complet, în trei coloane pe un plan fix de 1152×648 (`PLAN` + `_pune`, deci layout-ul arată la fel la orice rezoluție):
- **stânga** — runda („READY" înainte de start), indiciul, avertismentul de dificultate, premiul câștigat;
- **centru** — scena: poza mărită ×4 într-o ramă bogată, cu un reflector cald deasupra mesei, umbre sub pahare care se micșorează când paharul se ridică, și zonele de click peste cele trei locuri;
- **dreapta** — scara de premii (5 plăcuțe, cea următoare pulsează, cele luate se umplu cu culoarea rarității) și butoanele.
- Ramele sunt 5 celule diferite din `Border EGT.png` (`CH_PANOU`, `CH_SCENA`, `CH_PANEL`, `CH_BUTON`, `CH_PLACA`), butoanele au `StyleBoxTexture` din aceeași planșă.

⚠️ **Celulele din `Border EGT.png` NU au mijlocul transparent**, au un bleumarin închis. O ramă pusă PESTE ceva trebuie să aibă `draw_center = false`, altfel acoperă complet ce e dedesubt — prima versiune a ieșit cu scena goală, deși poza era încărcată și așezată corect.

⚠️ **O etichetă cu autowrap NU se așază cu `size`.** Își calculează înălțimea minimă din lățimea pe care o are în acel moment, iar înainte de prima așezare lățimea e 0 → „un cuvânt pe rând" → minim 439 px, care rămâne agățat de ea pentru totdeauna. Textul ajungea tocmai în mijlocul panoului. Soluția: eticheta stă într-un `Control` gol, ancorată pe tot cuprinsul lui (`_eticheta_rupta`).

**3. Reglaje găsite rulând, nu ghicite:** ridicarea paharului 26 → 16 px de artă (ajunsă apoi la **10**, vezi log-ul de mai sus), arcul 20 → **11**, umbrele de sub pahare de la alpha 0,85 la **0,42** (erau trei pete cenușii pe masă).

**Verificat:** patru capturi din joc (intro / bila la vedere / amestec / câștig), `tool_check_i18n` ✔ (265 chei × 8 limbi; chei noi: „READY", „PRIZE LADDER"; titlul scris cu spații între litere e trecut în `IGNORATE`) și o pornire de `main.tscn` fără erori de script.

---

## Session log — 2026-08-12 (de ce hitbox-ul din editor nu semăna cu cel din joc)

**Reclamat de Răzvan:** „Collision shape-ul din Godot nu arată ca cel din joc… încercam să le schimb și nu se schimbă nimic" — la Alba Neagra și la EGT.

**Cauza (verificată rulând cu `--debug-collisions`, nu din citit):** nu există două forme. Există UNA, dar `_ready()` din `alba.gd` și `egt.gd` mută **arta** sub ea la rulare: `spr.scale = art_scale` (1.6) și `_aseaza_pe_origine()` care recalculează `offset.y` ca talpa să cadă la `ACOPERIRE_JOS = 74px` sub origine (trucul de Y-sort). `CollisionShape2D` nu e atins niciodată. În editor sprite-ul stătea la `scale = 1, offset = 0` — adică cu 60% mai mic și mai sus decât în joc. Potriveai cutia după o imagine care în joc arată altfel.

**Ce am făcut:** am scris ÎN SCENE exact valorile pe care scriptul le pune oricum la rulare — `alba.tscn`: `scale = 1.6`, `offset.y = -13.75`; `egt.tscn`: `scale = 1.6`, `offset.y = -7.75`. Jocul nu le citește (le recalculează), deci **la rulare nu se schimbă absolut nimic** — verificat, „IN SCENA" și „LA RULARE" tipăresc aceleași cifre. Se schimbă doar ce vezi în editor: arta la mărimea adevărată, deci cutia se potrivește din prima.

⚠️ **Cifrele sunt duplicate, deci pot rămâne în urmă în tăcere.** Dacă umbli la `art_scale`, la `ACOPERIRE_JOS` sau schimbi poza, rescrie-le și în scenă (formula e `_aseaza_pe_origine`). Avertismentul e scris și în capul lui `alba.gd` și `egt.gd`.

**De reținut, două lucruri care par tot „hitbox" și nu sunt:**
- `CollisionShape2D` **doar blochează mersul**. Raza la care apare „Press E to interact" e `interact_range = 190` (distanță), pe nodul rădăcină.
- Copacii, pietrele și structurile din deșert **n-au scenă deloc** — corpul și forma se construiesc din cod (`props.gd:182`, `rocks.gd:203`, `desert_structures.gd:318`), iar hitbox-ul se reglează din butoanele nodului `Props` / `Rocks` din `main.tscn` (`hitbox_north/south/east/west`, `hitbox_factor`, `hitbox_vertical`, `sort_anchor`).

**Observat pe drum:** `egt.tscn` nu se modificase pe disc de pe 30 iulie, deși Răzvan zicea că a tot încercat să-i schimbe cutia — modificările alea nu ajunseseră niciodată în fișier (scenă nesalvată sau editat în tab-ul „Remote" al debugger-ului, unde valorile trăiesc doar cât rulează jocul). Și `harta/EGT/egt.png` e acum 128×128, nu 68×111 cum zicea comentariul din `egt.gd` — corectat.

---

## Session log — 2026-08-12 (Alba-Neagra: textul de avertisment de jos)

**Cerut de Răzvan:** „la alba neagra vreau sa scrie jos If you lose, gain +10% Difficulty".

Eticheta de risc (`_lbl_risc` din `alba_menu.gd`, stările `intro` și `alege`) zicea „Lose and the game gets 10% harder". Acum zice **„If you lose, gain +10% Difficulty"** — formulare care seamănă cu restul jocului, unde prețul e scris tot ca dificultate (`"Cost: +%d%% difficulty"` la trade-up / statuia Ender).

- `i18n.gd`: cheia veche `"Lose and the game gets %d%% harder"` a fost **înlocuită** cu `"If you lose, gain +%d%% Difficulty"` (toate cele 8 traduceri rescrise; la turcă procentul stă înaintea cifrei, deci `+%%%d zorluk`).
- Cheia `"The game got %d%% harder"` (mesajul de DUPĂ ce ai pierdut, starea `gata`) a rămas neatinsă: acolo e trecut, nu avertisment.
- `tr()` explicit se păstrează — textul are `%d`, deci fără el s-ar căuta cheia „…+10%…", care nu există.

**Verificat:** `tool_check_i18n.tscn` → „✔ TOTUL E TRADUS" (263 chei × 8 limbi) și o rulare cu poză a meniului: scrie „IF YOU LOSE, GAIN +10% DIFFICULTY" (fontul e all-caps).

---

## Session log — 2026-08-11 (ALBA NEAGRA: structură nouă + jocul cu paharele)

**Cerut de Răzvan:** un folder nou `harta/Alba Neagra` cu două poze — omul (structură nouă în lume, „dacă ai putea să îi dai și o animație mică de breathing") și masa (meniul care se deschide la E). „Vezi cum arată pe net Alba Neagra/Shell Game și vreau să îmi faci o animație la fel cu paharele. Pe runde și din ce în ce mai greu. Primești iteme din ce în ce mai bune dacă ghicești. 2 = common, 3 = uncommon și tot așa. Dacă vrei să continui și pierzi, nu primești nimic și îți crește dificultatea cu 10%. Poți să joci doar o singură dată per NPC."
**Întrebat și lămurit:** XP-ul din paranteză era despre **poza bilei** (folosim sfera de XP), nu o mecanică; scara se oprește la Legendary.

**Fișiere noi:** `alba.gd` + `alba.tscn` (omul), `albas.gd` (generatorul), `alba_menu.gd` (jocul), `tool_alba_assets.gd` + `.tscn` (tăiat arta). **Atinse:** `main.tscn`, `nether.gd`/`limbo.gd`/`ender.gd` (WORLD_NODES), `pause.gd`, `i18n.gd`, `tool_check_i18n.gd`.

**1. ⚠️ Arta a trebuit DESFĂCUTĂ ca să se poată mișca.** Poza mesei (1672×940) are cele trei pahare desenate pe ea; ca să le pot amesteca, unealta taie `cup.png` și le ȘTERGE din `table.png`. Peticul se copiază **rând cu rând, din masa de lângă fiecare pahar**, în oglindă:
   · paharele ies cu vârful DEASUPRA muchiei din spate, deci un dreptunghi umplut cu „culoarea medie a mesei" ar fi tăiat trei crestături în siluetă; deasupra muchiei, coloanele vecine sunt deja transparente, deci rândurile alea ies transparente singure, fără să știm noi unde e muchia;
   · prima variantă lua „fâșia cea mai lată" și a copiat COLȚUL rotunjit al mesei în mijlocul tăbliei — se vedea imediat pe poză. Acum ia din vecinătatea imediată, stânga pentru jumătatea stângă, dreapta pentru cea dreaptă (masa e în perspectivă: muchia e la altă înălțime la 300px distanță).
   · Decuparea paharului: flood fill din marginile casetei care se oprește ȘI în conturul negru, ȘI în transparent. Fără a doua condiție, floodul intra prin vârful paharului (acolo silueta n-are contur desenat — o desparte de fundal chiar negrul) și golea paharul: ieșise doar conturul.

**2. Respirația.** Un singur sprite ține și omul, și masa lui, deci nu pot mișca doar omul. Îl întind pe verticală cu 1,8% la 2,3s, cu TALPA ținută pe loc: un `Sprite2D` se scalează din centru, deci `offset.y` coboară în paralel cu exact `talpa × (k−1)/k`. Fără compensarea asta, masa intra în iarbă la fiecare inspirație.

**3. Regulile.** 2 ghiciri = Common, 3 = Uncommon, 4 = Rare, 5 = Epic, 6 = **Legendary și jocul se închide singur** (peste Legendary n-ai ce câștiga). Greșeală = nimic + `Difficulty.add_trade_penalty(0.10)` — același mecanism ca la statuia Ender, deci +10% pe viață, damage de contact, spawn ȘI viteză. Scara de premii e desenată sus, cu treapta următoare aprinsă: nu trebuie să ții minte tu unde ai ajuns.

**4. Omul se consumă la PRIMA RUNDĂ, nu la deschiderea meniului** — dacă doar te uiți și pleci, rămâne întreg. Locul lui se ține minte în generator (`marcheaza_folosit`, ca la cufere), altfel ar fi revenit întreg la fiecare descărcare de chunk și puteai juca la nesfârșit plimbându-te.

**5. ⚠️ Amestecul se CONSTRUIEȘTE dintr-o bucată, dar se JOACĂ pe parcurs.** Deci la construcție `_slot` e încă starea de la început și nu poți citi din el pozițiile schimbului al cincilea. Ține o copie „simulată" care înaintează odată cu construcția, iar la rulare `_schimba` face aceleași mutări pe `_slot`-ul adevărat. Fără asta, paharele ar fi sărit aiurea de la a doua mutare.

**6. ESC cu premiu în mână ÎL IA.** Ar fi crud să pierzi un Legendary câștigat fiindcă ai apăsat ESC. (Dacă n-ai ajuns la 2 ghiciri, ESC doar închide.)

**Reglaje de mărime, prinse pe poze:** bila 104 → 150 (ieșea cât o boabă de mazăre); ridicarea paharului **nu poate trece de 152** — la 230 paharul își scotea vârful din poza mesei și plutea peste titlu.

**Verificat rulând jocul adevărat:** omul apare în lume, se sortează corect cu player-ul și scrie „Press E to interact"; E deschide jocul și pune jocul pe pauză; două ghiciri fac butonul „TAKE COMMON"; luarea premiului bagă un item real în registru (0 → 1); o greșeală duce `trade_penalty` 1.00 → 1.10; iar generatorul întoarce **1 om înainte de consum și 0 după**, pe același chunk. `tool_check_i18n`: **263 chei × 8 limbi**.

---

## Session log — 2026-08-11 (Nether-ul te pedepsește dacă intri prea devreme)

**Cerut de Răzvan:** „vreau Nether-ul să fie greu în așa fel încât un player să nu poată intra imediat în portal, să trebuiască să stea în lumea normală măcar 2 minute. Ca și spawn-rate mă refer la inamicii din Nether."

**Atinse:** `nether.gd` (`INTRARE_MIN`, `SPAWN_PEDEAPSA`, `spawn_mult()`, valul de la intrare, avertismentul), `spawner.gd` (cere multiplicatorul), `difficulty.gd` (`spawn_mult_la(t)`), `i18n.gd` (2 chei).

**1. NU e ușă încuiată.** Portalul te lasă înăuntru oricând; ce se schimbă e cât de deasă e ploaia de inamici. Un gard făcut din dificultate, nu din cod care zice „nu poți" — asta a și cerut („să fie greu în așa fel încât...").

**2. Formula.** Rata de spawn primește un multiplicator care pleacă de la **×4 la secunda 0** și scade liniar la ×1 la **2:00**. Se socotește pe ceasul NETHER-ului (`_diff_time()`), nu pe clipa intrării, deci **pedeapsa se stinge singură dacă supraviețuiești înăuntru** (verificat: intrat la 0:00, după 2:00 petrecute acolo → ×1.00). Ai trecut proba, n-are rost să te mai apese tot drumul.

**3. ⚠️ Rampa singură lăsa o GAURĂ, prinsă la măsurătoare.** Rata de bază sare ×2 fix la 2:00 (`SPAWN_DOUBLE_AFTER`), așa că doar cu rampa liniară intrarea la **1:30 ieșea 2.48/s — mai ușoară decât cea la 2:00 (3.12/s)**, adică exact gaura pe care regula trebuia s-o astupe. Am adăugat o **podea**: Nether-ul nu e niciodată mai gol decât ar fi lumea la `INTRARE_MIN`. Pentru ea a trebuit `Difficulty.spawn_mult_la(t)` — aceeași formulă, evaluată într-un moment ales (`spawn_mult()` o cheamă acum cu `_mult_time()`, deci nu s-a schimbat nimic pentru ceilalți).

**Măsurat** (inamici/s în Nether, cu regulă / fără): 0:00 → 4.00/1.00 · 0:30 → 3.70/1.14 · 1:00 → 3.20/1.28 · 1:30 → 3.12/1.42 · 2:00 și după → neatins. Lumea normală: 3.12/s la 2:00, neschimbată.

**4. Valul de la intrare crește și el:** 25 de creaturi la 2:00, **~100 la 0:00**. Un multiplicator pe rată se simte abia peste zece secunde, când e prea târziu să te întorci; zidul care se strânge pe tine în clipa aterizării se simte imediat.

**5. Avertisment pe ecran**, la 2,6s după bannerul „THE NETHER": „YOU CAME TOO EARLY / The Nether is packed until 2:00". Întârzierea nu e de gust — `hud.announce` ÎNLOCUIEȘTE bannerul de dinainte, deci două anunțuri odată ar fi însemnat unul singur. Ora se scrie din constantă (`_mmss(INTRARE_MIN)`), deci textul urmează pragul dacă îl reglezi.

**6. ⚠️ Se pedepsește DOAR câți inamici apar, nu și cât de tari sunt.** Viața și viteza rămân pe `_diff_time()`. Dacă urcam ceasul de dificultate, urca și `xp_mult` — adică intratul devreme ar fi PLĂTIT mai bine, exact pe dos.

**Verificat rulând**: tabelul de mai sus măsurat pe șapte momente de intrare într-o rundă adevărată, stingerea pedepsei după 2 minute înăuntru, lumea normală neatinsă, plus poze cu zidul de creaturi la 0:00 și cu bannerul de avertisment. `tool_check_i18n`: **253 chei × 8 limbi**.
ℹ️ În poze player-ul secera valul în două secunde fiindcă **salvarea lui Răzvan are OP START pornit** (damage 100, 10 proiectile) — cifrele de spawn nu depind de asta, dar „cât de letal e" nu se poate judeca din pozele alea.

**Butoane de reglaj:** `INTRARE_MIN` (pragul, acum 2:00) și `SPAWN_PEDEAPSA` (cât de deși la secunda 0, acum ×4), amândouă sus în `nether.gd`.

---

## Session log — 2026-08-11 (CHOOSE WEAPON: armele în stânga, fișa lor în dreapta)

**Cerut de Răzvan:** „la choose weapon, vreau armele să fie în stânga și să scrie ce fac (ce abilități au — cum scrie și acum sub ele) în dreapta".

**Atinse:** `menu.gd` (`_build_weapon` rescris + fișa), `i18n.gd` (o cheie nouă: „AT START").

**1. Ce era.** Cele 5 arme una lângă alta, pe orizontală, cu numele (18px) și bonusul de nivel (13px) scrise dedesubt. Cinci coloane înguste de text mărunt — pagina cea mai aglomerată din meniu — și tot ce se putea afla despre o armă era acel rând de notă.

**2. Ce e acum.** Listă pe stânga (chenar de raritate + iconiță + nume, rânduri de 62px), fișă pe dreapta cu arma pe care stai.

**3. ⚠️ Cifrele din fișă se CITESC din `player.gd`, nu se scriu de mână.** `_arme_stats()` ia constanta `ARME` cu `get_script_constant_map()` și de acolo scoate damage-ul și intervalul (afișat ca `1/interval` în „x.xx/s", exact ca în panoul de level up). O copie în `menu.gd` ar fi rămas în urmă în tăcere la primul rebalans — capcană pe care fișierul o are deja scrisă la `WEAPONS` pentru textele de bonus.
Secțiunea se cheamă **„AT START"** fiindcă asta e: statusul cu care PORNEȘTE arma, fără magazinul permanent și fără itemele din rundă.

**4. Fișa urmărește mouse-ul (și focusul de tastatură), dar se întoarce la arma ALEASĂ când ieși de pe listă.** Fără întoarcere ar rămâne pe ultima armă peste care ai trecut din greșeală și n-ai mai ști ce ai ales de fapt.

**5. Fișa e o casetă desenată (piatră închisă, muchie de aramă), NU încă un chenar ornat** — pagina are deja o ramă în jur, iar două rame ornate una în alta se citesc ca una singură, groasă și murdară (aceeași regulă ca la cutia de inventar din cazinou).

**6. Bonusul de nivel n-a primit cap de secțiune.** Am pus întâi „EVERY LEVEL" deasupra lui și ieșea „EVERY LEVEL / +1% ATTACK SPEED **PER LEVEL**" — același lucru spus de două ori. Textul lui zice deja când se aplică.

**⚠️ Înălțimea.** Prima variantă (celulă 68, separare 8, iconița fișei 96, marginile 22) măsura **623 din 648** — încăpea, dar la limită. Acum: celulă 62, separare 6, iconiță 84, margini 18 → **585**. Dacă mai adaugi o armă a șasea, remăsoară: 5 rânduri intră comod, 6 nu mai sigur.

**Verificat rulând** (scena de test ștearsă după): fișa arată corect arma previzualizată (coasa: 24 / 1,05/s — exact cifrele din `ARME`), se întoarce la pistol când ies de pe listă, și pagina randată în **germană** („VERFLUCHTES SCHWERT" încape în rând). `tool_check_i18n`: **251 chei × 8 limbi**.
⚠️ Testul NU a apăsat pe nicio armă: `_on_weapon_chosen` scrie în `GameSettings.weapon_type`, iar aia ajunge în salvarea reală a lui Răzvan (vezi regula de sus despre teste și `GameSettings`). Codul acela n-a fost atins.

---

## Session log — 2026-08-11 (level up + pagina principală, „premium", pe Border EGT)

**Cerut de Răzvan:** „poți să faci meniul de upgrade-uri mai premium? Folosind Border EGT, și vreau și meniul principal să îl faci tot cu ăla. Îți alegi tu cum le pui și pe care. Dar vreau să arate de parcă e făcut de un studio mare de game dev. Foarte profesional și curat."

**Atinse:** `levelup.gd` (refăcut tot ce se vede), `menu.gd` (placa de sub butoanele paginii principale + verdele OP), `i18n.gd` (2 chei noi, una scoasă).

**1. Level up — rama.** Lemnul din `Menu.png` → chenarul de aramă, celula (2,0), aceeași unealtă (`_chenar`) ca la cazinou/statuie/meniu. Era ULTIMUL ecran rămas pe lemn. **De acum `Menu.png` nu mai e încărcat de niciun script** — din folderul `Upgrades/Menu UI/` se mai folosesc doar chenarele de raritate.

**2. Cele 3 opțiuni sunt CARTONAȘE**, fiecare în chenarul lui subțire (celula (1,2)). Un rând fără margini nu arată a lucru pe care poți da click. Hover-ul (și focusul de tastatură) aprinde rama din cenușă în aramă în 0,12s, plus numele în alb. **Highlight-ul vechi era un dreptunghi alb transparent** (10–18% alfa) — pe fundal aproape negru, invizibil.

**3. ⚠️ Numele itemului NU mai e colorat pe raritate.** Common e `#424B6D`, adică albastru închis pe fundal aproape negru: numele itemului era cel mai greu de citit lucru de pe ecran, exact la raritatea care apare cel mai des (40%). Acum: nume alb-os, descriere cenușie, iar **doar cuvântul rarității** poartă culoarea — și aia trasă 30% spre alb, din același motiv. Chenarul desenat rămâne culoarea adevărată.

**4. Titlul, spart în trei.** „LEVEL UP" mare + linia subțire + „Level 12" / „Choose one". Nivelul la care ai ajuns e o informație pe care ecranul nu ți-o dădea deloc. În plus, vechiul titlu-într-o-bucată („LEVEL UP!  Choose:") creștea urât în germană și rusă. Cheia veche a ieșit din `i18n.gd`, au intrat „LEVEL UP" și „Choose one"; nivelul refolosește „Level %d" de la Game Over.

**5. Panoul de STATS e un tabel:** aceeași ramă și **aceeași înălțime** ca panoul de alegeri (două panouri de înălțimi diferite arată a improvizație), dungi de 3% alb pe rândurile pare, iar **doar valoarea** ia verdele/roșul de schimbare. Cu numele colorat și el, o rundă bună făcea panoul un perete verde.

**6. ⚠️ Fundalul, 0.9 → 0.975.** La 0.94 se citeau prin el cronometrul din HUD (sus) și „LEVEL 1" (jos-stânga) — două texte fantomă peste meniu. Prins pe poză, nu în cod.

**7. Meniul principal: butoanele stau pe o PLACĂ de aramă.** Era ultimul ecran fără ramă, adică prima pagină pe care o vede oricine arăta a listă lipită peste o poză, în timp ce toate sub-paginile erau încadrate. **Marginile plăcii sunt mai strânse (34/26/24) decât cele standard (42/34/30)**: cu cele standard, logo-ul (240) + placa treceau de cei 648px ai ecranului de referință. Măsurat după: **594**.
⚠️ Transparența din intro se animează acum pe PLACĂ, nu pe lista de butoane — `modulate` se moștenește la copii, deci altfel rama ar fi stat vizibilă și goală tot intro-ul.

**8. Verdele de „OP pornit", muiat** (`#66FF80` → `#76B27C`): pe un ecran de aramă și piatră, butonul de test din colț sărea în ochi mai tare decât START.

**Verificat rulând** (scenele de test șterse după): ecranul de level up deschis **în jocul adevărat** (peste lume și HUD, cu jocul pe pauză), alegerea aplicată pe bune (registru 0 → 1, meniu închis, joc repornit), poză pe starea de hover, și amândouă ecranele randate în **germană** — nimic tăiat, nimic ieșit din ramă. Înălțimi cu `get_combined_minimum_size()`: main 594, weapon 437, settings 541, toate sub 648. `tool_check_i18n`: **250 chei × 8 limbi, tot tradus**.

**Neatins dinadins:** ecranul de Game Over și HUD-ul (n-au fost în cerere), iar verdele de SELECȚIE de la arme/limbi a rămas — ăla e chenarul de raritate din arta jocului, nu o culoare inventată de interfață.

---

## Session log — 2026-08-11 (cazinoul te BANEAZĂ după 3 câștiguri la rând)

**Cerut de Răzvan:** „vreau dacă playerul câștigă de 3 ori la rând la ruletă să nu îl mai lase tot run-ul să joace și să îi scrie «You've been banned for cheating»".

**Atinse:** `casino.gd` (ecranul 4 + numărătoarea), `egt.gd` (eticheta de deasupra aparatului), `i18n.gd` (3 chei noi), `tool_check_i18n.gd` (lista de fișiere verificate).

**1. Al treilea câștig se ÎNCASEAZĂ.** Statusul se dublează normal, bannerul „3 RED — YOU WIN!" rămâne `BAN_INTARZIERE` (1,7s) pe ecran și abia apoi intră ecranul de ban. Altfel banul ar arăta ca și cum jocul ți-a furat rotirea câștigătoare, nu ca urmarea ei.

**2. ⚠️ Șirul se numără pe RUNDĂ, nu pe vizită.** `Casino` e **un singur nod**, în `main.tscn`, care trăiește cât runda — deci nu poți strânge două câștiguri, să ieși din meniu și s-o iei de la capăt, și nici nu scapi mergând la alt EGT (toate aparatele deschid același nod, vezi `egt.gd::invoca`). O pierdere duce șirul la 0; banul, o dată căzut, NU se mai ia (verificat: a patra rotire, pierzătoare, a dus șirul la 0 și a lăsat `_banat = true`). Trade-up-ul n-are câștig/pierdere, deci nu intră la socoteală. La restart, `reload_current_scene()` reface nodul → tot curat.

**3. ⚠️ Blocarea stă într-un SINGUR loc: `_arata_pagina()`.** Cât ești banat, orice pagină cerută devine `"ban"`. Așa nu poate fi ocolită de niciunul din cele trei drumuri care duc la pagini: `open()` (E pe aparat), ESC-ul de pe masă și butoanele „Back". Peste asta, `SPIN`, punerea jetonului și `TRADE UP` refuză și ele. Dacă aș fi pus verificarea doar în fiecare din ele, prima cale nouă adăugată peste un an ar fi fost o portiță.

**4. ⚠️ `egt.gd::poate_invoca()` rămâne `true` și după ban** — aceeași logică ca la cufărul fără cheie (`chest.gd`): pe `false`, `interact_ui.gd` nu mai alege deloc aparatul ca țintă, deci n-ar mai scrie NIMIC deasupra lui și ar arăta a decor. Așa rămâne țintă și scrie de ce nu mai merge, prin `eticheta()`. Textul apare pe **toate** aparatele din lume, fiindcă banul e al cazinoului, nu al mașinii la care ai jucat.

**5. Textul cu cifră se pune la AFIȘARE, nu la construcție.** „3 wins in a row" e asamblat (`tr("%d wins in a row") % CASTIGURI_BAN`), deci nu se re-traduce singur când schimbi limba din Settings — iar panoul se construiește o dată, la pornirea rundei. Pus în `_arata_pagina`, e mereu în limba de acum.

**6. `casino.gd` și `egt.gd` au intrat în `FISIERE_UI` din `tool_check_i18n.gd`.** Nu erau acolo deloc, deși `casino.gd` desenează tot meniul cazinoului și avea deja `tr(...)`-uri — adică traducerile lui nu erau verificate de nimeni. Acum: **249 chei × 8 limbi, tot tradus**.

**Verificat rulând** (scena de test ștearsă după): trei „câștiguri" simulate prin `_arata_rezultat` → șir 1 → 2 → 3, `_banat` pe true la al treilea, pagina trece pe `ban` după întârziere cu SPIN stins, a patra rotire (pierzătoare) resetează șirul dar nu banul, `e_banat()` true, aparatul instanțiat din `egt.tscn` întoarce eticheta corectă și `invoca()` nu mai deschide nimic. Plus o poză a ecranului de ban (titlu roșu pe două rânduri în chenarul de aramă, „3 WINS IN A ROW", „THE CASINO IS CLOSED FOR THE REST OF THE RUN", buton „Leave").

**Butoane de reglaj:** `CASTIGURI_BAN` (câte câștiguri la rând) și `BAN_INTARZIERE` (cât stă rezultatul pe ecran înainte de ban), amândouă sus în `casino.gd`.

---

## Session log — 2026-08-07 (tot meniul jocului, în chenarele de aramă)

**Cerut de Răzvan:** „fă tot meniul de la joc PROFESIONIST cum ai mai făcut și până acum, să arate ca un joc făcut de un studio profesional. Folosește Border EGT."

**Atinse:** `menu.gd` (meniul principal + toate sub-paginile), `settings_ui.gd` (blocul de setări, folosit ȘI în pauză), `pause.gd` (meniul de pauză). Acum **tot jocul are o singură paletă** — aceeași aramă ca EGT-ul și statuia din Ender.

**1. Rama.** `Upgrades/Menu UI/Menu.png` (lemn beige-auriu) → celula (2,0) din `harta/EGT/Border EGT.png`. Lemnul era singurul lucru de pe ecran care nu ținea de nicio paletă: beige cald peste o pădure de noapte albastră, lângă un logo de aramă. Rămâne `PanelContainer` + `StyleBoxTexture`, **nu** `NinePatchRect`: paginile au înălțimi diferite (LEADERBOARD crește cu scorurile), iar NinePatch-ul nu se strânge pe copii. Marginile de conținut au scăzut de la 72/58/56 la **42/34/30** — ornamentul de aramă e mult mai subțire decât cel de lemn, iar cei ~60px câștigați i-au prins bine paginii SETTINGS, care abia încăpea (600 → **541** din 648).

**2. ⚠️ Colțurile rotunjite, 10 → 2.** Ăsta a fost cel mai mare semn de „interfață făcută repede", și e într-un singur loc: `_sb()`. **Nicăieri în arta jocului (pixel art) nu există o rază de zece pixeli** — deci butoanele arătau a pagină web lipită peste un joc. Aceeași schimbare în toate trei fișierele.

**3. ⚠️ Butoanele: deosebirea se face pe MUCHIE, nu pe umplutură.** Stilul vechi construia hover/pressed cu `BTN_MAIN.lightened(0.10/0.20)`, ceea ce mergea pe maro deschis. Pe **piatră aproape neagră** (26,22,28) o umplutură cu 10% mai deschisă nu se vede deloc. Deci acum starea și importanța se citesc din culoarea muchiei: repaus = aramă stinsă, hover = aramă, apăsat/principal = aramă aprinsă. La fel la taburile din Settings (`_stil_tab`), unde `darkened(0.18)` pe negru era invizibil.

**4. Sliderele de volum.** Erau cele CENUȘII implicite ale motorului — singurul lucru din tot meniul care arăta a Godot. Godot le desenează din trei bucăți: `slider` (șanțul), `grabber_area` (partea plină) și **iconița** `grabber` (butonul). Primele două sunt StyleBox-uri; a treia are nevoie de o textură, așa că butonul e un pătrat de aramă de 12×12 desenat din cod (`_grabber`).

**5. ⚠️ Clasamentul, pe COLOANE.** Tot rândul era un SINGUR text centrat (`"%d.   %d:%02d   ·   Level %d   ·   %d kills"`), deci nimic nu se alinia: „Level 4" și „Level 41" cădeau la x-uri diferite. Acum fiecare coloană e o etichetă, cu **`SIZE_EXPAND_FILL` + proporție fixă, nu lățimi în pixeli** — cu pixeli, rusa („убийств: 3128") ar fi ieșit din coloana ei; cu proporții, toate rândurile primesc aceleași lățimi din același total, în orice limbă. `clip_text` e plasa de siguranță. Plus primele trei locuri colorate (aramă aprinsă / alb-os / aramă, restul cenușiu): un top în care toate rândurile sunt la fel de albe e o listă, nu un clasament.
⚠️ Cheia compusă din `i18n.gd` a fost înlocuită cu `"%d kills"` (`"Level %d"` exista deja, de la Game Over).

**6. Meniul de pauză a primit ȘI el rama.** Nu era în cerere direct, dar el ÎNCADREAZĂ blocul `SettingsUI`: fără schimbare ar fi rămas cu butoane maro rotunjite în jurul unui bloc de aramă. Butoanele lui pluteau înainte pe un ecran întunecat, fără nimic în jur — mergea, dar arăta a listă de depanare.

**Verificat rulând**, cu poze pe fiecare pagină și înălțimea măsurată (`get_combined_minimum_size`) în **en / de / tr**: main 556, weapon 437, character 276, leaderboard cu 10 scoruri **491**, settings 541, language 570, opstart 414 — toate sub cele **648** ale ecranului de bază. Clasamentul randat și în **rusă** (cele mai lungi coloane): aliniat, nimic tăiat. Meniul de pauză, ambele pagini. `tool_check_i18n`: **246 chei × 8 limbi, tot tradus**.
⚠️ Testul a umblat la `GameSettings.scores` doar în RAM ca să aibă ce afișa — și verifică singur, la final, că `scores.save` n-a fost atins (a ieșit `true`).

**Rămas neatins dinadins:** `Menu.png` e încă folosit de `levelup.gd`, deci arta rămâne pe disc. Ecranul de level up, cel de Game Over și HUD-ul au stilul lor și n-au fost în cerere.

---

## Session log — 2026-08-07 (SWAT — al treilea polițist, cel gras)

**Cerut de Răzvan:** „ți-am băgat un nou enemy în homeless directii, vezi folderul Swat. Apare când mai are player-ul 6:00 în lumea normală și e la fel de rapid ca Police Skinny doar că are 50% din ce HP are Garda la momentul ăla exact. Vreau să fie așa tanky."

**⚠️ „Mai are 6:00" = `Difficulty.time >= 240`, nu 360.** Cronometrul de pe ecran **SCADE** de la 10:00 (`time_left() = RUN_LENGTH - time`), deci „mai are 6:00" înseamnă 4:00 SCURSE. E genul de cifră care ar fi trecut neobservată în cod și ar fi scos inamicul cu două minute mai devreme.

**⚠️ Cum se ține promisiunea „50% din Garda ÎN MOMENTUL ĂLA".** Nu se calculează nimic la rulare: `garda.gd::_ready` face `max_hp = int(300 * Difficulty.enemy_hp_mult())`, iar `enemy.gd::_ready` face `max_hp = int(max_hp * enemy_hp_mult() * power_mult)` — **același multiplicator**. Deci `max_hp = 150` în scenă dă exact 1/2 în ORICE secundă a rundei, nu doar la 6:00. Verificat pe patru momente: raport 0.500 la t=240, 400, 600 și 700 (adică și în Final Swarm, unde viața se dublează la fiecare 45s).

**⚠️ SWAT-ul e scos din îngroșarea de după Nether** (`spawner.gd`, `escaped_power_mult = 2`), deși e tot polițist ca Skinny. Cu ea ar fi ajuns **100%** din viața Gărzii — un boss din întâmplare, și numai pe rundele în care ai trecut prin Nether. Promisiunea trebuie să fie adevărată mereu, deci îngroșarea se oprește la Skinny.

**Arta:** 8 GIF-uri `Idle_running-6-frames_<dir> (1).gif`, 116×116, 6 cadre. Sufixul „ (1)" (de la o descărcare dublă) trebuia scos întâi — `tool_taie_gifuri.ps1` ia direcția din COADA numelui, deci ar fi ieșit `east (1)`. Apoi tăiate normal în 48 de PNG-uri în `homeless directii/Swat/frames/` + `--headless --import`. Toate 8 direcțiile sunt desenate (verificat cu md5: 8 fișiere diferite), nimic de oglindit.

**Mărimea, măsurată nu ghicită:** silueta opacă din `run_south_0` e 31×52 px (față de 33×58 la Skinny, pe pânză de 128). Ca să iasă **la fel de înalt pe ecran ca Skinny** (58 × 1.8 = 104): `scale = 2.0` → 52 × 2 = 104. `stop_dist = 46` = jumătate din lățimea desenată (31 × 2) + jumătatea player-ului (15). Plafonul dur rămâne 54 (`contact_range` 60 − `STOP_MARGINE` 6).

**Restul statelor:** `speed = 160` și `frames_fps = 14` — identice cu Skinny, cum s-a cerut; `damage_mult = 1.3`, tot ca el.

**`xp_drop_mult = 3.0` — judecata mea, nu ceruta lui.** Un inamic cu de 5 ori viața lui Skinny care lasă exact cât el e timp pierdut curat: îl tai de cinci ori mai mult pentru aceeași gemă. 3 e conservator (sub raportul de viață). **Nu-l vrea? `xp_drop_mult` din `enemy_swat.tscn`, pe 1.0.**

**Spawn-ul:** `swat_after = 240` + `swat_share = 0.20`, întrebat ÎNAINTEA lui Skinny în `_politist()` — deci Skinny ia felia lui din ce rămâne (același tipar ca Nether/Ender). Ținut mic dinadins: la 0.35 (cât are Skinny) jumătate din runda de după minutul 4 s-ar transforma în tocat buști. Verificat cu 4000 de trageri la zar pe fiecare moment: **0% la t=120 și t=239**, 19–20% la t=241 și t=400, cu Skinny scăzut de la 35% la ~28% (35% din restul) — adică numărul TOTAL de inamici nu s-a schimbat, doar cine sunt.

**Rămas neatins dinadins:** hoarda monumentului (`monument.gd::FELURI`) n-a primit SWAT. E „random din toate dimensiunile", dar acolo toți primesc ×3 viteză și ×3 damage — un tanc de 5× viață în plus e o schimbare de echilibru pe care n-a cerut-o. Se adaugă cu **un rând** dacă vrea.

**Verificat rulând:** cele 48 de cadre randate în grilă (8 direcții × 6, orientări corecte — spatele cu rucsacul la `north`, ochelarii portocalii la `south`, diagonalele la fel), fundal transparent, fără mânjeli de la GIF; niciun avertisment „lipsesc cadre" la instanțiere prin `enemy.gd`; și o poză cu cei trei polițiști unul lângă altul la t=240 — **HP 126 / 190 / 635**, viteze 137 / 182 / 182.

---

## Session log — 2026-08-07 (căsuțele contractului: egale, pătrate, și se pot goli înapoi)

**Cerut de Răzvan:** „arată urât astea 4 căsuțe. În primul rând nu sunt egale cu al 4-lea primele 3. Iar nu intră bine în căsuță. Vreau să ai și opțiunea să apeși pe iteme din nou ca să le scoți din căsuță." (+ captura din `debugging/`)

**1. De ce ieșeau dreptunghiulare.** Sloturile sunt copii de `HBoxContainer`, iar acesta **întinde pe verticală** tot ce n-are alt `size_flags_vertical`. Coloana premiului e mai înaltă (cutie + două etichete sub ea), deci rândul avea ~136px și cele 3 căsuțe de 92 se lungeau exact până acolo. Leacul: `SIZE_SHRINK_BEGIN` — le lasă pătrate ȘI le lipește de marginea de sus, la fel ca la cutia premiului. Săgeata a primit `custom_minimum_size.y = SLOT_LAT` + `SHRINK_BEGIN`, ca să stea la mijlocul RÂNDULUI DE CĂSUȚE, nu al coloanei premiului.

**2. De ce nu intra itemul bine în căsuță.** Chenarul de raritate era pus cu offset-uri ghicite (9 și 11), dar rama desenată e de altă grosime la fiecare celulă. **Măsurată din planșă**, nu ghicită (scanare de la centru spre margini după prima schimbare de culoare): celula (1,2) are **6px** de ramă, (3,2) are **8px**, ×`ZOOM` → 12 și 16. Acum:
- `SLOT_LAT = 116` — **aceeași latură la toate patru**;
- `CONTINUT = SLOT_LAT - 2*RAMA_PREMIU = 84` — chenarul de raritate e la fel de mare peste tot, adică exact cât încape în cea mai strâmtă dintre rame. La sloturi rămân 4px de joc de fiecare parte, dar acolo e fundalul închis al ramei (#201E26), aceeași culoare — nu se vede.
- iconița: `CONTINUT - 2*ICON_MARGINE`, cu `ICON_MARGINE = 11` (~15%, cât ține rama pictată a chenarului de raritate, ca în inventar).

**⚠️ A doua rundă, tot atunci: „fac overlap cu celălalt border".** Prima variantă avea `CONTINUT = SLOT_LAT - 2*RAMA_PREMIU`, adică chenarul de raritate umplea EXACT golul ramei de aramă și se lipea de muchia ei interioară — cele două rame desenate se citeau ca una singură, groasă și murdară. Leacul e `JOC_CHENAR = 7`: **două rame au nevoie de aer între ele ca să se vadă că-s două.** `CONTINUT` a scăzut de la 84 la 70, `ICON_MARGINE` de la 13 la 11, „?"-ul din cutia premiului de la 50 la 38 (umplea chenarul micșorat), iar „X"-ul de scoatere se aliniază acum cu colțul CONȚINUTULUI, `(SLOT_LAT - CONTINUT) / 2`, nu cu al ramei — altfel ar fi plutit în golul proaspăt făcut. Inventarul de jos n-a fost atins: acolo nu există a doua ramă peste care să se calce.

**3. Scoaterea din contract.** Mergea deja (al doilea click pe iconița din inventar), dar la `modulate.a = 0.22` itemul ales arăta MORT și nimeni nu ghicea că se poate apăsa. Acum:
- itemul ales stă la **0.4**, iar stingerea se pune pe ARTĂ (border + icon), nu pe buton — `modulate` se moștenește la copii, deci un „X" pe un buton la 0.4 ar fi fost la fel de greu de văzut ca itemul de sub el;
- **căsuțele au devenit butoane**: click pe una plină scoate itemul (`_scoate_slot`). Goală, e stinsă;
- semn „X" în colț, la ambele capete. **„X" simplu, nu „✕"** — fontul e pixel art și un pătrat gol în locul semnului ar arăta a bug. **Mereu vizibil, nu la hover**: jocul e și pe Android, unde hover nu există;
- în timpul tragerii (`_rula`) căsuțele sunt stinse și fără „X": contractul e deja bătut în cuie, itemele au plecat din registru.

**4. Gaura de sub inventar.** `ScrollContainer` are `SIZE_EXPAND_FILL`, deci înghite toată înălțimea rămasă; cu un singur rând de iteme dedesubt rămânea gol. Acum stă într-o **casetă desenată** (`PanelContainer` cu fund închis + muchie de aramă stinsă), deci golul se citește ca „rafturi goale de inventar", nu ca o gaură.

**`PANOU_IT_H` 566 → 612**, fiindcă și căsuțele au crescut. Cifra e **măsurată**, nu ghicită: `vbox.get_combined_minimum_size().y` după o tragere adevărată, în turcă, cu 30 de iteme → 551 + 56 de marjă = 607. Numele premiului are rezervată din start înălțimea a **două rânduri** (`custom_minimum_size.y = 44`) și e plafonat la `max_lines_visible = 2`: altfel apărea abia la aterizare și împingea tot ce e sub el peste chenar.

**Verificat rulând** (player REAL, nu fals, ca să treacă și prin `da_item`): 30 de iteme în turcă → 3 rare → tragere → **Tuhaf Karışım (Destansı)**, registru 30 → 28, `trade_penalty` 1.00 → 1.10, nimic peste chenar; `_scoate_slot(1)` scoate din mijloc și restul se string la stânga; al doilea click pe iconițe golește contractul și deblochează raritatea; în timpul tragerii 3/3 căsuțe stinse și fără „X", iar `_scoate_slot` nu face nimic. `tool_check_i18n`: **246 de chei × 8 limbi**, tot tradus (cheie nouă: „Click to take it out", care se lipește după numele itemului în tooltip).

---

## Session log — 2026-08-07 (EGT: TRADE-UP CONTRACT + tot cazinoul în chenarele de aramă)

**Cerut de Răzvan:** „Adaugă la EGT și partea de gamble your items. Ți-am pus și un border ca să poți să faci tot meniul super profesional ca un joc cu 1 milion de copii vândute (Border EGT). La Gamble Your Items vreau să fie ca un trade-up de CS:GO — iei 3 iteme de le ai și poți să le transformi într-un item cu o calitate mai mare (gen uncommon → rare) și nu vezi ce îți pică până faci trade-up-ul."

**Ecranul 3 din `casino.gd`, „TRADE-UP CONTRACT".** Pui 3 iteme de ACEEAȘI raritate (`TU_CATE`) și primești unul cu o treaptă mai sus. Regulile:
- Prima alegere BLOCHEAZĂ raritatea — celelalte se sting singure în inventar. Regula se vede pe ecran, nu doar în cod (același principiu ca `ButtonGroup`-ul de la ruletă).
- **Legendary nu poate fi urcat**: `raritate_mai_sus` l-ar da tot Legendary, deci ai schimba 3 pe 1 în pierdere curată. Itemele legendare apar în listă, dar stinse.
- **Cutia premiului arată RARITATEA, nu itemul.** Raritatea o hotărăști tu prin ce bagi, deci a o ascunde ar fi minciună, nu suspans. Itemul se vede abia după tragere.
- **Premiul se trage CINSTIT, înainte de animație** — exact ca numărul de la ruletă (`_spin`). Perindarea de ~18 iconițe care încetinește (`TU_PASI` / `TU_PAS_START` / `TU_PAS_FACTOR`, ~2s) e decor. Dacă rezultatul s-ar alege la sfârșit n-ar fi nicio deosebire vizibilă, dar codul ar fi unul în care se POATE trișa.
- Tween cu `TWEEN_PAUSE_PROCESS`, fiindcă jocul e înghețat cât ești în cazinou.

**⚠️ DE CE COSTĂ DIFICULTATE (`TU_COST_PROCENT`, +10%), deși dai 3 iteme pe 1.** Fiindcă efectele NU se iau înapoi: ca peste tot în joc (vezi `ender_statue.gd`), un item se aplică o dată, la luare, direct pe statusuri, iar jumătate din ele nici n-ar putea fi anulate (Panic Button a explodat deja, Wine te-a vindecat deja). Din cele 3 iteme pleacă doar RÂNDUL din `player.run_items`, nu și ce ți-au dat — adică trade-up-ul e câștig curat, și fără preț ar fi buton de „mai dă-mi". Același mecanism ca la statuia Ender (`Difficulty.add_trade_penalty`), doar mai mic: acolo urci 2 trepte, aici una. **Îl vrei gratis? `TU_COST_PROCENT = 0`.**

**⚠️ Ordinea la aplicare** (`_aterizeaza`): scoatem cele 3 rânduri din registru în ordine **DESCRESCĂTOARE** (ștergi întâi indicele mic și toți ceilalți se mută cu unu sub tine) și abia apoi `da_item`, fiindcă el ADAUGĂ în aceeași listă. Aceeași grijă ca la `trade.gd::_alege`.

**Aspectul, tot meniul.** `harta/EGT/Border EGT.png` e o planșă 5×4 de chenare de 64×64, exact ca `Border Statuie Ender.png` — deci merg aceleași unelte: `_chenar` decupează celula, o mărește ×2 cu nearest (nine-patch-ul întinde doar MIJLOCUL laturii, iar o celulă de 64 pe un panou de 1010 lăsa linii de 1px) și o dă unui `NinePatchRect`. Celulele: (2,0) panou, (1,2) slot, (3,2) cutia premiului. **⚠️ Nu folosi (0,1) și (0,3): au pătrate ALBE în colțuri.** `Menu.png` a plecat din panoul mesei de ruletă, `ACCENT` s-a mutat de pe auriu pe arama artei (#C67650, scoasă numărând pixelii planșei), butoanele au devenit piatră închisă cu muchie de aramă.

**Verificat rulând**, cu inventar fabricat: 12 iteme → alegi 3 rare → contract plin cu chenar EPIC pe cutie și „?" → tragere → **Panic Button (epic)**, registru 12 → 10, `trade_penalty` 1.00 → 1.10; al doilea contract pornește imediat; click pe altă raritate cât una e blocată = ignorat; click pe legendary = ignorat; 30 de iteme în **turcă** (cele mai lungi propoziții) → nimic nu iese din chenar, inventarul se derulează; 3 iteme din care nu se poate face set → „You need 3 items of the same rarity". `tool_check_i18n` trece: **245 de chei × 8 limbi**, 7 chei noi.

⚠️ Înălțimea panoului (`PANOU_IT_H`) și așezarea căsuțelor s-au schimbat în sesiunea următoare — vezi log-ul „căsuțele contractului".

---

## Session log — 2026-08-07 (cerul Ender-ului, refăcut: liniile drepte erau HASH-UL, nu shaderul)

**Cerut de Răzvan:** „nu îmi plac liniile astea albastre din render de la shader. poți să faci să fie mai premium? ca un joc care are 100.000 de copii vândute pe Steam" (+ captura din `debugging/`).

**Cauza, găsită rulând, nu citind.** Am pus `ender_cosmic.gdshader` singur pe un ColorRect și l-am spart pe componente (o scenă temporară care schimbă un `mode` și salvează câte un PNG). Liniile veneau din `n2`, adică din `noise()`, adică din `hash21`:

```
p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y);
```

Zgomotul interpolat e continuu **doar dacă cele două celule vecine citesc EXACT aceeași valoare în colțul comun**. Hash-ul ăsta termină înmulțind două numere de ordinul lui ~90 (produs ~8600), unde un `float` are pași de ~0,001 — colțul comun ieșea cu valori ușor diferite din cele două celule, deci o TREAPTĂ fix pe granița celulei, adică o linie **dreaptă**. Se roteau încet fiindcă nebuloasa se rotea. **Martorul:** același zgomot cu hash pe biți întregi (cel din `biome.gdshader`) → ecran complet curat, zero linii. **Morală: pentru zgomot pe tot ecranul, hash pe ÎNTREGI, nu `fract()` peste `fract()`.**
- ⚠️ `nether_hell.gdshader` are **încă** hash-ul vechi — fumul lui suferă de aceeași boală. N-am umblat la el, nu l-a cerut.

**Ce s-a schimbat în `ender_cosmic.gdshader`** (rescris, aceleași reguli ca înainte: nu citește ecranul, aceeași compunere într-o trecere, `amount` la fel):
- `uhash`/`hash21`/`hash22` pe biți întregi + interpolare **quintică** (cubica lasă o cută vizibilă pe graniță când împingi contrastul cu `smoothstep`).
- `fbm2`/`fbm3` cu **rotație între octave** și pas **2.03**, nu 2.0 — altfel octavele își suprapun granițele și grila reapare, doar mai fină.
- Nebuloasa e **domain-warped** (zgomot împins cu alt zgomot) + „dust lanes" care taie fâșii din nor. Ăsta e singurul lucru care face un nor procedural să nu arate procedural.
- **Stele pe trei straturi**, cu luminozitate strâmbată cu o putere (puține tari, multe abia vizibile), culoare variată (rece/chihlimbariu) și o cruce subțire de lumină doar pe cele mai tari. ⚠️ Offset-ul stelei în celulă e ±0.25 și haloul se stinge tot până la 0.25: dacă desenul atinge marginea celulei, se taie brusc → exact muchia dreaptă pe care o reparam.
- **Paralaxă**: `atmosphere.gd` scrie în fiecare cadru `world_offset` = `-get_viewport().get_canvas_transform().origin` (pixeli de ecran, zoom-ul deja inclus, deci nu căutăm Camera2D). Cerul curge în urma ta → se simte că ești ÎNTR-un loc, nu că ai un filtru pe ecran. Straturile: 0.020 / 0.055 / 0.115.
- **Dither** de 1/255 pe pixel înainte de afișare. Gradientele foarte întunecate ies altfel în INELE pe 8 biți; banding-ul e cel mai ieftin mod de a arăta amatorism și se repară cu o linie.
- Stea căzătoare la ~19s, aurora șerpuită din zgomot (nu dintr-un sinus curat), vinietă mai moale.

**Verificat rulând**: (1) shaderul singur, la trei poziții de lume — zero muchii drepte, cer diferit la fiecare poziție; (2) prin drumul adevărat (`atmosphere.gd::set_dimension("ender")`) peste o lume falsă și un HUD fals — HUD-ul rămâne lizibil, culorile lumii nu-s spălate; (3) **cost pe GPU la 1920×1080, vsync oprit: 1,487ms fără shader → 1,711ms cu el = 0,225ms.** Ieftin, dar contează că a fost măsurat: proiectul e pentru Android.

---

## Session log — 2026-08-06 (Nether-ul și Ender-ul au un CAPĂT: groapa de la 3000px)

**Cerut de Răzvan:** „poate să fie finite nether și ender ca să găsești statuile mai ușor? Gradient spre negru ca să simuleze o groapă infinită ca în Minecraft — să fie undeva la 3000 de pixeli de spawn."

Un disc de rază `3000` în jurul PORTALULUI prin care ai intrat (nu în jurul tău): acolo e și ieșirea, deci „spawn" și „centrul lumii" sunt același punct. Podeaua se stinge în negru pe ultimii 700px, iar dincolo e negru plin.

**⚠️ Decizia care contează: raza stă ÎNTR-UN SINGUR LOC, `ground.gd`.** Marginea are două fețe — cum ARATĂ (`biome.gdshader`) și unde TE OPREȘTE (`player.gd`) — și amândouă întreabă podeaua. Dacă `player.gd` ar fi avut propriul `3000`, prima schimbare a uneia din ele le-ar fi despărțit fără să crape nimic: ai fi mers pe negru, sau te-ai fi oprit în aer, pe podea încă vizibilă. De-aia zidul NU e un `StaticBody` în cerc, ci un `clamp` după `move_and_slide`.

- `biome.gdshader`: `void_center` / `void_radius` / `void_fade`. `void_radius = 0` (implicit) = fragmentul sare peste tot calculul — lumea normală și Limbo nu plătesc nimic și rămân infinite.
  - ⚠️ Distanța se măsoară pe `world_pos`, **nu** pe `wp` (poziția unduită de `warp`): altfel buza gropii s-ar legăna în Ender, iar zidul stă pe loc — s-ar vedea că marginea desenată și cea adevărată nu-s aceeași.
- `ground.gd`: `MARGINE_RAZA` (3000) + `MARGINE_FADE` (700), `set_margine()` / `opreste_margine()`, `in_margine()` (pentru player) și `loc_in_margine()` (pentru spawn-uri).
- `nether.gd` / `ender.gd`: `_margine(on)`, chemat din **exact aceleași patru locuri** ca `set_nether`/`set_ender` — intrare, ieșire, `suspenda()`, `reia()`. Cât ești în Limbo marginea e stinsă: Limbo e altă lume, cu podeaua lui.
  - ⚠️ În Nether se aprinde DUPĂ `_spawn_return_portal`, nu odată cu podeaua: până atunci portalul nu există, iar centrul ar fi ieșit `(0,0)` — adică groapa ar fi căzut la zeci de mii de pixeli, într-un colț pe care nu-l vezi. S-ar fi văzut doar ca „marginea nu apare".
- `spawner.gd`: când te plimbi pe buză, conul de spawn cade jumătate în gol. `loc_in_margine` **oglindește** punctul față de player (inamicul vine dinspre lume, la aceeași distanță de tine, deci tot din afara ecranului) și abia dacă nici așa nu iese îl trage pe margine.

**Verificat rulând**, Ender și Nether: rază 3000 cu centrul la **0,0px** de portal; aruncat la 9849px și din alt colț → **exact 3000,0** de fiecare dată; **0,000px** mișcare parazită când ești înăuntru (la 1500); statuile de schimb la 882–1920px și structura lui Saratalin la 936px, deci bine în interior; rază 0 după ieșire, 0 cât Nether-ul e suspendat (Limbo) și 3000 înapoi după `reia()`.
- **Martorul care contează:** o captură din CENTRU, fără urmă de negru, lângă una de pe buză. Dacă groapa ar fi fost legată de ecran și nu de lume, cele două ar fi ieșit identice — asta e greșeala clasică la un shader de podea, și doar martorul o prinde.

---

## Session log — 2026-08-06 (cinematica lui Celesto: intră din dreapta, sare imediat, dispare fără fade)

**Cerut de Răzvan:** „vreau ca Celesto în animația de la început să înceapă în partea dreaptă direct, să nu fie în mijloc, și să înceapă direct să se teleporteze fără să aștepte, un interval așa de 1 secundă–0.5 secunde, vezi tu ce arată mai profesional. Și la final când se aude teleportarea nu vreau să își ia fade out, vreau doar să dispară de pe ecran că e mai profesional așa."

Tot în `ender.gd::_cutscene_celesto`. Trei schimbări, dar cea care se simte cel mai tare nu e niciuna dintre cele cerute pe față:

1. **Apare în DREAPTA, nu în mijloc.** `_boss.global_position = centru + Vector2(CUT_SARE_LAT, 0)`. `centru` rămâne ținta CAMEREI — el e descentrat în cadru, camera nu.
   - ⚠️ **Semnele saltului trebuiau inversate** (`-1` pe `i == 0`, nu `+1`). Cu ele nemodificate, primul „salt" l-ar fi pus exact unde era deja: sunet + sclipire albastră, dar el nemișcat — adică fix senzația de așteptare pe care o scoteam.
   - Și primește `ingheata_lateral(true)` ÎNAINTE de materializare, altfel apărea uitându-se spre sud (spre tine) și abia la primul salt intra în profil.
2. **Așteptarea de la început.** Cauza reală nu era o constantă prea mare, ci **ordinea**: bara de HP cobora ABIA DUPĂ ce se materializa el (`await` pe `CUT_BARA + CUT_PANA_LA_SARITURI`), deci 0,5 + 1,7 + 0,5 = **2,7 s** în care stătea nemișcat. Acum `arata_cinematic` e chemat ODATĂ cu materializarea și **nu e așteptat** (are tween-ul lui, merge în paralel): rămâne doar `CUT_PANA_LA_SARITURI = 0.6`. Coborârea barei (1,7 s) se termină aproape fix când el dă primul salt (1,1 + 0,6 = 1,7) — deci nu s-a pierdut nimic din „slow cinematic"-ul cerut în august 4.
   - `CUT_PANA_LA_BARA` a dispărut. `CUT_BARA` a rămas, dar acum înseamnă „cât coboară ea", nu „cât stăm noi".
3. **Fără fade la final.** `tween_property(anim, "modulate:a", 0.0, CUT_STINGE)` → `anim.modulate.a = 0.0`, într-un singur cadru, odată cu sunetul. `CUT_STINGE` a dispărut. Alpha, nu `visible`: sclipirea albastră (`puf`) e un tween pe `modulate` al lui, iar el rămâne în lume și după cinematică — alpha e ce restaurăm la capăt.

**Verificat rulând** (scenă temporară peste `main.tscn`, cu capturi și cu poziția lui logată cadru cu cadru, față de mijlocul cadrului):
- `dx=+170` din primul cadru (dreapta), `ecran_x=695` din 1152 — pe ecran, nu tăiat de margine;
- alpha 0 → 1,00 în 1,11 s (materializarea), primul salt la **1,71 s** = 1,11 + 0,60, exact cât trebuie;
- saltul: `-170` → `+170` → `-170`, deci stânga-dreapta-stânga, pornind din dreapta;
- **`alpha 0.98 → 0.00` într-un singur cadru** la final — înainte ar fi coborât în trepte, ca la materializare (se vede în log-ul de urcare: ~30 de trepte);
- total până iese camera: **3,58 s** (înainte ~6,6 s).
- Capturi: `shot_apare` (dreapta, opac, întors spre mijloc, bara jos și plină), `shot_salt1` (albastru aprins, în capătul celălalt), `shot_disparut` (nicio urmă de el, nici măcar o siluetă pe jumătate transparentă).

---

## Session log — 2026-08-06 (LIMBO: inamici pe bune, fără portaluri, și te dă înapoi în dimensiunea în care ai murit)

**Cerut de Răzvan:** „în limbo nu sunt inamicii destul de op, vreau să aibă spawn-rate-ul, viteza și damage-ul la fel ca cei cu un minut înainte să intre player-ul în limbo — se calculează pe loc. Vreau să nu apară portalul de ender în limbo. Și atunci când ieși din limbo te dă fix din locul unde ai murit (dacă ai murit în lumea normală acolo, dacă în nether acolo, dacă în ender acolo). Când revii din limbo sau orice altă dimensiune nu vreau să se reseteze lucrurile deja folosite în lumea normală."

Patru cereri, patru bug-uri de fond. Merită citite separat, fiindcă niciunul nu e „o cifră prea mică".

### 1. De ce erau inamicii din Limbo blânzi — DOUĂ cauze, nu una

**(a) Ceasul greșit.** `limbo.gd` pornea de la `Difficulty.time - 60`. Dar `Difficulty.time` e ceasul RUNDEI, iar el e ÎNGHEȚAT din secunda în care intri în Nether sau în Ender (`Difficulty.frozen`). Deci dacă mureai la minutul 4 din Nether, dificultatea reală era `intrare + 240`, iar Limbo îți dădea `intrare - 60` — cu minute bune înapoi, inamici de început de rundă. Acum pleacă de la `Difficulty.mult_time()` (accesor public nou în `difficulty.gd`, întoarce `_mult_time()`), adică din dificultatea pe care o SIMȚEAI când ai murit.

**(b) Ritmul fix.** Ăsta era cel mai gras. Limbo oprește spawner-ul și își năștea singur inamicii, cu un firicel FIX: `TRICKLE = 1.4`, adică 0,7 inamici/secundă, indiferent de minut. Afară, la minutul 5, curg ~4,2/s. Acum ritmul vine din `spawner.gd::rata_curenta()` — funcție scoasă din `_spawn_tick`, ca formula (inclusiv corecția `2/(1−nether_share)` de după Nether, greșită o dată deja) să trăiască într-un singur loc. Limbo adună fracții de inamic în `_spawn_acc`, nu numără pauze: la rate mari un cadru poate datora 3-4 inamici.

**Și felul inamicilor**, tot de la spawner (`scena_inamic()`, public nou): mori în Nether → creaturi Nether, în Ender → creaturile lui Celesto, în lumea normală → polițiști cu amestecul de Skinny/scăpați de la momentul ăla. Merge fiindcă dimensiunea rămâne `active` cât e suspendată (vezi mai jos).

Viteza și damage-ul n-au avut nevoie de nimic: `enemy.gd` coace viteza din `Difficulty.enemy_speed_mult()` la `_ready`, iar damage-ul se citește la fiecare mușcătură — amândouă trec prin `_mult_time()`, deci s-au aliniat singure odată ce ceasul a devenit corect.

### 2. Portalul de Ender în Limbo

`WORLD_NODES` din `limbo.gd` NU avea `"Portals"` — singura listă din trei (`nether.gd`, `ender.gd`, `limbo.gd`) căreia îi lipsea. Deci generatorul rămânea aprins și-ți răsăreau portaluri Nether și fântâni Ender în câmpia alb-negru. Adăugat. **Asta e a treia oară** când un generator lipsește dintr-o listă și nimic nu te avertizează (înainte: „EGTs", de două ori, pe 2026-07-30).

### 3. Te dă înapoi ÎN DIMENSIUNEA în care ai murit

Până acum `player.die()` ÎNCHIDEA Nether-ul/Ender-ul (`exit_nether(false)`) și abia apoi chema Limbo. Adică minutul de Limbo îți mânca portalul de întoarcere, structura de invocare, boss-ul la viața pe care i-o lăsaseși și cele 7 (sau 6) minute — iar la ieșire te trezeai în lumea normală. Acum e invers: **Limbo întreabă primul**, iar dacă te prinde, pune dimensiunea **PE PAUZĂ** în loc s-o închidă.

`nether.gd` și `ender.gd` au primit `suspenda()` / `reia()` + un `_suspendat` care le face `_process`-ul mut. Cât ești în Limbo: ceasul lor stă (`_elapsed` nu curge), nu mai rescriu `mult_time_override` (e al Limbo-ului), podeaua și atmosfera trec pe neutru, iar ieșirea lor (portalul Nether / fântâna Ender), structura de invocare, statuile de schimb din Ender și boss-ul sunt **ascunse, nu șterse**.

**Trei capcane rezolvate pe drum:**
- **Boss-ul ar fi fost măturat.** Saratalin și Celesto sunt în grupul `"enemy"` — exact grupul pe care îl golește `limbo.gd::_clear_enemies()`. Un boss adus la jumătate de viață ar fi dispărut, iar portalul nu s-ar mai fi deschis NICIODATĂ. Soluție: `remove_from_group("enemy")` cât e parcat, `add_to_group` la reluare.
- **„Press E" în aer.** Portalul ascuns rămâne în grupul `"interactable"`, deci `interact_ui.gd` ți-ar fi scris „Press E to interact" peste câmpia alb-negru — și ai fi ieșit din Limbo prin el. Adăugat un filtru `is_visible_in_tree()` acolo (nu `visible`: statuile Ender sunt ascunse de pe părintele lor).
- **Decorul lumii normale s-ar fi aprins peste Nether.** La ieșirea din Limbo, `_set_world_enabled(true)` era necondiționat. Acum e `_set_world_enabled(_dimensiune == null)`.

Ca să nu rămână nimic ascuns dacă mori a doua oară în Limbo, `exit_nether` / `exit_ender` cheamă `reia()` din prima linie când sunt suspendate.

### 4. Ce ai folosit deja în lumea normală NU se mai reface

Intrarea în ORICE dimensiune golește toate generatoarele (`_toggle_generator` șterge copiii și `_loaded`), iar la ieșire ele se refac de la zero. Deci un cufăr deschis se întorcea închis, o statuie invocată se întorcea în picioare — la fiecare drum în Nether, dar și la o simplă plimbare de `load_radius` chunk-uri. Adică upgrade-uri câte chei ai și Gardă după Gardă din același loc.

`chests.gd` și `statues.gd` au primit tiparul care exista deja în `monuments.gd`: un dicționar `_folosite` + `marcheaza_folosit(pos)`, chemat de `chest.gd::invoca()` și `statue.gd::invoca()`. **Cheia e POZIȚIA rotunjită, nu chunk-ul** — la cufere chunk-ul ar fi fost greșit, fiindcă lada se pune lângă poteca chunk-ului, iar o potecă lungă iese din el, deci lada poate cădea în alt chunk decât cel care a generat-o. EGT-ul nu intră: el e refolosibil prin design.

### Verificat RULÂND (`test_limbo.tscn`, temporar, șters după)

Patru scenarii, toate verzi de două ori la rând:
- **lumea normală**: dificultate 240 din 300 · Portals oprit ȘI golit · zero obiecte interactibile vizibile · **rata măsurată 4,42 inamici/s față de 4,24 cerut** (cu tunul player-ului oprit, ca să nu moară nimeni în timpul măsurătorii) · întoarcere la ±1px.
- **Nether**: `active && _suspendat` · dificultate 440,4 = 500,4 − 60 · portal ascuns · inamicii = `enemy_nether.tscn` · la ieșire ceasul Nether-ului a stat pe loc (200,10 → 200,38, adică doar cadrele de tranziție) · `xp_bonus` înapoi la 2,0 · decorul lumii rămas stins.
- **Ender**: statuile de schimb stinse dar NEȘTERSE (3 → 3) · Celesto scos din `"enemy"` · la întoarcere viu cu **hp neatins** (100000 → 100000) · fântâna vizibilă iar · `xp_bonus` 3,0.
- **cufere/statui**: cu un **martor** — golesc și regenerez FĂRĂ să marchez → obiectul se întoarce; marchez → nu se mai întoarce. Fără martor, „nu s-a întors" ar fi putut însemna doar că regenerarea n-a apucat să ruleze.

Plus o captură de ecran: fântână Ender lângă player în lumea normală → mori → în Limbo câmpia e goală, alb-negru, cu 38 de inamici pe tine și **zero** fântâni.

**De știut la testare:** dacă player-ul apucă să urce în nivel, ecranul de Level Up pune arborele pe `paused` și generatoarele nu mai construiesc nimic — m-a costat două rulări până am văzut `paused=true`.

---

## Session log — 2026-08-06 (Adrenaline: +15% → +7% crit)

**Cerut de Răzvan:** „Adrenaline vreau sa aiba doar +7 crit chance".

**Schimbat în trei locuri, fiindcă numărul apare în trei:**
1. `levelup.gd` — efectul real, `p.crit_chance += 0.07` (era `0.15`), plus `desc` și comentariul.
2. `i18n.gd` — **descrierea E cheia de traducere**. Am redenumit cheia `"+15% Crit chance"` → `"+7% Crit chance"` și am renumerotat toate cele 8 traduceri. Dacă schimbi doar `levelup.gd`, cheia nu mai există în tabel și **celelalte 8 limbi afișează textul englezesc brut**, fără nicio eroare. `tool_check_i18n.tscn` prinde exact asta — rulat, „✔ TOTUL E TRADUS" (238 chei × 8 limbi).
3. `codex.html` + republicare pe același URL — cardul, ȘI nota despre Noroc, unde 17,5 noroc duce acum un crit de 7% la **14%** (scria 15% → 22%).

**Mecanica NU s-a atins:** rămâne crit fix, aditiv la fiecare luare, neplafonat (multi-crit peste 100%), se adună cu Megane's Katana și îl umflă Norocul.

**Verificat rulând**, nu doar citind codul: `crit_chance` 0 → 0.07 → 0.14 → 0.21 la trei luări, traducerile ies corect (`+7% Kritchance`, `+7% クリティカル率`, `+7% шанс крита`), și o captură din meniul REAL de level up cu **ADRENALINE / +7% CRIT CHANCE** în chenarul Rare. Scenele de test (`test_adrenaline*.gd/.tscn`) au fost șterse după.

---

## Session log — 2026-08-06 (Celesto îngheață din profil în cinematică + fântâna chiar se stinge)

**Cerut de Răzvan:** „vreau la cutscene-u lu celesto sa fie freeze frame si vreau sa nu se uite in sud … cand e telepotat in partea dreapta sa se uite spre west … cand e in partea stanga sa se uite spre east. Si well-ul cand se inchide vreau sa aiba un fade pana la 0% opacity".

**1. Freeze frame în cinematică.** `celesto.gd` are acum `ingheata_spre(dir)` / `ingheata_lateral(la_dreapta)`: pune animația direcției cerute, sare pe cadrul `CUT_CADRU` (0) și dă `anim.pause()` — deci stă, nu mai merge pe loc. `_ready()` îl naște deja înghețat pe „west" dacă e adormit (înainte pornea `south`, adică se uita fix la tine), iar `ender.gd::_cutscene_celesto` îi dă direcția la fiecare salt: **dreapta → `west`, stânga → `east`**, mereu spre mijlocul cadrului.
- ⚠️ **`trezeste()` repornește animația EXPLICIT** (`anim.play(anim.animation)`). `_uita_spre()` cheamă `play()` doar când se SCHIMBĂ direcția — dacă prima direcție de mers după cinematică era chiar cea înghețată, boss-ul ar fi alunecat pe hartă ca o statuie. Verificat: după cinematică `playing=true` și cadrul chiar curge (0 → 4 în 0,4s).
- Verificat rulând, cu poziții tipărite: `dx=+170 → anim=west`, `dx=-170 → anim=east`, `playing=false`, `frame=0` pe toată durata.

**2. Fântâna Ender se stinge la închidere — și de ce nu se stingea deloc până acum.** `intra_in_pamant()` cerea de mult `modulate:a → 0` în paralel cu scufundarea, dar **nu se vedea nimic**: `portal_ender.gdshader` își citește singur textura și scrie `COLOR` peste, deci culoarea care intra în `fragment()` (textură × modulate) era aruncată. Fântâna cobora **opacă** și pierea dintr-o bucată la `queue_free`. Din același motiv nu se aplica nici `ender_tint`-ul din `set_cosmic()` — piatra n-a fost niciodată stinsă în Ender, deși README-ul zicea că e.
- Shaderul are acum două uniforme: **`tint`** (culoarea, pentru Ender) și **`fade`** (opacitatea, pentru scufundare). Două, nu unul cu alfa cu tot, fiindcă la ieșire se animă în ACELAȘI timp din locuri diferite (`set_cosmic(false)` 0,8s și `intra_in_pamant()` 1,0s) — pe o singură proprietate, tween-urile s-ar fi călcat pe picioare.
- ⚠️ **Materialul se duplică în `_ready()`**: e o sub-resursă a scenei, adică ACELAȘI obiect în toate fântânile de pe hartă. Fără copie, stinsul uneia le-ar fi stins pe toate.
- ⚠️ **Nu pune `COLOR = c * COLOR`**: `COLOR` intră în `fragment()` DEJA înmulțit cu textura, deci s-ar aplica de două ori (verificat pe pixeli: iese vizibil mai închisă). Iar `MODULATE` **nu există** în Godot 4.7 la `canvas_item` — shaderul nu compilează.
- Verificat pe drumul adevărat (intrare în Ender → boss „căzut" → `exit_ender`): în Ender `tint=(0.8, 0.84, 1.0)`, la ieșire `fade` 1.0 → 0.74 → 0.49 → 0.24 → nod șters, cu culoarea revenind la alb în paralel, fără să se bată cap în cap. Pe captură fântâna e o fantomă la 750ms.

**Capcană de test:** ca să prinzi ieșirea din Ender, ieși **imediat** după cinematică (~6,5s). Lăsat mai mult, player-ul moare în valul de la intrare, iar moartea iese singură din Ender — nu mai ai ce închide (și scrie și în leaderboard-ul real: am șters scorul fals de 2 secunde).

---

## Session log — 2026-08-06 (Nether-ul, mai luminos)

**Cerut de Răzvan:** „e cam intunecat in nether fa sa fie putin mai luminos".

Întunericul de acolo venea din **două** locuri, amândouă atinse, nimic altceva (Ender-ul și lumea normală rămân exact cum erau):
1. `atmosphere.gd::DIM_TINT["nether"]`: `(0.98, 0.58, 0.50)` → **`(1.05, 0.80, 0.72)`**. Roșul aproape că nu s-a mișcat (locul TREBUIE să rămână roșu), verdele și albastrul urcă ~38% — ei sunt cei care scot cărămida din negru și dau creaturilor nuanța lor înapoi.
2. `nether_hell.gdshader`: `vignette_strength` **0.50 → 0.28** și `vignette_color` `(0.07, 0, 0)` → `(0.13, 0.02, 0.02)`. Marginile erau partea cea mai rea, fiindcă în Nether se adună **două** viniete: asta plus cea obișnuită din `atmosphere.gd` (0.55), care e pe toate dimensiunile.

**Verificat rulând**, nu din ochi: o scenă de test a instanțiat `main.tscn`, a chemat `nether.enter(player)` și a salvat **două capturi din același cadru** — una cu valorile noi, una cu cele vechi puse la mână peste `_dim_modulate` / `_dim_mat`. Luminozitate medie pe ecran **0,080 → 0,089 (+11%)**, iar în colțuri mult mai mult. Scena de test a fost ștearsă.

⚠️ **Capcană de metodă, pierdut un rul întreg pe ea:** la prima încercare cele două capturi au ieșit una „0,085" și alta „0,008" — a doua era de fapt ecranul **YOU DIED**. Player-ul lăsat singur în mijlocul valului de 25 moare în ~2 secunde, deci orice test care compară două momente ale aceleiași intrări în Nether trebuie să-l țină în viață (`hp = max_hp` în `_process`). Vezi și regula de mai sus: un test care lasă player-ul să moară scrie și în leaderboard-ul real.

---

## Session log — 2026-08-05 (masa Ender: costul devine 15% ADEVĂRAT + meniul refăcut „spooky")

**Cerut de Răzvan:** „vreau sa scrie in meniul de la statuia de ender 15% difficulty si as vrea sa arate mai spooky meniul. Nu asa friendly. Ti-am pus in folderul harta Border Statuie Ender... Vreau sa fie super profesional ca un joc deja scos pe Steam cu 100.000 de downloads. Si sa si mentioneze You can only choose one".

**1. Costul e acum CHIAR 15%, nu doar scris așa.** `Difficulty.penalty` (secunde adăugate la ceasul inamicilor) a fost înlocuit cu `Difficulty.trade_penalty`, un MULTIPLICATOR care pleacă de la 1.0 și se înmulțește cu 1.15 la fiecare schimb. Motivul e că eticheta trebuie să spună adevărul: cu secunde, „+15" însemna +8,8% viață dar doar +2,6% spawn și +0,7% viteză, procente diferite pe fiecare stat, care se mai și subțiau pe măsură ce trecea runda. Un „15%" scris peste mecanica aia ar fi fost o minciună.
- Se înmulțește în `enemy_hp_mult`, `enemy_damage_mult`, `spawn_mult` și `enemy_speed_mult`.
- **NU** intră în `xp_mult`: e un COST. Pe varianta veche cu secunde creștea și XP-ul, adică penalizarea se plătea singură pe jumătate.
- La viteză intră **înainte de `SPEED_CAP`**, deci plafonul rămâne deasupra: nici cu 10 schimburi inamicii nu trec de 2.2× (verificat). Consecință de știut: după ce viteza atinge plafonul (3–4 minute de Final Swarm), schimburile nu mai adaugă viteză.
- `ender_statue.gd`: `cost_dificultate` (secunde) → `cost_procent` (15).

**Măsurat:** 1 schimb = +15,0% pe toate patru; 2 = +32,2%; 3 = +52,1%. XP +0,0%, ceasul rundei neatins. Pentru comparație, vechea variantă pe secunde dădea la minutul 6 doar +8,8% viață / +2,6% spawn / +0,7% viteză — deci schimbul e acum de câteva ori mai scump, ceea ce s-a și cerut.

**2. Meniul, refăcut din temelii.** Rama de lemn auriu (`Menu.png`) a plecat — ea era tot ce-l făcea prietenos. În loc, `harta/Border Statuie Ender.png`, o **planșă de 5×4 chenare de 64×64** din care `trade.gd` decupează la rulare doar celulele de care are nevoie (`_chenar`): celula (2,0) pentru rama mare, (1,2) pentru rândurile de ofertă. Fiecare chenar are și interiorul lui aproape negru, deci ține loc și de ramă, și de fundal.
- **Text nou:** „COST: +15% DIFFICULTY" (roșu-sânge, singurul lucru de culoarea aia pe ecran) și, sub el, „You can only choose one". Amândouă traduse în cele 8 limbi. ⚠️ Cheia din `i18n.gd` e scrisă cu `%%` („Cost: +%d%% difficulty") — așa cere formatarea GDScript pentru un `%` afișat, și cheia din tabel trebuie să fie EXACT ca în cod.
- **Feedback la mouse:** rândul neatins e tras spre cenușiu (`RAND_STINS`), cel de sub mouse revine la culoarea plină, în 0,12s. Prima variantă folosea doar transparență (0.45 → 1.0) și **pe captură nu se vedea diferența** — stacojiul iese aprins pe negru chiar și la 45%.
- Itemul pe care îl DAI stă la 70% opacitate, cel primit la 100%: se citește direcția afacerii fără să scrie nimeni „give"/„receive".
- Titlul respiră încet (1,3s dus, 1,3s întors), contur stacojiu în loc de negru.

**Două capcane, ambele prinse pe captură de ecran, nu în cod:**
1. **Panoul trebuie să încapă în 1152×648**, nu în rezoluția monitorului — jocul desenează la rezoluția aia și întinde imaginea (`window/stretch/mode = canvas_items`). Prima variantă avea 960×**672** și îi ieșeau colțurile de sus și de jos din ecran; se vedeau doar două linii verticale, exact ca un bug de randare. Acum 940×592, cu toate cifrele de aspect declarate ca fiind în pixeli de ecran de bază.
2. **Nine-patch-ul întinde mijlocul laturilor, nu grosimea lor.** O celulă de 64px pusă pe un panou de 940 lăsa linii de 1px, adică o ramă desenată cu pixul. Celula se mărește acum ×`ZOOM` (2) cu vecinul cel mai apropiat înainte să devină textură, iar `patch_margin` se înmulțește la fel — linia are 2px și rama capătă greutate.

---

## Session log — 2026-08-05 (statuia Ender: overlay opac + statuile în inel în jurul fântânii)

**Cerut de Răzvan:** „Overlayu de l ai pus in ender nu se vede bine e cam bugat, si statuile din ender vreau sa fie la 2000 de pixeli maxim departare de portal si minim 600".

**1. Overlay-ul.** Reprodus intrând CU ADEVĂRAT în Ender (fântână + cinematica lui Celesto) și deschizând masa acolo. Vinovatul: fundalul mesei era `alpha = 0.985`, copiat de la cazinou — iar prin acel 1,5% răzbătea **cronometrul Ender-ului**, 64px de albastru aprins cu contur de 9px, exact în capul panoului. Arăta ca un artefact de randare. Acum e **complet opac** (`alpha = 1.0`), ca ecranul de „YOU DIED". N-a fost o problemă de straturi: masa e pe 10, ceasul Ender-ului pe 4 — deci era dedesubt, doar că se vedea prin.

**2. Statuile, în inel.** `ender_statues.gd` **nu mai e un generator pe chunk-uri**. Era, de câteva ore, și era unealta greșită: chunk-urile împrăștie la infinit, deci o statuie putea cădea la 30.000px de fântână, într-un loc în care nu ajungi în cele 6 minute. Cerința („minim 600, maxim 2000 de portal") e o regulă de DISTANȚĂ FAȚĂ DE UN PUNCT, deci se scrie direct: la deschiderea Ender-ului pune `numar` (3) statui într-un inel de `dist_min`–`dist_max` (600–2000) în jurul fântânii, la cel puțin `dist_intre` (520) una de alta. În plus, așa știi sigur că ai trei — filtrarea unui generator ți-ar fi dat câteodată zero.
- `ender.gd` a primit `portal_pos()` (public), fiindcă `_fantana` e privat și generatorul are nevoie de centrul inelului.
- Se pun O SINGURĂ dată: „am copii" e semnul, iar `_toggle_generator` îi șterge la ieșire, deci se re-armează singur.

**Verificat prin rulare** (intrare reală în Ender, spawner oprit + Celesto scos → fără moarte, fără scor fals): 3 statui la 1379 / 1413 / 1750 px de fântână, la 883–2971 px una de alta; pe **500 de intrări simulate**, cea mai apropiată **602px**, cea mai depărtată **1999px**, niciuna în afara inelului. Captură de ecran cu masa deschisă în Ender: fără nicio fantomă de ceas.

---

## Session log — 2026-08-05 (STATUIA ENDER: schimbi iteme, plătești în dificultate)

**Cerut de Răzvan:** „Ti-am bagat si ender statue. Statuia asta se spawneaza doar in ender dimension si cand apesi pe ea deschide un meniu de trade. Iti apar 3 iteme de ale tale(random orice raritate) si cu o sageata spre dreapta ce iteme pot deveni(cu 2 raritati mai mari) - Costul pentru fiecare tranzactie este +15 difficulty (Spawn Rate mai rapid, viteza mai mare si damage mai mare)".

**Ce s-a făcut:**
- `ender_statue.tscn` + `ender_statue.gd` — călugărul din `harta/Ender Statue.png` (128×128, scara 2.4, `ACOPERIRE_JOS = 74` calculat la rulare, ca la monument). Grupurile `ender_statue` + `interactable`.
- `ender_statues.gd` + nodul `EnderStatues` în `World` — **primul generator care merge PE DOS**: pornește stins (`visible = false`, `process_mode = 4`) și se aprinde exact cât ești în Ender. `ender.gd` are pentru asta o listă nouă, `ENDER_ONLY_NODES`, pe care o trece prin același `_toggle_generator` cu `not on`. ⚠️ NU se trece în `WORLD_NODES` — acolo ar face exact invers. `statue_chance = 6%` (măsurat 6,18%), mai des decât statuia normală (3%) fiindcă Ender-ul e gol și ține 6 minute.
- `trade.gd` + nodul `Trade` — masa „ENDER TRADE", construită din cod ca `levelup.gd` (ramă `Menu.png`, border-uri de raritate, auriu). 3 rânduri: itemul tău ➜ ce poate deveni. Pune jocul pe pauză, ESC/Leave pleacă fără schimb, `pause.gd::_blocked()` o cunoaște (altfel ESC deschidea pauza peste ea).
- **Registrul rundei — `player.run_items`.** Jocul NU ținea minte nimic din ce ai luat; nimeni n-avusese nevoie. Se scrie dintr-un singur loc, `levelup.gd::_apply`, deci prinde toate sursele (level up, cufere, statuia însăși). Meta și OP start NU intră — alea nu trec prin `_apply` și nici nu sunt iteme.
- **Scara rarităților**, în `levelup.gd` lângă `RARITIES`: `SCARA_RARITATI` + `raritate_mai_sus(rar, trepte)`, plafonat la Legendary (common→rare, uncommon→epic, rare→legendary, epic→legendary, legendary→alt legendary). Plus `item_dupa_id`, `item_random_de_raritate` (sare peste Lucky Die din același motiv ca la cufăr) și `da_item(u, p)`, versiunea publică a lui `_apply`.
- **Prețul: `Difficulty.penalty`**, un câmp nou, adunat în `_mult_time()`. `cost_dificultate = 15` secunde pe tranzacție. **⚠️ ÎNLOCUIT în aceeași zi** — vezi log-ul „costul devine 15% ADEVĂRAT" de mai sus: astăzi e `Difficulty.trade_penalty`, un multiplicator, iar butonul se cheamă `cost_procent`. Ce urmează în intrarea asta descrie mecanica veche.

**Două decizii care se văd în cod și trebuie știute:**
1. **Penalizarea NU intră în `Difficulty.time`.** `time` e ceasul de pe ecran ȘI scorul din leaderboard: acolo, o tranzacție ți-ar fi scurtat runda cu 15 secunde și ți-ar fi umflat scorul cu 15 secunde netrăite — adică ai fi putut CUMPĂRA scor. Se adună și peste `mult_time_override`, altfel s-ar fi evaporat fix unde o cumperi (Ender-ul își rescrie override-ul la fiecare cadru).
2. **Schimbul NU ia înapoi efectul itemului dat.** Efectele se aplică o singură dată, la luare, direct peste statusuri, și nicăieri în proiect nu există „scoate itemul" — pentru jumătate din ele nici n-ar avea sens (Panic Button a explodat deja, Wine te-a vindecat deja). Deci itemul dispare din REGISTRU, nu din statusuri: schimbul e un câștig curat, plătit în dificultate. Ca să coste și puterea itemului dat, trebuie scris un „dez-aplică" pentru toate cele 50 de iteme. **Un schimb pe statuie** — fără regula asta n-ar fi existat nicio limită, fiindcă fiecare schimb îți lasă registrul la fel de mare.

**Verificat prin rulare** (scenă de test peste `main.tscn` cu spawner-ul oprit → fără inamici, deci fără moarte și fără scor fals; `GameSettings` neatins):
- registrul: gol la start, exact 7 după 7 iteme luate, „Nothing to trade" cât e gol (și masa nu se deschide);
- generatorul: stins în lumea normală, aprins în Ender, `Props` invers; statuia la **1px** de locul calculat; rata **6,18%** pe 10.000 de chunk-uri;
- rândurile: **+2 trepte** măsurate (Rolling Papers/Common ➜ Gunslinger/Rare), Epic ➜ Legendary la +1 (plafonul), niciodată același item înapoi;
- schimbul: itemul dat iese din registru, cel primit intră, mărimea rămâne aceeași; `penalty` 0 → 15; `Difficulty.time` **neatins** (0,33 → 0,33); statuia consumată, masa închisă, jocul repornit, a doua apăsare nu mai face nimic;
- penalizarea supraviețuiește unui `mult_time_override` (adică Ender-ului) și se șterge la `reset_run()`.

**Cât înseamnă +15s, măsurat pe curbele din `difficulty.gd`** (spawn / viteză / damage / viață):
| minutul | spawn | viteză | damage | viață |
|---|---|---|---|---|
| 1 | +5,5% | +0,9% | 0% | +8,9% |
| 5 | +2,9% | +0,7% | +2,1% | +8,8% |
| 9 | +2,0% | +0,7% | +2,1% | +8,8% |
| 11 (Final Swarm) | +14,9% | +3,5% | +9,1% | +26,0% |

Damage-ul e 0% în primul minut și jumătate fiindcă `enemy_damage_mult()` nu crește deloc până la `RAMP_START` (1:30) — nu e o scăpare a statuii, e curba existentă. (Tabelul ăsta e ISTORIC: cifrele lui au fost chiar motivul pentru care mecanica a trecut de la secunde la procent, în aceeași zi. Butonul de azi e `cost_procent`.)

---

## Session log — 2026-08-05 (hoarda monumentului curge EGAL în 10 secunde)

**Cerut de Răzvan:** „Vreau sa se spawneze nu in acelasi timp ci in 10 secunde asa pe rand cat sa fie egal in 10 secunde".

**Ce s-a făcut:** în `monument.gd`, `batch` (10) și `batch_gap` (0.06) au fost înlocuite cu **un singur buton, `spawn_duration = 10.0`**. Cele 103 creaturi ies acum una câte una, la `spawn_duration / 103 ≈ 0,097s` distanță.

Bucla din `_scoate_hoarda` s-a rescris din „scoate un val, așteaptă, scoate alt val" în **„la fiecare cadru, întreabă câți ar fi trebuit să fie afară până acum"**. Trei lucruri se sprijină pe asta:
- **nu se adună întârzierile.** Cu pauze înlănțuite, fiecare cadru lung se adaugă la coadă și cele 10 secunde ajung 12–13. Așa, dacă un cadru sare, următorul scoate doi și hoarda se termină tot la secunda 10;
- **ceasul e ADUNAT din delta cadrelor și STĂ PE LOC pe pauză adevărată** (`if not get_tree().paused`). Contează mult aici: în 10 secunde de hoardă aproape sigur prinzi un nivel, iar `levelup.gd` oprește arborele. Cu ceasul de perete, cât alegeai upgrade-ul timpul curgea, iar la Resume ți se vărsa restul hoardei într-un cadru;
- **cele 3 Gărzi sunt înfipte în șir la 1/6, 1/2 și 5/6** (≈1,6s, 5s, 8,3s): nu vin toate la început, iar prima nu mai cade peste cadrul cu alerta și cutremurul.

Monumentul rămâne acum **în picioare cele 10 secunde** cât toarnă (`await _scoate_hoarda`) și abia apoi se scufundă.

**Verificat prin rulare** (scenă de test temporară, ștearsă după — fără `main.tscn`, deci fără risc de scor fals în leaderboard):
- 103 creaturi, prima la 0,02s, ultima la **9,90s**; pe secunde: **11 · 10 · 10 · 11 · 10 · 10 · 11 · 10 · 10 · 10**;
- cel mai mare pumn într-un singur cadru: **1 creatură**;
- Gărzile la **1,65s / 4,95s / 8,26s**;
- **pauză simulată de 2 secunde reale la t=3s** (ca la Level Up): ceasul hoardei a rămas la 3,00, iar secunda 3 și-a primit tot cele 11 creaturi ale ei — nu s-a vărsat nimic la Resume.

**⚠️ Corectură la măsurătoarea de ieri** (din log-ul de mai jos): „invocarea costă ~140ms, mai ales din simbolul de alertă" era **greșit**, și greșeala era a testului, nu a jocului. Scena de test nu trecea prin ecranul de încărcare, deci `_spawn_alert` chiar citea de pe disc cele 16 PNG-uri — dar `res://Upgrades` e în `PreloadAll.FOLDERE`, iar într-o rundă adevărată ele sunt deja în memorie. Cu `PreloadAll.porneste()` + `pas()` rulate în test înainte de măsurătoare (789 fișiere), **cel mai lung cadru al invocării e 19,5ms**, adică un cadru normal. Morala pentru data viitoare: **o scenă de test care măsoară timpi trebuie să treacă întâi prin preîncărcare**, altfel măsori încărcarea de pe disc, nu jocul.

---

## Session log — 2026-08-05 (MONUMENTUL: structură nouă în lumea normală, scoate o hoardă de 103)

**Cerut de Răzvan:** „ti-am bagat o noua structura in folderul harta se numeste Monument Spawner, vreau sa se spawneze in lumea normala si poti sa apesi pe el doar daca l-ai batut pe Celesto. Iti spawneaza inamici care dau drop 2x mai mult xp, dar sunt de 3x mai rapizi si dau de 3x mai mult damage fata decat cei din momentul din care dai spawn. Vreau sa fie spawnati random 100 de enemies din orice dimensiune + 3 Bossi de la statui (garda)".

**Ce s-a făcut:**
- `monument.tscn` + `monument.gd` — obeliscul din `harta/Monument Spawner.png` (128×128, ca statuia; scara 2.4, arta așezată la rulare cu `ACOPERIRE_JOS = 74`, ca la statui și copaci). E în grupurile `monument` și `interactable`.
- `monuments.gd` + nodul `Monuments` în `main.tscn` (în `World`) — generator pe chunk-uri, copia lui `statues.gd`: `monument_chance = 1%` (sub statuie 3% și portal 1.5%), sămânță proprie `0x3B10`, se ferește de copaci, pietre **și statui**. Măsurat pe 10.000 de chunk-uri: 0,94%.
- **Încuiat până cade Celesto:** `eticheta()` întoarce „Defeat Celesto to awaken it" cât `ender.celesto_invins` e fals, iar `invoca()` refuză. Rămâne `poate_invoca() == true` ca să aibă text deasupra — aceeași soluție ca la cufărul fără cheie.
- **Hoarda:** 100 de inamici aleși la întâmplare din toate cele patru feluri (polițist / Police Skinny / creatură Nether / creatură Ender, ponderi egale în `FELURI`) + 3 Gărzi care ies din pământ ca la statuie. Ies unul câte unul, în ritm egal, pe 10 secunde (vezi log-ul de mai sus), într-un inel de 620–1150px în jurul monumentului. Se nasc în `World`, NU sub monument: containerul lui de chunk se șterge când te îndepărtezi.
- **Cele trei modificări**, față de un inamic născut ÎN ACEEAȘI CLIPĂ: `speed × 3` (pusă înainte de `add_child`, fiindcă `enemy._ready()` coace acolo viteza finală), `damage_mult × 3` (relativ — creatura din Ender rămâne dublă față de rest, deci iese 6.0) și `xp_drop_mult = 2`, un `@export` NOU în `enemy.gd`, aplicat în `_drop_xp` peste `Difficulty.xp_mult()`. Gărzile primesc și ele: viteză ×3, `damage_mult` ×3 (**`@export` nou în `garda.gd`**, implicit 1.0 → Garda de la statuie nu se schimbă), `lightning_damage` ×3 și `xp_value` ×2.
- Monumentul se scufundă și dispare după invocare, iar `monuments.gd` **ține minte chunk-ul** (`_folosite`) ca să nu se întoarcă la reîncărcarea chunk-ului — altfel puteai farmări hoarda la nesfârșit din același loc plimbându-te 1500px și înapoi. (⚠️ Statuile N-AU apărarea asta: o statuie folosită chiar reapare dacă pleci și revii. N-am atins-o, dar merită știut.)
- „Monuments" adăugat în `WORLD_NODES` din `nether.gd`, `ender.gd` **și** `limbo.gd`.
- i18n: 3 chei noi × 8 limbi („THE MONUMENT AWAKENS", „Double XP. Triple speed. Triple damage.", „Defeat Celesto to awaken it"). `tool_check_i18n.gd` verifică de acum și `monument.gd`, și `chest.gd` (al doilea lipsea de la început, deși are `eticheta()`).

**Verificat prin rulare** (scenă de test temporară peste `main.tscn`, ștearsă după; player-ul făcut invulnerabil și cu armele oprite ca să nu moară → fără scor fals în leaderboard, și ca să nu-mi omoare hoarda cât o număr — prima măsurătoare a ieșit 88/2 exact fiindcă îi împușca):
- 100 de inamici + 3 Gărzi, amestecate din toate cele patru feluri;
- raportul de viteză față de un inamic normal de același fel: **3,001–3,002** pe toți;
- `damage_mult` 3.0 la polițist, 3.9 la Skinny (1.3×3), 6.0 la Ender (2×3);
- gemă de XP: **2 la un inamic normal, 4 la unul din hoardă**;
- Gărzile: viteză 210 (3×70), `damage_mult` 3.0, fulger 45 (3×15), XP 100 (2×50);
- generatorul: 0,94% pe chunk, monumentul apare la 1px de locul calculat, iar după trezire **nu se mai întoarce** când pleci 30.000px și revii.

**Ce nu e perfect:** invocarea costă un cadru lung, ~140ms în scena de test. ⚠️ **Cifra asta s-a dovedit falsă mai târziu în aceeași zi** — vezi log-ul „hoarda curge egal în 10 secunde": scena de test nu trecea prin ecranul de încărcare, așa că plătea de pe disc cele 16 cadre ale simbolului de alertă, pe care jocul adevărat le are deja în memorie (`res://Upgrades` e în `PreloadAll.FOLDERE`). Cu preîncărcarea pornită, cel mai lung cadru al invocării e **19,5ms**.

---

## Session log — 2026-08-05 (ecranul de „YOU DIED" pe fundal complet negru)

**Cerut de Răzvan:** „cand scrie you died, vreau sa fie background-ul negru".

Overlay-ul din `gameover.gd` era `Color(0, 0, 0, 0.8)` — se vedea jocul înghețat prin el. Acum e `Color(0, 0, 0, 1.0)`, opac. O singură linie (`gameover.gd:19`); restul ecranului (titlu roșu, statistici, butoane) neatins.

**Verificat** cu o scenă de test temporară (ștearsă după): fundal magenta pe un `CanvasLayer` cu `layer = -100`, peste el ecranul de Game Over → în captură nu se mai vede niciun pixel magenta. Testul **nu** a chemat `show_gameover()`, tocmai ca să nu scrie un scor fals în `user://scores.save` (vezi regula de sus).

---

## Session log — 2026-08-05 (ecran de încărcare la pornire: tot e în memorie înainte să vezi meniul)

**Cerut de Răzvan:** „Sa fie un loading screen inainte sa intrii in joc (inainte si de meniu) in care sa se incarce deja toate asseturile sa nu faca lag (exemplu: toate dimensiunile si enemies)".

**`loading.tscn` e acum scena principală** (`project.godot`, `run/main_scene`), înaintea meniului: logo, bară cyan, `LOADING nn%` peste cadrul static de fundal. Se desenează din trei fișiere UȘOARE — un ecran de încărcare care ar aștepta el arta grea n-ar avea niciun rost.

**`preload_all.gd` (autoload `PreloadAll`) scanează FOLDERE, nu o listă scrisă de mână.** O listă de fișiere ar fi rămas în urmă la primul PNG pus în folder; numele folderelor se schimbă mult mai rar. 788 de fișiere, ~1,9 s pe mașina asta.

**⚠️ Miezul: ține REFERINȚE.** Cache-ul de resurse al lui Godot e pe referințe SLABE — o resursă pe care n-o mai ține nimeni se eliberează imediat ce se termină încărcarea și se recitește de pe disc data viitoare. Fără array-ul `_tinute`, tot ecranul ar fi fost o pierdere de timp. Verificat: după preîncărcare, `load("res://main.tscn")` durează **0 ms**.

**Încărcare SINCRONĂ, cu buget de ~10 ms pe cadru — nu `load_threaded_request`.** Ambele motive sunt măsurate, nu presupuse:
1. cu mai multe cereri în paralel, două fire ajung deodată la aceeași dependință, iar `preload()` dintr-un script care tocmai se compilează cade cu „Could not preload resource file" — și **scriptul rămâne STRICAT în cache tot restul rundei**. S-a întâmplat cu `egt.tscn` / `egts.gd`.
2. cu o singură cerere pe rând ridici cel mult un fișier per cadru, adică 16 ms de fișier degeaba: **728 de fișiere ajungeau la ~11 s**, deși citirea lor durează sub 3.

**Cele 120 de cadre de fundal ale meniului se țin DOAR până se deschide meniul.** Sunt 1920×1080 fiecare, ~70 MB de memorie de textură singure. Se preîncarcă (de-asta meniul apare instant, nu cu o proptire), dar li se dă drumul patru cadre după schimbarea scenei — moment în care le ține meniul însuși. Deci în timpul rundei nu costă nimic. **Regula: în `TEMPORARE` intră doar artă care se vede EXCLUSIV în meniu**; orice se poate cere în timpul unei runde trebuie ținut permanent. Costul total rămas: ~88 MB textură + ~17 MB RAM.

**🐛 A scos la iveală două fișiere moarte:** `bullet2.tscn` și `bullet3.tscn` cer `bullets/bullet2.png` / `bullet3.png`, care nu mai sunt pe disc, iar niciun `.gd` nu le mai folosește (verificat cu grep). Sunt sărite pe nume în `IGNORATE` ca să nu umple consola cu roșu la fiecare pornire — dar ar trebui pur și simplu șterse. **Nu le-am șters eu: sunt fișierele lui.**

**Verificat rulând:** poze pe parcursul încărcării (bara la 29%, apoi meniul complet, cu butoanele intrate în cadru), pornire din scena principală reală fără nicio eroare în consolă, și măsurători înainte/după (1,9 s, +17 MB RAM, +160 MB textură cât ține meniul cadrele lui, ~88 MB după).

---

## Session log — 2026-08-05 (a cincea armă — THROWING KNIFE — și un bonus de nivel pentru fiecare armă)

**Cerut de Răzvan:** „Bag o arma noua - throwing knife ai poza unde sunt si celelalte - vreau sa adaug o chestie pentru fiecare arma. La fiecare nivel fiecare arma are un bonus specific." (cuțit +1% crit, coasă +1% size, sabie +1% damage, pistol +1% attack speed, mage +1% luck).

**1. Throwing Knife** (12 damage, 0.55s → 1,82 lovituri/s: cea mai deasă și cea mai slabă). Proiectilul e CHIAR iconița din meniu, învârtindu-se în zbor. `bullet.gd` a primit un câmp `spin` care rotește **sprite-ul**, nu nodul — `rotation`-ul nodului e direcția de zbor, citită și de urmărire, și de hitbox-ul-capsulă. **Nu are scenă proprie**: e `bullet.tscn` cu altă poză pe `Sprite2D`, exact ca sfera mage, deci primește pe gratis străpungerea, ricoșeul, urmărirea, Thunder God și Jean's Bomb. Fără fulger la țeavă (n-are țeavă) și cu șuieratul de lamă al săbiei în loc de împușcătură.

**2. Bonusul de nivel al fiecărei arme.** Cuțit +1% crit, sabie +1% damage, pistol +1% attack speed, coasă +1% weapon size, mage +1 noroc. Se numără de la nivelul 1 (nivelul 12 = +12%).

**Nu se scrie nimic în stat-uri** — fiecare bonus se CALCULEAZĂ la folosire, lângă statul de care ține (`crit_chance_now`, `damage_mult`, `fire_interval_now`, `weapon_size_scale`, `luck_total`), exact regula pe care o urma deja `damage_mult()`. Scris în stat ar fi însemnat să scazi bonusul vechi și să-l aduni pe cel nou la fiecare level up, și s-ar fi stricat în tăcere la primul upgrade care înmulțește statul.

**Attack speed e excepția care are nevoie de un ghiont:** trăiește într-un `Timer`, nu într-un getter, deci `_seteaza_cadenta()` se cheamă la fiecare level up (și din `upgrade_fire_rate`). Reperul panoului (`_stats_base["fire_interval"]`) e valoarea DERIVATĂ, ca la `weapon_size` — altfel pistolul ar fi arătat o săgeată verde permanentă la Attack Speed, pentru un bonus pe care nu l-ai câștigat încă.

**NOROCUL e excepția care nu e procent.** E un număr de puncte, iar 1% din zero e nimic — deci Mage Staff ia **+1 noroc/nivel**. Un punct de noroc face 0,4 puncte procentuale la toate șansele din joc (`LUCK_CHANCE_PER`), deci iese pe-aproape de celelalte ca putere. Trece printr-un `luck_total()` nou, citit de `luck_bonus()`, de panou ȘI de `levelup.gd::_norocul_meu` — deci înclină și **rarităţile**, nu doar șansele itemelor.

**Criticul cuțitului a trebuit să treacă de o pază veche:** `crit_chance_now()` întorcea 0 sec dacă n-ai niciun item de crit, tocmai ca norocul să nu-ți strecoare o mecanică pe care n-ai ales-o. Bonusul armei ESTE acea mecanică, deci contează ca „ai una".

**Bonusul se și VEDE**, scris sub numele fiecărei arme în CHOOSE WEAPON, în toate cele 9 limbi — altfel ar fi fost o mecanică despre care jucătorul n-avea de unde să afle. ⚠️ Textele sunt scrise de mână în `menu.gd::WEAPONS`: schimbi `BONUS_PE_NIVEL` fără să le schimbi și meniul minte în tăcere.

**Verificat rulând:** toate cele cinci arme la nivelurile 1/10/20 — pistol 1,35 → 1,60 lovituri/s, sabie ×1,01 → ×1,20 damage, coasă 101% → 120% mărime, mage 1 → 20 noroc, cuțit 1% → 20% crit, iar la fiecare armă restul cifrelor neclintite; plus o poză cu cuțitele în zbor (se rotesc, unghiuri diferite) și una cu meniul de arme cu cinci sloturi. `tool_check_i18n` trecut.

**CODEXUL a fost actualizat și republicat** pe același URL: rând nou pentru Throwing Knife și o coloană nouă, „La fiecare nivel", în tabelul ARME, plus notele de la Crit/Luck/Weapon Size. Cifrele s-au scos RULÂND o scenă care instanțiază player-ul cu fiecare armă și tipărește `stat_lines()`, cu `GameSettings.upgrades` golit doar în RAM (și pus la loc; am verificat cu `md5sum` că `scores.save` a rămas neatins).

**⚠️ Codexul mințea de mult la Move Speed: scria 215, adevărul e 250.** 215 e valoarea implicită din `player.gd`, dar `player.tscn` o suprascrie cu 250 — deci cine citește doar scriptul ia cifra greșită. Regula pentru viitor: **statusurile de start se citesc din scena rulată, nu din `@export`-urile scriptului.** Corectat în codex.

---

## Session log — 2026-08-05 (cinematica lui Celesto, refăcută: îngheț + zoom + teleportări; bara sus; creaturile lui în lumea normală)

**Cerut de Răzvan:** „ca si cutscene pentru celesto, cand intrii in ender se opreste totul si se da zoom in pe el cum se teleporteaza stanga dreapta de 2-3 ori si vreau ca bara de hp si numele sa fie sus. Si vreau si inamicii de la celesto sa se spawneze in lumea normala dupa ce l-ai batut".

**1. Cinematica (`ender.gd`), cinci bătăi:** îngheț real (`get_tree().paused`) → camera intră pe locul gol de deasupra ta și strânge zoom-ul ×2 → Celesto se materializează acolo → bara COBOARĂ din marginea de sus → se teleportează stânga-dreapta de 3 ori în cadrul strâns → se stinge, camera iese, jocul repornește, el te așteaptă în inel și abia atunci curg inamicii.

**Camera NU îl urmărește la sărituri** — stă pe centru, el clipește în stânga și în dreapta ei. Dacă l-ar urma, s-ar vedea lumea mișcându-se, nu el; teleportarea ar dispărea din cadru.

**Îngheț: același tipar ca la `saratalin.gd::_cinematica_faza2`** (citește-o întâi, e referința). Trei precauții, toate obligatorii: nodul Ender pe `PROCESS_MODE_ALWAYS` (altfel îi stau tween-urile), `Fx` coborât pe `PAUSABLE` (e autoload ALWAYS, altfel plutesc numere de damage peste cadrul înghețat), `position_smoothing` al camerei stins (se calculează în procesarea EI, care nu merge pe pauză → camera ar rămâne blocată). **Plus una nouă: și BOSS-ul primește ALWAYS** — e adormit, dar sclipirea lui albastră de teleportare e un tween al lui și ar îngheța la mijloc, în albastru. La final îi pun `INHERIT` la loc.

**Două capcane de pauză, ambele cu jocul înghețat ca preț al greșelii:**
- un `Tween` FĂRĂ nicio comandă se anulează singur și nu-și mai trimite `finished` → `await`-ul ar aștepta la nesfârșit. De-asta prima bătaie are un `tween_interval` de siguranță, chiar dacă lipsesc camera și sprite-ul.
- `_cut_activ` ține `_process`-ul nostru mut: suntem ALWAYS, deci am fi ajuns acolo DEȘI jocul e pe pauză, și cronometrul Ender-ului ar fi curs în timpul filmulețului — adică ai fi plătit spectacolul din cele 6 minute.

**Anunțul „THE ENDER" a fost mutat la CAPĂTUL cinematicii.** Bannerul HUD-ului e un tween al unui nod pauzabil: pornit la intrare, îngheța la jumătatea „pop"-ului și rămânea așa, pe jumătate transparent, peste tot filmulețul.

**2. Bara de boss e SUS (`boss_bar.gd`), pentru TOȚI boșii, nu doar Celesto.** `DE_JOS` → `DE_SUS = 96`, ancorele de sus, iar intrarea cinematică coboară în loc să urce. **Numele stă SUB bară**, nu deasupra: sus-centru e deja ocupat de cronometrul rundei (44px de la y=14) și de al Ender-ului (64px de la y=8), care coboară până pe la y≈85. Dacă mai adaugi ceva sus-centru, verifică-le pe toate trei — se suprapun în tăcere.

**3. Creaturile Ender-ului în lumea normală (`spawner.gd`).** Exact tiparul lui `nether_share`: `ender.gd` aprinde un `celesto_invins` PUBLIC care — spre deosebire de `_boss_invins`, care doar ține fântâna închisă — **nu se stinge la ieșire**, iar `_scena_inamic()` îl citește și face `ender_share` (0.15) din spawn-urile lumii normale creaturi Ender. Ținut mic dinadins: sunt cei mai duri inamici obișnuiți din joc (380 viteză, damage dublu). Felia Ender se ia DUPĂ cea Nether, ca cele două să nu se bată pe aceiași inamici.

**Verificat rulând:** opt poze pe parcursul cinematicii (harta chiar goală și înghețată cât ține, zoom-ul, bara sus cu numele sub ea, ambele capete ale săriturilor, inamicii abia după); și 4000 de trageri la zar înainte/după uciderea boss-ului — 0% creaturi Ender înainte, 15,2% după, cu raportul polițist/Skinny neatins dedesubt.

**⚠️ Capcană de TESTARE, m-a prins pe loc:** dacă montezi `main.tscn` ca fiu al unui nod de test pus pe `PROCESS_MODE_ALWAYS`, tot jocul moștenește ALWAYS și `get_tree().paused` nu mai oprește nimic — primele poze arătau inamici alergând „pe pauză". Nodul de test n-are nevoie de ALWAYS: `create_timer(..., true)` și `RenderingServer.frame_post_draw` reiau corutina oricum.

---

## Session log — 2026-08-05 (POLICE SKINNY — al doilea polițist, de după minutul 1)

**Cerut de Răzvan:** „ti-am facut un folder in homeless directii - se numeste Police Skinny, o sa fie alt enemy putin mai rapid si mai strong decat faceless police officer in lumea normala, vreau sa se spawneze dupa ce trece 1 minut in lumea normala".

**Arta:** 8 GIF-uri `Idle_running-6-frames_<directie>.gif`, 128×128 — exact convenția pe care o mănâncă `tool_taie_gifuri.ps1`. Tăiate cu el (`-Prefix run`) în 48 de PNG-uri în `homeless directii/Police Skinny/frames/`, apoi `--headless --import`, altfel nu se încarcă la rulare.

**Scena nouă `enemy_police_skinny.tscn`** — același `enemy.gd`, fără `.tres`: folosește mecanismul `frames_dir` / `frames_count` / `frames_fps` apărut odată cu inamicul din Ender, deci zero UID-uri scrise de mână. `speed = 160` (față de 120), `max_hp = 45` (față de 30), `damage_mult = 1.3`, `frames_fps = 14` (față de 12, fiindcă aleargă).

**Mărimea, în patru trepte, toate în aceeași zi.** Întâi a rămas cea a polițistului (`scale` 1.5, `stop_dist` 41), fiindcă desenele sunt cât se poate de egale — măsurat, nu ghicit: 36×61 px din pânza de 128 la Skinny, 37×61 din cea de 124 la polițist. Apoi „fa-i pe astia cu 1.5x mai mari" → **2.25** (1.5 × 1.5). Apoi „fa politistu skinny putin de tot mai mic" → **2.1**. Apoi Răzvan a deschis scena în editor și a coborât-o el la **1.8**, unde a rămas. Tot cel mai mare inamic obișnuit din joc.

**`stop_dist` merge după DESEN, nu după scenă: 41 → 54 → 53 → 47.** Formula e mereu aceeași: jumătate din lățimea desenată (36 px × `scale`) + jumătatea player-ului (15). La 1.8 iese 47. Dacă mai umbli la `scale` din editor, adu-l și pe ăsta după, altfel ori intră peste player, ori se oprește cu o dungă de gol în față.

**54 e plafonul dur**, nu o rotunjire: `enemy.gd::_oprire()` taie `stop_dist` la `contact_range` (60) − `STOP_MARGINE` (6) și te avertizează în consolă, fiindcă un inamic care se oprește mai departe decât brațul player-ului n-ar mai apuca niciodată să-l lovească. Deci Skinny nu poate trece de ~2.25 fără să urci întâi `contact_range`-ul player-ului.

**Spawn-ul (`spawner.gd`):** funcție nouă `_politist()`, chemată în cele două locuri din `_scena_inamic()` care returnau `ENEMY`. Două butoane noi: `skinny_after` (60s) și `skinny_share` (0.35). Ca la `nether_share`, **nu se schimbă CÂȚI inamici apar, ci CINE sunt** — primul minut rămâne identic cu ce era. Se numără pe `Difficulty.time`, care stă pe loc în Limbo și în Nether, deci e chiar „un minut în lumea normală". Și, fiind polițist, intră și el în îngroșarea de după Nether (`escaped_power_mult`) — de-asta condiția de acolo a devenit `scena == ENEMY or scena == ENEMY_SKINNY`.

**Verificat rulând:** 4000 de trageri la zar pe fiecare moment → 0% skinny la 30s și la 59s, 35,4% la 61s, 34,7% la 300s; poză cu cei doi polițiști unul lângă altul (ambii cu 8 animații × 6 cadre, hp 30 vs 45, speed 120 vs 160); și `main.tscn` rulat întreg, fără nicio eroare și fără avertismentul de cadre lipsă. Scenele de test au fost șterse.

---

## Session log — 2026-08-04 (umbra fântânii Ender, a doua oară: inel în jurul tălpii)

**Cerut de Răzvan:** „tot nu e facuta umbra bine, fa fix inconjuru ei, adica umbra trebuie pusa mai sus si mai mare", cu o captură nouă în `debugging/`.

**Ce lipsea în reglajul de dinainte** (dunga de contact, `1.00` / `squash` 0.18 / `shift_y` -3): plecam de la ideea că umbra e o baltă sub un punct de sprijin, ca la copaci, și o lipeam de botul de jos al pietrei. Dar fântâna e un BUTOI: umbra ei nu e o pată, e **cercul pe care stă**, umflat puțin.

**Măsurat, nu ghicit** — silueta texturii, rând cu rând, în banda de jos: talpa e o elipsă lată de ~72 px și înaltă de ~26 (marginile din lateral la `y=99`, botul din față la `y=112`). Deci turtirea ei reală e **0.36**, nu 0.18, iar centrul ei stă cu **~33 px** (în coordonatele nodului) mai sus decât `base_y`, care e chiar botul. Cifra de dinainte (`shift_y = -3`) punea centrul elipsei fix pe bot, deci toată umbra ieșea în JOS, pe iarbă — exact pata pe care o vedea el.

**Ce e acum:** `shadow_width` 1.15, `shadow_squash` 0.42, `shadow_shift_y` -33. Centrul umbrei pe centrul tălpii, elipsa puțin mai mare decât ea → rămâne un inel egal în stânga, în dreapta și în față, iar partea de sus intră firesc sub piatră. Asta e „fix înconjuru ei".

**`halo_scale` 1.7 → 1.5** ca haloul violet să rămână LA FEL de lat ca înainte (1.00×1.7 ≈ 1.15×1.5). E înmulțit cu `shadow_width`, deci fără corecție ar fi crescut și el cu 15% degeaba. Alfele lui n-au fost atinse.

**Verificat rulând:** patru variante una lângă alta pe iarba din captura lui (cea veche + trei mărimi), apoi vechi-vs-nou pe podeaua Ender-ului, ca haloul să nu piardă din ancoră dincolo — nicio diferență în rău acolo. Scena de test a fost ștearsă.

---

## Session log — 2026-08-04 (Cigarette Pack „nu dă nimic": panoul mințea, itemul mergea)

**Raportat de Răzvan:** „nu merge itemu de 5% damage increase, nu iti da nimic".

**Itemul funcționa.** Măsurat cu pistolul, pe un manechin, cu criticul pus pe 0: **24 → 25 → 26 → 28** damage pe lovitură la trei luări consecutive, exact `bullet_damage × (1 + 0.05·n)` rotunjit.

**Ce era stricat era PANOUL.** `stat_lines()` afișa `bullet_damage` gol, iar Cigarette Pack nu scrie în el: e procent, ținut în `cig_bonus` și aplicat în `damage_mult()` la fiecare lovitură (dinadins — +5% peste un damage ÎNTREG s-ar rotunji urât, 10 × 1.05 → 11, adică +10%). Deci luai itemul, te uitai în panou, scria aceeași cifră, și concluzia normală era „nu face nimic".

**Fix:** rândul „Damage" arată acum `bullet_damage × damage_mult()`, adică fix cât intră în inamic. Aceeași regulă pe care panoul o aplica deja la Crit și Instakill, afișate de mult cu norocul inclus (`*_now()`): **în panou scrie ce face arma ACUM**, nu ce scria pe ea la începutul rundei. Verificat: panoul arată 24 → 25 → 26 → 28, cifră cu cifră aceleași ca damage-ul dat, și cu săgeata verde.

Theo's Wrath și Diesel Power intră și ele în rândul ăsta, dar numai când sunt aprinse (sub 20% viață / în mers). Pe ecranul de level up stai pe loc și de obicei cu viața plină, deci panoul arată cinstit că atunci nu-ți dau nimic — ceea ce e și scris pe iteme.

**De reținut pentru raportări viitoare:** un item procentual care nu scrie într-un stat e INVIZIBIL în panou dacă panoul afișează statul brut. Dacă mai apare unul, se adaugă la fel în rândul lui, nu se mută efectul în stat.

---

## Session log — 2026-08-04 (inamicul Ender-ului + cinematica de intrare a lui Celesto)

**Cerut de Răzvan:** „ti-am pus ce inamic vreau sa apara in ender, vreau sa fie de 2x mai rapid si sa dea damage de 2x mai mult decat cei din nether, dupa o sa apara si ei in lumea normala. Vreau ca Celesto sa aiba un cutscene cand intrii in ender, nu sa se spawneze direct, si vreau sa intre in cadru bara de hp cu numele lui asa slow cinematic."

### Inamicul din Ender
**Arta:** 8 GIF-uri (toate direcțiile, nimic de oglindit), tăiate cu `tool_taie_gifuri.ps1` în `harta/Portal Ender/enemy ender/frames/` — 8 direcții × 8 cadre de 124×124.

**⚠️ Damage-ul de contact NU se putea dubla, pur și simplu nu exista mecanica.** Până acum venea DOAR din statul `contact_damage` al player-ului × dificultate, deci era identic pentru orice inamic de pe ecran (scrie negru pe alb în comentariul vechi din `enemy.gd`). Am adăugat `@export var damage_mult` pe inamic, iar `player._take_contact_damage` îl citește **per inamic** — socoteala s-a mutat în buclă. Creatura Ender are 2.0, restul 1.0.

**Cadrele se construiesc la RULARE**, dintr-un `frames_dir` pus în scenă: 64 de poze separate ar fi însemnat un `.tres` cu 64 de UID-uri scrise de mână. Mecanismul e pe `enemy.gd`, deci îl poate folosi orice inamic viitor — inclusiv când or ajunge ăștia în lumea normală, cum a zis.

**Unde apar:** `spawner.gd` îi dă în Ender (în loc de creaturile Nether), `ender.gd` îi varsă la intrare, iar Celesto îi cheamă în faza 2. Viteză 380 (Nether are 190), viață 50 ca ei.

### Cinematica
Trei bătăi, fără pauză de joc: **se materializează** deasupra ta (transparent → opac, 1.1s, cu sunetul lui de teleport) → **bara urcă încet** din marginea de jos cu numele aprinzându-se odată cu ea (1.7s) → **dispare** și reapare în inelul lui obișnuit, iar atunci curge valul de inamici și începe lupta.

**De ce NU pun jocul pe pauză:** ar trebui scoase de sub pauză `_process`-ul Ender-ului (cronometrul tocmai a pornit), spawner-ul și dificultatea — trei lucruri de ținut minte pentru trei secunde de spectacol. În loc de asta, liniștea vine din faptul că **valul de 20 de inamici e amânat**: cât ține cinematica, harta chiar e goală (mai pică 2-3 din spawner-ul obișnuit, ceea ce arată bine).

**`boss_bar.gd` a primit `arata_cinematic(nume, hp_max, durata)`** — scrisă general, o poate chema orice boss. Mișcă `_radacina` (containerul), NU barele: ele sunt ancorate de marginea de jos cu offset-uri fixe, iar un `position` pus direct pe ele s-ar bate cu ancorele. Transparența urcă pe 75% din drum, ca bara să se materializeze pe măsură ce alunecă, nu să apară întreagă și apoi doar să se miște.

**Celesto doarme cât ține** (`adoarme()` chemat ÎNAINTE de `add_child`, altfel `_ready` apucă să ceară bara singur): nu se mișcă, nu atacă, nu-și cere bara. `trezeste()` îl pornește.

**⚠️ Încadrarea a trebuit schimbată după prima captură:** îl puneam „în direcția în care te uiți", dar la aterizare te uiți implicit în JOS, deci cădea fix peste bara care tocmai urca. Acum apare DEASUPRA ta — sus e curat și e oricum încadrarea clasică de apariție de boss.

**Verificat rulând:** viteză 380 vs 190 (raport exact 2.00), damage la contact **20 HP vs 10 HP** în ~1s cu același player, artă 8 direcții × 8 cadre. Cinematica, pe capturi: la 0.2s boss-ul e la 292px cu alfa 0.17 și doarme, la 1.4s e opac, la 2.6s bara alunecă (alfa 0.81, y +5), la 4.6s boss-ul e la 826px, treaz, bara sus și 24 de inamici pe hartă.

**⚠️ 88 MB de sunete au venit odată cu arta.** În folderul inamicului era un „400 Sounds Pack" (800 de fișiere) din care jocul nu folosește nimic — și pe care Godot începuse deja să-l importe (400 de `.import` generate, șterse). Are acum un `.gdignore` lângă el și e trecut în `.gitignore`: rămâne pe disc, dar nu intră nici în import, nici în istoric. Dacă vrea un sunet de acolo, se copiază în `audio/` și primește o linie în `audio.gd`.

---

## Session log — 2026-08-04 (STINGĂTORUL a fost scos din joc; sunetul lui trece la sabie)

**Cerut de Răzvan:** „pune sunetu de la extintor la cursed sword si sterge cu totu extintoru din joc".

**Sunetul:** în `audio.gd`, cheia `"sword"` arată acum spre `Extinguisher.wav`, iar cheia `"extinguisher"` a dispărut. **`Cursed Sword.wav` a rămas pe disc, nefolosit** — n-am șters-o, e sunetul lui; dacă vrea vechiul sunet înapoi, se schimbă o singură linie.

**Ce a plecat, tot dintr-o bucată:**
- `player.gd`: rândul din `ARME`, `_aura_pulse()`, `_spawn_aura_ring()`, `_build_foam_frames()`, `_make_radial_texture()`, exporturile `aura_base_radius / aura_growth / aura_damage / foam_scale`, `_aura_tex`, `_foam_frames`, ramura din `_fire()` și cea din burst;
- `menu.gd`: rândul din `WEAPONS`; `i18n.gd`: cheia `EXTINGUISHER` (cu tot cu cele 8 traduceri);
- de pe disc: `stingator/` (14 cadre de spumă + `.import`) și `weapons_icons/stingator.png`.

**Și comentariile.** Stingătorul era pomenit ca exemplu în vreo zece locuri care n-aveau treabă cu el (`bullet.gd`, `shockwave.gd`, `levelup.gd`, plafonul de mărime, Bloody Situation, burst-ul). Toate arată acum spre sabie sau spre coasă. Un comentariu care trimite la cod inexistent e mai rău decât niciunul.

**Verificat rulând o rundă cu FIECARE armă rămasă**, cu un manechin lipit de player: pistol 48, mage 90, sabie 74, coasă 45 damage încasat în 1.6s. Sunetul săbiei citește `Extinguisher.wav`, iar cheia `"extinguisher"` nu mai există. Meniul arată 4 arme, fără iconițe lipsă. Verificatorul de traduceri trece.

**Codexul e actualizat și republicat**: rândul de armă a dispărut din tabelul de start, iar cele patru locuri unde stingătorul era dat ca exemplu (Aimbot, Bloody Situation, Pufferfish, nota despre proiectile pe arme de corp la corp) arată acum spre sabie/coasă. Randat întâi în Chrome headless.

---

## Session log — 2026-08-04 (hitbox-ul coasei = chiar desenul ei, umflat cu 5px)

**Cerut de Răzvan:** „hitboxu la scythe nu e egal cu sprite-ul in sine, poti chiar sa il faci cu 5pixeli peste sprite daca arata mai ok asa".

**Avea dreptate de două ori.** Prima variantă lovea tot ce era într-un CERC PLIN de rază fixă în jurul player-ului, deși lama e o secere subțire: prindea inamici lipiți de tine, pe sub lamă, și alții de dincolo de vârful ei.

**Ce n-a mers, ca să nu se reîncerce:**
1. **Bandă circulară** (rază interioară + exterioară, scoase din înălțimea anvelopei): coasa e desenată pe DIAGONALĂ, deci desenul e înalt cât toată poza și banda ieșea 0→130, adică exact cercul plin de dinainte. Zero câștig.
2. **Dreptunghiul anvelopei, rotit cu lama** (metoda săbiei): mai bun, dar tot cuprinde cele două colțuri goale ale diagonalei — aproape dublul suprafeței. Se vedea pe captură cum chenarul roșu prinde iarbă curată.

**Ce e acum: CÂMP DE DISTANȚE.** La pornire se calculează o dată, din poză, cât are fiecare pixel până la cel mai apropiat pixel DESENAT (chamfer în două treceri, cost liniar, eroare sub un pixel). Întrebarea „lovește?" devine: aduc inamicul în sistemul artei și citesc din tabel. Hitbox-ul e **chiar desenul**, umflat cu `scythe_marja` (5px, cât a cerut el) plus raza corpului inamicului. O citire per inamic per cadru.

**⚠️ Și a ieșit la iveală un bug pe care nu-l vedeam:** lama era așezată după axa Y a POZEI, dar coasa e desenată pe diagonală, deci ea „arăta" cu ~40° pe lângă raza pe care mătura turul. Măsurat: inamicul din spatele tău, **de unde pornește măturatul, era prins ULTIMUL**, după un tur întreg. Acum axa se scoate din poză și lama cade de-a lungul razei.
- Axa NU e centrul de greutate al pixelilor: la coasă el cade aproape fix în mijlocul pozei, deci direcția lui e zgomot curat — încercat, tot 40° pe lângă. E **axa principală** (matricea de împrăștiere a pixelilor, `theta = ½·atan2(2·Sxy, Sxx − Syy)`), adică direcția în care desenul e cel mai lung.
- Sensul îl alege jumătatea cu mai mulți pixeli: la coasă lama e mai grasă decât coada, deci ea iese în afară, cum și trebuie (coada rămâne în mână).

**Verificat rulând:** ordinea turului e acum cea corectă — **180° (de unde pornește) la 0.007s, 270° la 0.070s, 0° la 0.153s, 90° la 0.237s**, pe un tur de 0.34s. Vin puțin înaintea sferturilor exacte fiindcă lama are lățime: te atinge înainte să ajungă axa ei peste tine — exact ce înseamnă „hitbox după desen". Un manechin la 170px rămâne neatins; la 10, 45, 91 și 125 px, loviți.

**`scythe_debug`** (ca `sword_debug`) desenează peste joc: cerc subțire = cât de departe ajunge vârful, cerc roșu gros pe fiecare inamic aflat **chiar atunci** sub lamă. N-am desenat „forma hitbox-ului" fiindcă nu e o formă geometrică, e desenul — deci se desenează rezultatul, care e oricum ce vrei să verifici.

---

## Session log — 2026-08-04 (armă nouă: COASA LUI CELESTO, măturat 360°)

**Cerut de Răzvan:** „vreau sa mai adaug o arma in joc, scythe-u lu celesto." Cum atacă a ales el, întrebat: **măturat 360° în jurul player-ului** (variantele respinse: bumerang și coase care orbitează).

**Ce e:** a cincea armă (`scythe`), a treia de corp la corp. La fiecare atac, lama lui Celesto face un TUR COMPLET în jurul tău. Rază fixă și scurtă (130px), damage întreg (`bullet_damage + scythe_base_damage` = 24 + 12 = 36 la start), cadență cea mai rară din joc (0.95s → 1.05 lovituri/s).

**⚠️ Lovește PE MĂSURĂ CE LAMA AJUNGE la fiecare, nu pe toți deodată** — asta e deosebirea de STINGĂTOR, care pulsează un cerc și lovește tot ce prinde în aceeași clipă. Turul pornește din SPATELE tău, ca lama să treacă întâi prin fața ta (acolo te uiți, acolo ai inamicii).

**Cum se decide „a ajuns la el", fără capcana unghiurilor:** se ține `parcurs`, câți radiani a măturat lama de la start (crește de la 0 la TAU, deci doar crește). Pentru fiecare inamic se calculează unde stă pe cerc **față de unghiul de pornire**, adus în [0, TAU) cu `wrapf`. Dacă `parcurs` a trecut de el, l-a prins. Comparație între numere care doar cresc, deci nu există „a sărit peste el" la trecerea prin 360°.

**Lovitura de corp la corp e acum ÎNTR-UN SINGUR LOC** (`_lovitura_melee`): instakill (Hacksaw), damage, numărul care sare, curentul lui Thunder God, knockback. Era scrisă în `_sword_damage_pass`; am scos-o afară când a apărut coasa, ca cele două să nu poată ajunge cu reguli diferite. Sabia a fost **re-verificată după mutare**: 37 damage în față, 0 în spate (corect — ea taie doar înainte).

**Arta:** aceeași poză pe care o aruncă Celesto (`celesto throw.png`), și ca lamă în joc, și ca iconiță în meniu — luată direct din folderul boss-ului, nu copiată în `weapons_icons/`. E aceeași armă, deci o singură poză pe disc.
- **Mărimea:** 150px lățime, la rază × 0.8. Prima variantă (104px, fără tentă) era aproape invizibilă pe iarbă — văzut pe captură. Acum are aceeași tentă ca proiectilul lui Celesto (`Color(1.15, 1.05, 1.35)`), fiindcă lama e aproape neagră.
- Raza cercului crește cu Pufferfish/Rat's Burger ca orice armă, iar **din ea iese și mărimea lamei** — desenul și zona lovită nu se pot despărți.

**Verificat rulând:** cu player-ul uitându-se spre EST și manechine în cele 4 zări, lovitura vine la **0.010s (vest, de unde pornește) / 0.085s / 0.171s / 0.255s**, exact sferturile turului de 0.34s. Un manechin la 400px rămâne neatins. Meniul: 5 arme, rândul are 813px pe un ecran de 1152 — încap.

**⚠️ CAPCANĂ NOUĂ, prinsă pe pielea mea:** un test care schimbă ceva în `GameSettings` **doar în RAM** și apoi pornește `main.tscn` poate să-l scrie în salvarea REALĂ — jocul cheamă `_save()` de la sine, iar `_save()` scrie TOATE valorile din memorie. Așa mi-a rămas `op_start = true` în salvarea lui Răzvan de la testul de dimineață; l-am pus la loc pe `false` (monedele și scorurile intacte, verificate). Regula: în teste ori nu atingi `GameSettings` înainte să pornești jocul, ori pui valoarea înapoi ȘI salvezi.

**Codexul e actualizat și republicat** (aceeași adresă): rând nou în tabelul „Ce depinde de arma aleasă" — Celesto's Scythe, 24, 1.05/s, 36 pe măturat. Cifrele NU sunt scrise de mână: rulate cu `GameSettings.upgrades` golit în RAM, ca să nu prindă magazinul permanent al lui Răzvan. Verificat întâi în Chrome headless (pagina se randează, nu e albă), fiindcă tot conținutul ei vine din JS.

**i18n:** un singur text nou, „CELESTO'S SCYTHE", în 8 limbi. Verificatorul trece.

---

## Session log — 2026-08-04 (umbra fântânii Ender: dungă de contact, nu baltă)

**Cerut de Răzvan:** „e proasta umbra la portalu de ender", cu o captură în `debugging/`.

**Ce era:** elipsa era împinsă SUB talpă (`shadow_shift_y = +10`) și puțin mai lată decât piatra (`1.02`, `squash` 0.26). Jumătatea ei de jos ieșea pe iarbă ca o baltă mare și moale, iar fântâna părea că plutește peste o pată de murdărie. Măsurat pe captura lui: pata avea ~184×32 px pe ecran, sub o fântână de ~190px.

**De ce era împinsă acolo:** ca să se VADĂ. Fântâna e un butoi rotund, lat cât toată silueta — nu un copac cu trunchi subțire — deci o elipsă centrată pe talpă îi stă întreagă ascunsă în spate. Verificat pe capturi: la `0.86` abia se ghicește, la `0.74` nu se mai vede deloc. Deci „mai îngustă" nu era răspunsul.

**Ce e acum:** elipsă cât piatra (`1.00`), TURTITĂ mai tare (`squash` 0.18) și trasă puțin ÎN SUS (`shift_y = -3`), cu alfa 0.45. Rămâne o dungă de contact lipită de baza pietrei — spune „stă pe pământ" fără să murdărească iarba. Arată ca umbra mestecenilor de lângă ea, ceea ce e și ideea.

**Haloul violet NU e vinovat și n-a fost atins.** Am pus una lângă alta aceeași fântână cu haloul la 0.16 și la 0.09, pe aceeași iarbă: nu se deosebesc. Coborât degeaba, s-ar fi stins și în ENDER, unde el e ancora (podeaua e nebuloasă aproape neagră, iar negru pe negru nu se vede). Deci `halo_alpha_lume`, `halo_scale` și tot ce ține de dimensiune au rămas cum erau.

**Reglat pe capturi, nu din cap:** scenă temporară care punea fântâna lângă player pe iarbă și scotea câte o poză per set de cifre (5 variante + comparația de halou), decupată în jurul ei. Fără asta, „mai mică" ar fi însemnat invizibilă și n-aș fi știut.

---

## Session log — 2026-08-04 (OP START: comutator de testare în colțul meniului)

**Cerut de Răzvan:** „un buton in meniu langa cel de limba si setari pentru OP Start - Vreau sa am 100 damage, 2.5 attack speed, 10 proiectile. Si sa pot sa ii dau on/off".

**Ce e:** al treilea buton din colțul dreapta-sus, „OP", lângă steag și rotiță. Deschide o pagină care scrie ce primești (Damage 100 · Attack Speed 2.50/s · Projectiles 10) și are un ON/OFF. Butonul din colț se face **verde** cât e pornit, deci starea se vede din meniul principal, fără să intri.

**De ce pagină și nu comutare directă din colț:** ar fi trebuit să ții minte trei cifre invizibile, iar toate celelalte butoane din colț deschid pagini. Așa se vede negru pe alb ce dă cheat-ul.

**Cifrele stau în `game_settings.gd`** (`OP_DAMAGE`, `OP_ATTACK_SPEED`, `OP_PROJECTILES`), nu în `player.gd`: le citesc amândoi — meniul le AFIȘEAZĂ, player-ul le APLICĂ. Scrise în două locuri, prima reglare ar fi făcut pagina să mintă.

**„2.5 attack speed" nu se poate pune direct:** player-ul lucrează cu `fire_interval`, adică PAUZA dintre atacuri. Butonul e scris în atacuri pe secundă (cum arată și panoul de statusuri din joc), iar `player.gd` întoarce cifra: `fire_interval = 1 / 2.5 = 0.4s`.

**`_aplica_op_start()` SCRIE, nu adună**, și se cheamă **ULTIMUL** — după `_aplica_arma()` și `_apply_meta()`. Dacă ar aduna, rezultatul ar depinde de armă și de ce ai cumpărat din magazin, iar butonul n-ar mai însemna aceleași trei cifre de fiecare dată. Se citește o singură dată, în `_ready()`: pornit în timpul unei runde, se vede abia la următoarea — și așa și trebuie, e „OP **start**".

**i18n:** singurul text nou e titlul „OP START" (8 limbi; „OP" rămâne OP peste tot, e jargon de jucători). Restul erau deja traduse: `ON`, `OFF`, `BACK`, iar numele rândurilor — `Damage`, `Attack Speed`, `Projectiles` — sunt **exact cheile din panoul de statusuri din joc**, refolosite intenționat, ca pagina să vorbească aceeași limbă cu jocul. „OP" (textul butonului) și „opstart" (cheia paginii) sunt în `IGNORATE`. Verificatorul trece: 222 chei × 8 limbi.

**⚠️ Textul ON/OFF se scrie în ENGLEZĂ pe buton, nu prin `tr()`** — Godot traduce singur ce e pe un Button, inclusiv textul pus din cod. Cu `tr()` acolo ar fi ajuns în buton un text DEJA tradus, care n-ar mai fi urmat schimbarea limbii. Aceeași soluție ca la `settings_ui.gd::_on_toggle`.

**Marginile butonului din colț** sunt strânse la 4px (`_sb_stramt`): cu cele obișnuite (14 lateral) rămâneau 24px din cei 52 ai butonului și „OP" ieșea tăiat. Aceeași problemă și aceeași rezolvare ca la butonul-steag.

**Verificat rulând meniul și apoi o rundă:** butonul apare la (960, 16), comută OFF→ON→OFF, iar cu OP pornit player-ul raportează **damage=100, attack speed=2.50/s, proiectile=10, timer de tragere 0.4s**. Testul a apăsat de DOUĂ ori și a pus steagul direct (nu prin `set_op_start`) când a pornit runda, ca să nu scrie în salvarea reală a lui Răzvan — `set_op_start` cheamă `_save()`.

---

## Session log — 2026-08-04 (conturul lui Celesto și al coasei: 1 pixel de ECRAN, din shader)

**Cerut de Răzvan:** „outline-u lu celesto vreau sa fie de 1px si la atacu pe care il arunca la fel".

**Era deja 1px — dar 1px DIN POZĂ.** `tool_celesto.gd` cocea conturul în PNG-uri, iar `celesto.tscn` afișează sprite-ul la `scale = 3.2`: pe ecran ieșea un chenar de 3 pixeli. Nu exista variantă de copt mai subțire (sub 1 pixel de poză nu se poate desena), deci **conturul s-a mutat din poză în shader**: `contur_1px.gdshader`, pus pe `AnimatedSprite2D` din `celesto.tscn` și pe `Sprite2D` din `scythe.tscn`. `celesto.gd` citește acum `frames/`, nu `frames_contur/` (altfel s-ar aduna 3px copți + 1px desenat).

**Cum știe shaderul cât e „un pixel de ecran":** din derivata lui UV — `dFdx(UV)`/`dFdy(UV)` spun cât se schimbă UV când te muți un pixel pe ecran, chiar acolo. Deci grosimea rămâne 1px **la orice scale al sprite-ului și la orice zoom al camerei**, ceea ce rezolvă din prima și coasa uriașă din faza 3 (`marime = 3.0`): un contur copt s-ar fi mărit și el de 3 ori, iar cele două coase n-ar mai fi arătat a aceeași armă.

**Nu `fwidth`**, deși ăla e reflexul: `fwidth = |dFdx| + |dFdy|`, iar coasa **se învârte în zbor** — pe diagonală suma aia e cu până la 40% mai mare decât realitatea, deci conturul s-ar fi îngroșat când se rotește. Se folosește lungimea gradientului per axă.

**⚠️ `MODULATE` NU EXISTĂ în canvas shader-ul din 4.7** („Unknown identifier in expression: 'MODULATE'", prins la prima rulare). Iar în `fragment()` `COLOR` vine deja înmulțit cu textura, deci n-ai de unde să scoți modularea curată. Soluția: un `varying` setat în `vertex()` (`modulare = COLOR`), folosit apoi în `fragment()`. Contează: fără el, conturul ar fi rămas aprins peste boss-ul care se stinge la moarte (tween pe `modulate`) și n-ar fi luat flash-ul de la lovitură.

**Verificat rulând** (scenă temporară, ștearsă): fereastră 1920×1080 (viewportul jocului e 1152×648, deci desenul e întins ×1,667 — dar shaderul lucrează pe fragmente, deci tot 1 pixel de fereastră iese). Pe 60 de rânduri prin Celesto: **379 de benzi de contur de exact 1px**; benzile de 6-7px sunt marginile ORIZONTALE, unde rândul de scanare merge PE LÂNGĂ contur, nu prin el. Coasa mică și cea de 3× ies la fel de subțiri (1-2px, din unghiul lamei) — adică exact ce se voia: conturul **nu** se scalează cu `marime`.

**Măsurătoarea a trebuit strânsă de două ori:** „ceva albăstrui" prindea și armura lui Celesto, și tăișul coasei (benzi false de 7-8px), iar coasa are `modulate = tint` (1.15, 1.05, 1.35), deci conturul ei apare pe ecran ÎNMULȚIT cu tint-ul — comparat cu albastrul curat, ieșea zero. Se compară cu `culoare * tint`, tăiat la 1.0.

**`frames_contur/` a rămas pe disc**, nefolosit de joc (unealta încă știe să-l genereze, ca să poți compara variantele). Dacă vrei, se poate șterge oricând — se reface dintr-o rulare.

---

## Session log — 2026-08-04 (CELESTO e boss-ul Ender-ului: coase, bumerang, teleportări, 3 faze)

**Cerut de Răzvan:** boss-ul se numește acum Celesto, apare invizibil în joc; să arunce cu coasa (`celesto throw.png`, pusă de el în folder), **unul dintre atacuri să fie o coasă aruncată în direcția OPUSĂ player-ului, care se întoarce ca un bumerang**; **part 2** — după ce-i iei un sfert de viață — se teleportează **la 8s, la 50px în spatele player-ului**, cu `Teleport.wav`; **part 3** — teleportare la 4s + o **coasă de 3× (sprite ȘI hitbox)** aruncată spre player la 10s, cu cutremur. Pragul fazei 3 (50%) și păstrarea invocărilor le-a ales el, întrebat.

**De ce era invizibil:** `executioner.gd` încă încărca foile din `Undead executioner puppet/`, folder șters de pe disc pe 3 august. Nu crăpa (doar `push_warning`), deci nimic nu-l trăgea de mânecă. **`executioner.gd` și `executioner.tscn` sunt ȘTERSE**; boss-ul e acum `celesto.gd` + `celesto.tscn`, iar `ender.gd` îl încarcă pe el.

**Arta:** 8 direcții × 8 cadre de mers din `Celesto/frames_contur/` (cele cu conturul albastru de 1px; `west` și `north_west` erau deja oglindite de `tool_celesto.gd` pe 3 august — mirroring-ul era făcut, legătura la cod lipsea). `SpriteFrames` se construiește **la rulare**, din fișiere separate, ca la creaturile Nether: 64 de UID-uri scrise de mână = 64 de șanse de „resource not found".

**⚠️ Are DOAR mers.** Fără cadre de atac, de invocare sau de moarte. Consecințe scrise în cod: lovitura NU mai așteaptă „cadrul ei" (ca la Saratalin/Executioner), pleacă în clipa deciziei, iar boss-ul stă pe loc `pauza_atac` (0.35s) ca să se vadă că a aruncat; moartea e un tween (se stinge și se umflă), nu o foaie.

**Proiectilul, `scythe.gd` + `scythe.tscn`** — o singură scenă, trei feluri, alese punând proprietăți ÎNAINTE de `add_child` (ca la `lightning.gd` — `_ready()` le citește o dată):
- dreaptă (atacul obișnuit + cercul de 12);
- **bumerang**: aruncată invers față de player, frânează, se oprește și se întoarce **țintind player-ul de ACUM**, nu unde era la plecare. Frânarea nu e o cifră din burtă: `a = v²/(2·rază)`, deci knob-ul rămâne „câți pixeli se duce". **Are viteza lui, 700** (nu 340): timpul până se oprește e `2·rază/viteză`, iar la 340 dusul singur dura 2,5s — armă pe care o uitai până se întoarce. La 700 → ~1,2s;
- **uriașă**: `marime = 3.0` aplicat ÎNTR-UN SINGUR loc (`_aplica_marime`), și pe sprite, și pe forma de coliziune, ca să nu se poată desincroniza.

**Teleportarea** e „în spate" față de unde se uită **PLAYER-UL** (`player.facing_dir()`), nu față de unde stă Celesto — deci dacă fugi, ți-l găsești pe urme. Sunetul e `Teleport.wav` **din folderul lui de artă**, nu din `audio/`: acolo l-a pus Răzvan, și dacă re-copiază folderul boss-ului vine și sunetul cu el (`audio.gd`, cheia `celesto_teleport`).

**Fazele** (praguri în procente, ca să însemne același lucru la orice rundă): 2 sub 75%, 3 sub 50%. `_intra_in_faza3` tratează și cazul în care o lovitură uriașă sare peste faza 2 — aplică și bonusurile ei, și anunță o singură dată.

**i18n:** textele boss-ului vechi (`THE PUPPET STILL DANCES`, `THE STRINGS ARE CUT`, `THE PUPPET PULLS ITS STRINGS`, `UNDEAD EXECUTIONER PUPPET`, `Kill the Executioner to leave`) au fost **înlocuite**, nu doar completate, cu cele noi (`CELESTO STILL STANDS`, `CELESTO FALLS`, `CELESTO VANISHES` + subtitlu, `CELESTO REAPS` + subtitlu, `Kill Celesto to leave`) — 8 limbi fiecare. „CELESTO" e nume propriu → e în `IGNORATE` din `tool_check_i18n.gd`, lângă „SARATALIN", iar `FISIERE_UI` arată acum spre `celesto.gd`. Verificatorul trece: *„221 chei × 8 limbi — TOTUL E TRADUS"*.

**Verificat rulând jocul** (scenă de test peste `main.tscn`, ștearsă după): artă 8 direcții × 8 cadre; bumerangul pleacă la 383px de player, se duce până la 679px și **se întoarce**; teleportarea aterizează la **50,0px de player și la 0,0px de punctul din spatele lui**, se declanșează singură de la 900px și își reîncarcă cronometrul la **8,0s în faza 2 și 3,9s în faza 3**; coasa uriașă: `marime=3.0`, scale sprite 2.10 = scale hitbox 2.10 (identice), damage 45. Capturi: Celesto lângă fântână (se vede conturul albastru pe nebuloasă) și coasa uriașă în zbor lângă una normală.

**⚠️ Două capcane prinse la rulare:** (1) `var x := -player.facing_dir() if ...` nu compilează — `player` e `Node2D` netipizat, deci `:=` n-are ce deduce, și **jocul nici nu pornește** (eroare de parsare, nu de rulare); tipul se scrie pe față. (2) Prima măsurătoare a teleportării a dat 19px în loc de 50: boss-ul MERGE spre tine imediat după ce aterizează, deci între teleportare și măsurătoare apucase să se apropie. Nu era bug în cod, era testul prost — se măsoară pe loc, cu apel direct.

**Mărimea pe ecran:** `scale = 3.2` pe `AnimatedSprite2D` (128×128 sursă). La 2.2, cât aveam la început, arăta cât o creatură obișnuită — verificat pe captură, nu din cap.

---

## Session log — 2026-08-04 (portalurile Nether DEVIN fântâni Ender după Saratalin)

**Cerut de Răzvan:** „portalele de ender vreau sa se spawneze in locul celor de nether cand bati pe saratalin".

**Ce era înainte:** după Saratalin, `nether.gd` ștergea toate portalurile, oprea generatorul (`oprit`) și punea **de mână O SINGURĂ** fântână în `World`, în gaura portalului scufundat. Restul rundei, harta rămânea goală.

**Ce e acum:** generatorul are două vârste, iar locurile rămân aceleași.
- `portals.gd` are `var ender := false` și `treci_pe_ender()`. `_build_chunk` alege `portal.tscn` sau `portal_ender.tscn` după steag; `treci_pe_ender()` îl aprinde și golește `_loaded`, iar `_process` reface aceleași chunk-uri la cadrul următor, cu noua față.
- **Cheia e că poziția e deterministă și NU se uită la steag** (`chunk_portal_pos` calculează din cheia chunk-ului). Deci fiecare fântână iese fix unde stătea portalul ei — inclusiv cea de sub picioarele tale — fără nicio listă de poziții salvată.
- `nether.gd`: `_deschide_fantana_ender/_pune_fantana` (care instanția una) au devenit `_deschide_fantanile_ender/_pune_fantanile` (care cheamă generatorul). Am păstrat doar temporizarea, `FANTANA_INTARZIERE = 1.1s` — puțin peste `sink_duration` (1.0), ca să se vadă schimbul: unul intră în pământ, altul iese acolo. `preload`-ul `FANTANA_ENDER` a plecat din `nether.gd` în `portals.gd`.
- `ender.gd`: la ieșirea victorioasă cheamă și `portals.opreste()` — ADICĂ închiderea definitivă s-a mutat cu o dimensiune mai încolo. Alegerea e a lui Răzvan (l-am întrebat): după Executioner se închid toate, un Ender pe rundă, nu farmabil.

**⚠️ Capcana care m-ar fi prins:** `ender.gd::enter()` cheamă `_set_world_enabled(false)`, care **golește generatoarele de copii** — iar fântâna e acum copilul unuia. Adică intrarea în Ender ți-ar fi șters chiar ieșirea. Rezolvat cu `reparent()` în `World` la intrare (același truc pe care `nether.gd` îl face cu portalul care se scufundă). Înainte problema nu exista: fântâna era pusă din start direct în `World`.

**Anunțurile nu s-au atins** — „A WELL RISES" / „Something deeper is waiting" sunt deja traduse în 8 limbi în `i18n.gd` și rămân adevărate (fântâna din fața ta chiar răsare). Un text nou ar fi cerut 8 traduceri pentru zero câștig.

**Verificat rulând jocul** (scenă de test peste `main.tscn`, ștearsă după), cu `portal_chance = 1.0` ca să intre zeci în cadru: **44 portaluri → 44 fântâni pe pozițiile identice** (capturi înainte/după, aceeași așezare), `ender=true oprit=false`; fântâna supraviețuiește intrării în Ender (`fantana inca vie? true`); după Executioner **0 interactabile**, `oprit=true`.

**Notă:** boss-ul Ender-ului tot n-are cadre (folderul `Undead executioner puppet` lipsește de pe disc — vezi log-ul de pe 2026-08-03). Testul a mers oricum, `executioner.gd` doar avertizează.

---

## Session log — 2026-08-03 (CELESTO: cadrele boss-ului nou din Ender)

**Cerut de Răzvan:** „Ți-am pus folderu de boss în Portal Ender — se numește Celesto. Nu ai animația de la west, îi dai tu mirror la aia de la east. Să aibă conturu ăla albastru da de 1 px."

**Ce e în folder:** 6 GIF-uri de mers (`Idle_v3_walking_*.gif`), 8 cadre fiecare, 128×128.

**Lipseau DOUĂ direcții, nu una.** Răzvan a văzut `west`; lipsea și `north_west` (are `south_west`, dar nu și perechea de nord). Le-am făcut pe amândouă după aceeași regulă — stânga e dreapta întoarsă — deci `west ← east` și `north_west ← north_east`. Dacă voia altfel la nord-vest, acolo se schimbă.

**Unealta nouă: `tool_celesto.gd`** (rulată ca scenă). Face două lucruri, în ordinea asta:
1. **oglindește** cele două direcții lipsă, cu **recentrare**: `flip_x` întoarce toată pânza, deci un desen care nu stă fix în mijloc se mută cu dublul decalajului — în joc s-ar fi văzut boss-ul SĂRIND lateral la schimbarea direcției. Unealta măsoară conturul opac înainte/după și îl pune la loc pe aceleași coloane (aici: −3px la west, −15px la north_west). Aceeași lecție ca la `tool_mirror_grasu.gd`;
2. pune **conturul albastru de 1px** (exact `ALBASTRU` din `tool_contur_foaie.gd`, ca să arate la fel cu boss-ul de dinainte) și scrie copiile în **`frames_contur/`**. Sursa din `frames/` rămâne neatinsă → unealta se poate re-rula fără să se îngroașe conturul.

**De ce o unealtă nouă și nu o linie în `tool_contur_foaie.gd`:** ăla conturează FOI (grile de cadre într-un singur PNG), aici sunt fișiere separate, câte unul pe cadru.

**Verificat pe capturi:** cele 8 direcții pe fundal de nebuloasă, conturul albastru vizibil pe toate; perechile east/west și north_east/north_west puse alături — oglindirea e corectă și numărul de pixeli de contur iese IDENTIC între sursă și oglindă (1769 și 2598), ceea ce arată că nu s-a pierdut nimic la întoarcere.

**⚠️ ATENȚIE, descoperit atunci: folderul `Undead executioner puppet` NU MAI E PE DISC.** Răzvan l-a înlocuit cu Celesto. `executioner.gd` încă îl caută: nu crapă (`_build_frames` dă `push_warning` și merge mai departe), dar boss-ul Ender-ului rămâne **invizibil**, iar cum lovitura lui pleacă pe un cadru anume (prin `frame_changed`), fără cadre **nu mai atacă**. Deci Ender-ul e momentan cu un boss fantomă. **N-am comis ștergerea** — se restaurează cu `git checkout -- "harta/Portal Ender/Undead executioner puppet"` dacă a fost din greșeală. **Și Celesto NU e înlocuitor direct:** are doar mers, pe când Executioner-ul avea idle + attack + skill + summon + death.

---

## Session log — 2026-08-03 (atmosferă pentru Nether și Ender + boss-ul Ender la 100 000 HP)

**Cerut de Răzvan:** „Poti sa pui niste shadere in nether si in ender sa arate mai atmosferic? Nether trebuie sa fie asa ca iadul si Ender mai cosmic." Plus, mai devreme: bossul din Ender la 100 000 HP (`executioner.gd::max_hp`, era 16 000 — viața rămâne FIXĂ, nescalată, ca pragul fazei 2 să cadă tot la jumătate).

**Atmosfera se face din DOUĂ lucruri, nu din unul.** Asta e decizia care ține tot restul:
1. **`CanvasModulate` colorează LUMEA** (`DIM_TINT` din `atmosphere.gd`): Nether `(0.98, 0.58, 0.50)` = roșu de jar, Ender `(0.68, 0.80, 1.12)` = albastru rece, cu albastrul PESTE 1.0 (deci aprins, nu stins). Fiindcă un CanvasModulate prinde doar canvas-ul obișnuit, nu și CanvasLayer-ele, HUD-ul rămâne necolorat. **Dacă culoarea s-ar fi făcut în shaderul de pe ecran, s-ar fi înroșit și bara de viață, și XP-ul, și cronometrul.**
2. **Un shader peste ecran** pentru mișcare: `nether_hell.gdshader` (scântei care urcă, fum, lumina cuptorului de jos, vinietă caldă) și `ender_cosmic.gdshader` (stele care clipesc pe 2 straturi cu parallax, nebuloasă care se rotește ~un tur/10 min, panglică de auroră, vinietă indigo).

**Shaderele astea NU citesc ecranul**, spre deosebire de `limbo_bw.gdshader`. De aia nu deformează și nu decolorează HUD-ul de sub ele: pun doar lumină peste. Amândouă se termină cu același truc de compunere într-o singură trecere, cu amestec normal: `a = vinietă + luminozitatea luminii`, iar culoarea se împarte la `a` ca înmulțirea de la amestecare s-o aducă înapoi. Consecință acceptată: lumina tare acoperă fundalul — la scântei e chiar ce vrem, iar ceața largă are `a` mic și abia se simte.

**Un singur loc de comandă:** `atmosphere.gd::set_dimension("nether" / "ender" / "")`. `nether.gd` și `ender.gd` cheamă fiecare câte o linie, lângă `_set_ground_*`. Tot ce ține de „cum arată dincolo" stă într-un fișier.

**⚠️ Tween-ul de intrare/ieșire e pe `TWEEN_PAUSE_PROCESS`, nu pe implicit.** Bug prins pe captură la testare: dacă mori în Nether, `player.die()` te scoate afară — dar ecranul de Game Over pune jocul pe **pauză** în aceeași clipă, iar tween-ul obișnuit îngheța cu lumea rămasă roșie sub „YOU DIED". Aceeași capcană ar prinde și un level up luat fix la intrarea în dimensiune.

**Podeaua unduiește DOAR în Ender, și puțin** (`warp_*` în `biome.gdshader`; 14px, scală 0.0022, viteză 0.16). **În Nether e stinsă (0)** — a fost pornită întâi la 5.5px, iar Răzvan a cerut-o scoasă în aceeași zi: „vreau sa nu se miste dubios ecranul". Motivul e în artă, nu în cifre: **cărămida are linii drepte și lungi**, iar orice deformare pe ele se citește ca „mi se mișcă ecranul", nu ca aer fierbinte. Nebuloasa Ender-ului n-are linii drepte, deci acolo trece — dar tot s-a tăiat de la 46 la 14. Reglajele au rămas `@export` în `ground.gd`, cu implicit 0 pe Nether, ca să se poată reîncerca fără cod. Se deformează **doar UV-ul texturii, nu harta de biomuri** — în dimensiuni ambele texturi sunt aceeași (vezi `ground.gd::set_nether`), deci amestecul iese la fel oricum. `warp_amount = 0` (lumea normală) sare complet peste calcul, deci **nu costă nimic afară din dimensiuni**. Reglajele sunt `@export` în `ground.gd`, se pot mișca din Inspector.

**Stratul e pe `layer = 2`** — peste lume și HUD, sub vinieta obișnuită (3), sub cronometrele dimensiunilor (4) și sub bara de boss (6). Deci cronometrul, busola și bara boss-ului rămân curate. Vinieta din shader se adună peste cea din `atmosphere.gd`, de aia e ținută mică (0.50 / 0.58).

**Verificat prin rulare, cu capturi:** lumea normală înainte și după — **identică** (nicio urmă de tentă, nicio unduire) ✅; Nether roșu cu scântei și cărămidă care unduiește ✅; Ender albastru-violet, stele, boss-ul pe ecran cu bara lui necolorată ✅; moarte în Nether → Game Over fără tentă roșie (fix-ul de pauză) ✅.

**Ce NU s-a făcut:** n-are buton în Settings → GRAPHICS (ar fi cerut 8 traduceri noi pentru o cheie). Dacă pe telefon se simte, acolo se leagă, lângă `vignette`/`glow`.

**Fântâna Ender stă acum pe sol, în amândouă lumile** (cerut tot atunci: „pune si tu o umbra pentru portalu de ender in lumea normala si in ender in sine fa-l sa se blenduiasca mai bine cu podeaua cosmica"). Două pete la bază, ambele pe `z_index = -1`, construite în `portal_ender.gd::_construieste_talpa()` din același `ground_shadow.gd` ca la copaci:
- **umbra** neagră — ancora din lumea normală;
- **haloul** violet, mai lat, care respiră (tween în buclă) — el ține locul umbrei în Ender, unde podeaua e o nebuloasă aproape neagră și **negru pe negru nu se vede**. Tot acolo piatra se stinge puțin (`ender_tint`), altfel fântâna era cel mai luminos lucru de pe ecran.

**⚠️ `shadow_width` e 1.02, adică PESTE lățimea siluetei, iar `shadow_shift_y` e POZITIV (+10).** Copacii au 0.60 și −6. Nu e capriciu: prima variantă a folosit cifrele lor și umbra a ieșit **complet invizibilă în joc** — fântâna e un butoi rotund, lat cât toată silueta, deci o elipsă mai îngustă îi stă întreagă ascunsă în spate. La copaci merge fiindcă umbra iese în lături de sub un trunchi subțire. **Dacă vreodată o umbră „nu apare", asta e prima verificare**, nu alfa.

**Cine îi spune în ce lume e:** `ender.gd`, cu `set_cosmic(true/false)`, exact lângă locul unde îi mută `retur`. Fântâna nu se uită singură după grupul „ender" în fiecare cadru — cine îi schimbă rolul îi spune și cum să arate. Tween-ul e tot pe `TWEEN_PAUSE_PROCESS`, din același motiv ca la atmosferă. La scufundare, cele două pete se sting odată cu piatra, altfel rămânea o baltă violetă pe pământul gol.

---

## Session log — 2026-08-03 (ruleta EGT: un singur status pe învârtire)

**Cerut de Răzvan:** „Vreau la EGT sa poti sa faci gamble doar la un stat at a time."

**Ce era înainte:** `_alese` era un DICȚIONAR de bifate, iar `_aplica_pariul()` trecea prin toate. Puteai bifa Damage + Max HP + Move Speed + orice altceva și le trimiteai pe toate la aceeași învârtire — un singur zar decidea jumătate de build.

**Ce s-a făcut.** `_alese := {}` a devenit `_ales := ""` (un singur id, „" = niciunul), iar bifele primesc un **`ButtonGroup` comun** — Godot le face exclusive singur și, bonus, le desenează ca butoane RADIO, deci regula se vede pe ecran, nu doar în cod. Grupul se face nou la fiecare `_umple_statusuri()`, fiindcă și bifele sunt noduri noi.

**⚠️ La schimbarea bifei vin DOUĂ semnale `toggled`** (se stinge cea veche, se aprinde cea nouă) și ordinea lor nu e garantată. De aia `_on_bifa` stinge doar dacă cel care tocmai s-a stins e chiar cel reținut (`elif _ales == id`) — iese la fel indiferent care semnal vine primul. Din același motiv, sunetul de click se dă doar pe aprindere, altfel s-ar auzi dublu.

**Subtitlul panoului** e acum „One stat per spin · Lose = half of it" (cheia veche, „Lose = half the stat", a fost înlocuită în `i18n.gd`, cu tot cu cele 8 traduceri).

**Verificat pe rulare:** 7 statusuri în listă, toate pe același `ButtonGroup`; bifez Damage → `_ales = damage`, bifez apoi Weapon Size → `_ales = wsize` și **o singură bifă rămâne aprinsă pe ecran**; SPIN e blocat fără pariu pe masă și pornește cu pariu + status; după învârtire **exact un status s-a schimbat** (`wsize 100% → 50%`, pierdere).

---

## Session log — 2026-08-03 (dimensiunea ENDER + boss-ul ei)

**Cerut de Răzvan:** tilesetul pentru dimensiunea nouă (`misc_nebula.png`) plus, la întrebările mele: intrarea = **fântâna apare în lumea normală după ce-l omori pe Saratalin**; conținutul = **creaturile violete + un boss nou**, „Undead executioner puppet", cu **contur albastru închis**; ieșirea = **doar după ce omori boss-ul**.

**Lanțul întreg, ca să se înțeleagă cum se leagă:** bați Saratalin în Nether → ieși viu → portalul Nether-ului se scufundă → **din locul lui răsare fântâna Ender** (`nether.gd::_deschide_fantana_ender`) → E pe ea → Ender → omori Executioner-ul → E pe fântână → înapoi în lume, iar fântâna se scufundă. **Un Ender pe rundă**, ca Nether-ul.

**`ender.gd`** e frate cu `nether.gd`, nu o rescriere a lui: aceeași rețetă (nu se încarcă altă scenă, se oprește decorul, îngheață cronometrul rundei și pornește unul propriu). Diferă cifrele — 6:00 în loc de 7:00, **XP ×3** în loc de ×2, cronometru albastru — și boss-ul, care e acolo de la intrare, într-un inel de 700–1100px, cu busola pe el. **Fișier separat, cu duplicare asumată**, ca Limbo față de Nether: un strămoș comun ar fi legat trei dimensiuni cu reguli diferite într-un singur loc greu de citit.

**⚠️ O SINGURĂ fântână, nu două.** Nether-ul își pune un portal NOU dincolo, fiindcă cel din lume e generat pe chunk-uri și dispare. Fântâna Ender stă direct în `World`, iar dimensiunile împart aceleași coordonate — deci ea e deja exact acolo unde aterizezi. Prima variantă (copiată de la Nether) punea o a doua fântână peste ea: **două „Press E" în același punct**, iar `interact_ui.gd` putea alege exact pe cea greșită, care n-ar fi făcut nimic. Acum `ender.gd` o împrumută: îi aprinde `retur` la intrare, i-l stinge la ieșire.

**Boss-ul (`executioner.gd`)** e croit după `saratalin.gd`, cu trei deosebiri:
- **arta e pe GRILE, nu pe un rând** — 5 foi cu cadre de 100×100 (`idle2` 8, `attacking` 13, `skill1` 12, `summon` 5, `death` 18). Feliate la rulare cu `AtlasTexture`, pe rânduri; celulele goale de la coada grilei se sar prin numărul real de cadre;
- **lovitura pleacă pe un CADRU anume** (`CADRU_LOVITURA`, prin semnalul `frame_changed`), nu la începutul animației — altfel proiectilul iese din el înainte să se vadă că a tăiat;
- **faza 2 n-are filmuleț.** Saratalin oprește jocul și pulsează mov; ăsta are animație de invocare în foaie, deci de la jumătate de viață **cheamă 4 creaturi** la fiecare 11s și atacă de 1,6× mai des. Se vede prin ce face, nu prin cameră.
Viață fixă **100 000** (Saratalin are 10 000) și premiu **4 niveluri** (el dă 3) — ca să ajungi aici trebuie să-l fi bătut deja pe el. Proiectilul e ștreangul lui Saratalin colorat albastru, **placeholder** până are tăietura lui de coasă.

**Conturul albastru:** `tool_contur_foaie.gd` știa doar foi pe un singur rând; acum acceptă grile (`coloane`×`randuri`) și sare celulele goale. Nu e cosmetic: silueta e **complet neagră**, iar podeaua Ender-ului e o nebuloasă aproape neagră — fără contur boss-ul ar fi o gaură în ecran. Foile lui Răzvan rămân neatinse, se scriu copii `*_contur.png`, deci unealta se poate re-rula fără să se îngroașe conturul.

**Podeaua:** `ground.gd::set_ender()`, exact trucul de la Nether (aceeași textură pe ambele sloturi ale shaderului de biom). **Dala e 256, nu 96 ca la cărămidă** — e un cer înstelat, nu un pavaj; la 96 se vedea limpede că aceeași bucată se repetă la doi pași.

**Cele patru locuri care întrebau „ești în Nether?" întreabă acum și de Ender:** `hud.gd` (ascunde cronometrul rundei), `player.gd` (pașii + `die()`), `spawner.gd` (ce inamic naște + să NU aplice îngroșarea de „scăpat din Nether" înăuntru, unde dificultatea o scrie `ender.gd`).

**Verificat printr-o rulare reală a lui `main.tscn`**, cu lanțul întreg parcurs de o unealtă temporară:

| | rezultat |
|---|---|
| fântâni Ender în lume înainte / după Saratalin | 0 → **1**, la 220px de player (fix unde s-a scufundat portalul) |
| podea / dală | `grass` 64 → **`misc_nebula` 256** → înapoi `grass` 64 |
| decor (Props/Rocks/Statues/Chests/EGTs) | 49/49/49/81/49 → **0 peste tot** → 49/49/49/81/49 |
| `Difficulty` | frozen **true**, xp_bonus **3.0** → false, 1.0 |
| E pe fântână cu boss-ul viu | `active` rămâne **true** (nu te lasă) |
| la jumătate de viață | **4 creaturi chemate** = `summon_count` |
| premiu la moartea boss-ului | nivel **1 → 5** (+4) |
| după ieșire | fântâna s-a scufundat, lumea a revenit |

**🐛 Prins la testare:** bannerul „A WELL RISES" apărea **peste ecranul Ender-ului**. Anunțul vine la ~5,6s după ieșirea din Nether (ca să nu taie „BACK" și „SOMETHING FOLLOWED YOU" — bannerul din HUD e unul singur), dar fântâna răsare **fix sub picioarele tale**, deci poți intra în ea înainte. Acum `_anunta_fantana()` verifică și grupul „ender".

**Capcană de testare, nu bug:** prima rulare zicea „fântâni după: 0". Motivul: fântâna răsare unde se **scufundă un portal**, iar testul chemase `nether.enter()` direct, fără să existe vreun portal de piatră prin apropiere (1,5% din chunk-uri). Testul trebuie să pună întâi un portal real și să intre prin `portal.invoca()`.

**Traduceri:** 14 chei noi în `i18n.gd` × 8 limbi (numele boss-ului de pe bară se traduce și el, e text descriptiv, nu nume propriu ca „Saratalin"). `ender.gd` și `executioner.gd` sunt acum în lista `FISIERE_UI` din `tool_check_i18n.gd`. Verificatorul zice **„TOTUL E TRADUS"** (220 chei × 8 limbi).

**Ce NU s-a făcut:** creaturile mici din foile `summon*.png` (au și ele cadre, dar de mărimi amestecate — 50×100 și 50×50) n-au devenit inamici; boss-ul cheamă creaturile violete ale Nether-ului. Ender-ul n-are muzică proprie și nici pas propriu — împrumută bucla și pașii Nether-ului.

---

## Session log — 2026-08-03 (portalul Ender: lichidul se învârte)

**Cerut de Răzvan:** „ti-am facut un nou folder in harta, se numeste Portal Ender, ai un sprite acolo, daca poti sa animezi sa se invarta usor «lichidul» dinauntrul portalului. Vreau sa fie o noua structura si o sa iti dau dupa ce animezi lichidul un tileset sa facem dimensiunea noua «Ender»."

**Ce s-a făcut.** `harta/Portal Ender/portal ender.png` (128×128, o fântână de piatră cu un vârtej violet) a devenit `portal_ender.tscn` — structură ca celelalte (`StaticBody2D` + `Sprite2D` la scale 2.4 cu `offset.y = -18.17`, adică regula de 74px, + `CollisionShape2D` 190×90 de reglat cu mâna) — iar lichidul se rotește dintr-un **shader**, `portal_ender.gdshader`.

**De ce shader și nu cadre.** Ar fi însemnat un sprite sheet desenat de mână pentru fiecare unghi; așa rămâne un singur PNG, iar viteza se schimbă dintr-un slider.

**Cum se rotește o elipsă fără să se rotească forma.** Gura fântânii e o elipsă (o rotunjime văzută din unghi). Dacă roteai UV-ul direct, se rotea și conturul, ca o roată de mașină. Shaderul aduce pixelul în „spațiul cercului" (`(UV - centru) / raze`), rotește acolo, apoi îl întinde înapoi în elipsă — exact ce face perspectiva cu un disc care se învârte pe orizontală.

**Cifrele nu sunt ghicite, sunt măsurate pe pixeli** (o unealtă temporară care a scanat pixelii unde albastrul domină clar roșul și verdele): lichidul stă la x 38..89, y 52..79 → centru `(0.496, 0.512)` în UV, raze `(0.2, 0.105)`. Prima încercare, cu saturația drept criteriu, n-a mers: și piatra fântânii e albăstruie la umbră.

**Marginea (`edge_fade = 0.88`):** ultimii 12% din elipsă se estompează înapoi spre imaginea originală. Fără ea, rotația ar fi tras în horă și pixeli de pe buza de piatră, și s-ar fi văzut o cusătură.

**Viteza e în ROTAȚII pe secundă, nu radiani** — `spin_speed = 0.05` = o tură la 20 de secunde. Plus `wobble` ±0.012 ture (≈4°), o legănare mărginită: brațele spiralei se strâng și se lasă puțin. Legănarea trebuie să rămână mărginită — o rotație diferențiată pe rază (interiorul mai repede) ar înfășura spirala tot mai strâns, la infinit, până se face terci.

**Verificat pe rulare** (fereastră, nu headless — headless randează negru): cadre la t = 1,2 s / 11,2 s / 21,2 s, vârtejul e la câte o jumătate de tură distanță, iar piatra, funia și manivela stau nemișcate.

**⚠️ `const float TAU` în shader = eroare de compilare** — `TAU` e deja constantă în limbajul de shader al Godot. Iar când shaderul nu compilă, sprite-ul pur și simplu nu se desenează, fără nimic în ecran; mesajul e doar în consolă.

**Nu e pus încă în lume** — n-are generator și n-are `.gd`. Așteaptă tilesetul pentru dimensiunea Ender. *(Rezolvat în aceeași zi: a venit tilesetul, vezi log-ul „dimensiunea ENDER" de mai sus — fântâna are acum `portal_ender.gd` și răsare unde se scufundă portalul Nether-ului.)*

---

## Session log — 2026-07-30 (proiectilele câștigate la ruletă sunt ca cele de la iteme)

**Cerut de Răzvan:** „Cand castig la ruleta proiectile mi le pune paralele, eu vreau cum sunt si celalalte iteme de proiectile."

**Bug real, nu preferință.** Cazinoul scria în `player.bullet_count` = gloanțe PARALELE, trase toate spre aceeași țintă. Mecanica aia e moartă din **2026-07-21**: niciun item n-o mai dă (vezi comentariul de la `bullet_count`), iar tot ce se numește „proiectil în plus" azi — Gunslinger, Twin Comets, chiar itemul cu id-ul vechi `gloante_paralele` — merge pe **`stacked_armory_stacks`**: salve ÎNTREGI trase în ALȚI inamici, în direcții diferite. Deci ruleta dădea altceva decât dau itemele, deși rândul din panou se numea la fel.

**Ce s-a făcut.** `casino.gd::_aplica("proj")` socotește acum pe **total** (`projectiles_total()` = paralele + bonus, adică exact numărul afișat în panou) și pune diferența în `stacked_armory_stacks`; `bullet_count` rămâne 1. Și `_valoare("proj")` citește totalul, nu `bullet_count` — altfel rândul s-ar fi uitat la altceva decât modifică.

**Verificat pe rulare:**

| | rezultat |
|---|---|
| itemul din level up (+2) | paralele 1, bonus 2, total 3 |
| câștig ×2 / ×3 / ×20 | bonus 1 / 2 / 19 — paralele rămân 1 |
| lanț ×2 de trei ori | 1 → 2 → 4 → 8, apoi înapoi 4 → 2 → 1 la pierderi |
| pierdere de la 1 | rămâne 1 (nu poți ajunge fără proiectile) |
| tras cu 2 bonus, 4 inamici în jur | **3 gloanțe în 3 direcții DISTINCTE** — salve separate, nu paralele |

---

## Session log — 2026-07-30 (întors din Nether = polițiști dubli, ca număr și ca viață)

**Cerut de Răzvan:** „vreau sa fie la fel ca putere si spawn rate, si atunci cand vine player-ul din nether, dubleaza spawn-rateul si puterea inamicilor normali din lumea normala."

**Întrebat înainte de a scrie cod** (trei citiri diferite duceau la jocuri diferite). Răspunsurile lui: creaturile rămân **ca în Nether** (mai tari decât polițiștii), dublarea prinde **doar polițiștii**, amestecul rămâne **30%** creaturi.

**Ce s-a făcut.** `spawner.gd` are `escaped_police_mult` (2) și `escaped_power_mult` (2), amândoi `@export`. Când `nether.escaped` e aprins: rata crește și fiecare polițist primește `power_mult = 2`, citit de `enemy.gd::_ready()` peste multiplicatorul de dificultate. Creaturile nu-l primesc.

**⚠️ Aritmetica pe care am greșit-o o dată, în timpul lucrului.** Am pus întâi „rata totală × 2" și am măsurat: polițiștii crescuseră doar cu 1,4×. Motivul: ÎNAINTE de Nether polițiștii sunt **100%** din flux, iar DUPĂ sunt doar **70%**. Ca să fie de două ori mai mulți polițiști pe secundă ȘI creaturile să rămână 30% din total, fluxul întreg trebuie înmulțit cu `2 / (1 − nether_share)` = **2,86**, nu cu 2. Scris în comentariu, ca să nu se „simplifice" cineva înapoi la 2.

**„Putere" = doar VIAȚA.** Viteza nu se atinge (dublată, polițiștii i-ar întrece pe creaturi). Damage-ul de contact nici n-ar avea cum: nu vine de la inamic, ci din statul `contact_damage` al player-ului × `Difficulty.enemy_damage_mult()` (vezi `player._take_contact_damage`), deci e același pentru orice inamic de pe ecran. Multiplicatorul se pune din spawner ÎNAINTE de `add_child` (acolo rulează `_ready`), deci **niciun fișier `.tscn` n-a fost atins** — important, fiindcă `enemy_nether.tscn` are modificări necomise ale lui Răzvan.

**Măsurat, 60s pe fază, dificultate înghețată ca fazele să fie comparabile:**

| | înainte de Nether | după întoarcere |
|---|---|---|
| total | 1,25 inamici/s | **3,63/s** |
| polițiști | 1,25/s (100%) | **2,48/s** (68%) — exact dublu |
| creaturi | 0 | 1,15/s (32%) |
| viață de bază polițist | 29,7 | **60,0** |
| viață de bază creatură | — | 49,7 (neschimbată) |

**⚠️ Două capcane de testare, ambele m-au trimis pe piste false:**
1. **Ecranul de Level Up pune jocul pe PAUZĂ** și oprește spawnerul, dar `get_tree().create_timer()` merge mai departe (are `process_always = true` din oficiu). Cu player-ul nemuritor care strânge XP la nesfârșit, măsurătoarea arăta o rată care „scade cu timpul" — de fapt jocul stătea. Soluția: `p.xp_to_next = 1_000_000_000` în test.
2. **`instance_id` se REFOLOSEȘTE** după ce un nod e șters, deci un test care ține minte id-urile văzute subnumără grav într-un măcel de 40 de secunde. Numără prin `child_entered_tree` pe `World` și distinge tipul prin `scene_file_path` — numele nodului NU merge, Godot îl rescrie în `@Enemy@1234` la duplicate.

**De urmărit în joc:** lumea se umple mult mai repede (180 de inamici vii după 60s în test), deci plafonul `max_enemies` = 300 se atinge mai devreme decât înainte.

---

## Session log — 2026-07-30 (aparatele EGT nu mai apar în Limbo)

**Cerut de Răzvan:** „egt-urile nu vreau sa se spawneze in nether."

**În Nether nu se spawnau deja** — verificat pe rulare: intri, te plimbi 20 de mutări prin lume, **0 aparate**, generatorul stins și invizibil, iar la ieșire revine. Ăla fusese reparat mai devreme în aceeași zi (`WORLD_NODES` din `nether.gd`).

**Unde se spawnau de fapt: în LIMBO.** Sunt DOUĂ dimensiuni-buzunar care sting decorul, fiecare cu lista ei, iar `limbo.gd::WORLD_NODES` nu-l avea pe „EGTs". Măsurat înainte de reparare: **2 aparate vii și vizibile** în Limbo, cu tot cu hitbox și cu tastă E funcțională — puteai să deschizi cazinoul în mijlocul probei de 60 de secunde. Reparat prin adăugarea lui „EGTs" în listă; verificat: 0 în Limbo, generatorul repornit corect la ieșire.

**Regula, scrisă acum în AMBELE fișiere:** un generator nou pus în `World` (main.tscn) se trece în `WORLD_NODES` din `nether.gd` **și** din `limbo.gd`. Aceeași scăpare, de două ori, cu același obiect.

**Rămas nereparat, semnalat lui Răzvan:** `Portals` e în lista Nether-ului, dar NU în a Limbo-ului, deci portalurile spre Nether rămân vizibile în Limbo (măsurat: 1 portal viu). Apăsatul pe E acolo nu face nimic — `nether.gd::enter()` refuză cât `limbo.active` — deci e un obiect mort pe ecran, nu un bug de logică. N-am atins-o fiindcă e o schimbare vizibilă pe care n-a cerut-o.

---

## Session log — 2026-07-30 (norocul înclină ruleta EGT)

**Cerut de Răzvan:** „Vreau ca luck-ul pe care îl iei în joc să afecteze la EGT [...] +1 șansă pentru fiecare 10 luck în plus. Exemplu: 10 luck și pune roșu → 50% roșu, 48% negru, 1% verde."

**Ce s-a făcut.** `casino.gd` nu mai trage `randi() % 37`, ci `_trage_numarul(pariu)`: construiește greutăți pentru cele 37 de numere și mută **`LUCK_PER` = 0,1 puncte procentuale pe punct de noroc** (deci +1 la 10 noroc) de la numerele care PIERD spre cele care câștigă pariul pus. Suma greutăților rămâne 1 — e tot o roată, doar înclinată.

**🔑 Zero-ul nu se atinge NICIODATĂ.** Verdele își păstrează 1/37 = 2,70% în orice condiții, exact ca în exemplul cerut (verdele rămâne pe loc, negrul scade). Adică norocul îți ia din adversar, nu din avantajul casei.

**Rata NU e `player.luck_bonus()`** (0,4 puncte pe punct de noroc). Acolo norocul umflă șanse mici de proc (crit, instakill), unde 0,4 e mărunt; aici s-ar aplica peste ~50% și 50 de noroc ar duce roșul la 68%. De-aia cazinoul are rata lui, `LUCK_PER`.

**Plafon:** nu poți muta spre câștig mai mult decât au numerele care pierd (`_bonus_noroc_util`). Practic e de neatins — la roșu ar trebui ~480 noroc — dar fără el un noroc absurd ar da greutăți negative, în tăcere.

**Panoul arată acum și șansa**, nu doar plata: „WIN X2 · 49.6%". Cu zecimală intenționat — fără ea, +1 punct de la 10 noroc s-ar rotunji înapoi la 49% și ai crede că itemul n-a făcut nimic. Procentul e un număr, deci **nu cere cheie i18n nouă** (se lipește de „Win x%s", care există deja).

**Măsurat în jocul real** (player real, UI reală, 60.000 de trageri per configurație):

| pariu | 0 noroc | 10 noroc | 50 noroc |
|---|---|---|---|
| roșu | 48,50% (aștept. 48,65) | 49,75% (49,65) | 53,43% (53,65) |
| 1st 12 | 32,58% (32,43) | 33,04% (33,43) | 37,31% (37,43) |
| număr plin 17 | 2,60% (2,70) | 3,69% (3,70) | 7,67% (7,70) |
| **verde** | 2,73% | 2,75% | 2,74% | ← neschimbat, cum trebuie

**⚠️ Capcană de testare (m-a costat ~15 minute):** un test care instanțiază `casino.gd` cu `CASINO.new()` și un player FALS (un `Node2D` cu doar `luck`) se blochează la `open()` → `_umple_statusuri()`, care cere toate statusurile reale. Și cum Godot ține stdout în buffer până la ieșire, un blocaj arată exact ca „merge încet". Soluția: testează prin `main.tscn` (ca la testul de ocolire), cu player-ul adevărat.

---

## Session log — 2026-07-30 (inamicii ocolesc obstacolele în loc să împingă în ele)

**Cerut de Răzvan:** „când inamicii se blochează într-un obiect (merg încontinuu în el și se lovesc de hitbox) să facă stânga sau dreapta, nu tracking foarte complicat, doar atunci când e blocat să facă stânga sau dreapta să se pună pe traiectorie înapoi."

**Ce s-a făcut.** `enemy.gd` a primit un reflex de ocolire (blocul `OCOL_*`). NU e pathfinding: n-avem hartă de navigație (lumea e infinită, generată în chunk-uri) și la 300 de inamici un A* pe cadru ar omorî framerate-ul. Sunt trei bucăți:
1. **Detecția.** Compar deplasarea REALĂ dintr-un cadru cu cea cerută (`_verifica_blocaj`). Sub 40% timp de 0,15s = împinge degeaba. Pragul e pe cât s-a mișcat, nu pe „am atins ceva": inamicii ating obstacole tot timpul și alunecă frumos pe lângă ele — problema e doar când alunecarea nu-i mai duce nicăieri.
2. **Cotitura.** Mersul se rotește cu 80° (`_ocoleste`) timp de 0,6s, apoi îi dăm iar drumul spre țintă. Dacă obstacolul mai e în față se declanșează din nou, dar din alt unghi → înaintează pas cu pas în jurul lui.
3. **Partea.** Din normalele coliziunii: tangenta la obstacol, în sensul care duce mai spre țintă (= drumul scurt). Când e lovit DIN PLIN tangenta nu spune nimic (ambele sensuri sunt la fel), și atunci decide `get_instance_id() % 2` — arbitrar, dar constant pentru același inamic (nu tremură) și diferit între ei (doi blocați de același copac nu pleacă în aceeași parte).

**Două capcane, amândouă prinse de test, amândouă meritând ținute minte:**
- **Alegeam partea din nou la fiecare reblocaj** și, ca „să încerc și cealaltă variantă", o luam pe cea opusă. Rezultat: inamicul se legăna la nesfârșit în sus și-n jos pe fața obstacolului, fără să-i dea ocol niciodată (6/7 ajungeau, unul dansa la infinit). Corect e să se **țină de partea aleasă** până chiar înaintează (`_ocol_semn` se uită abia după `OCOL_UITARE` = 1s de mers curat).
- Dar dacă se ține ORBEȘTE de ea, un colț înfundat îl ține pe loc la fel de bine (în testul de pădure, 10 din 20 se adunaseră în ACELAȘI buzunar). Plasa de siguranță: dacă în `OCOL_INSISTENTA` = 2s de ocolit nu s-a apropiat de țintă cu măcar 40px, partea aia nu duce nicăieri → o încearcă pe cealaltă, **cu răbdare dublă** (2s → 4s → 8s, plafonat la 16). Dublarea nu e cochetărie: pe un obstacol LUNG (un zid, nu un copac), cu răbdare fixă se prinde între cele două capete și se leagănă la infinit — 4/7 ajungeau; cu dublare, 7/7.

**Măsurat, A/B pe același test** (cod vechi vs. nou):

| scenariu | înainte | după |
|---|---|---|
| copac fix în drum, 7 inamici | 0/7 | **7/7** (~4,5s) |
| zid de 320px, 7 inamici | 0/7 | **7/7** (~7-11s) |
| pădure de 22 de obstacole, 20 inamici | 4/20 | **20/20** |
| **jocul REAL, 15s** (inamici înțepeniți din total măsurători) | **12,9%** | **0,0%** |

Testul din joc a rulat `main.tscn` cu player-ul făcut nemuritor din afară (`max_hp = 10_000_000`), tocmai ca să nu moară și să scrie în leaderboard-ul real — capcana din regulile de sus. „Înțepenit" = mai departe de 90px de player (deci VREA să meargă) și nu s-a clintit 2px în jumătate de secundă.

**Bonus vizual:** cât ocolește, inamicul se uită ÎNCOTRO MERGE, nu spre tine — altfel s-ar vedea mergând lateral cu fața la tine, ca un crab.

**Notă:** `player.tscn` apare modificat în working tree (`speed = 250`) — nu e de la mine, nimic din cod nu salvează scene; e o salvare din editorul deschis. L-am lăsat neatins, ca pe celelalte modificări necomise ale lui Răzvan.

---

## Session log — 2026-07-30 (plafon la mărimea glonțului: pistol 100%, mage 250%)

**Cerut de Răzvan:** „Vreau ca la pistol, bullets sa nu poata sa isi ia size up. Si la mage staff vreau sa fie o limita de 250%."

**Ce s-a făcut.** `player.gd` are acum `BULLET_SIZE_CAP = {"pistol": 1.0, "mage": 2.5}` și funcția **`bullet_size_scale()`**, folosită la naștere în `_spawn_one_bullet()` în locul vechiului `bullet_scale * weapon_size_scale()`. Pistolul trage un glonț mic și des — umflat de Pufferfish + Rat's Burger + Doză dublă ajungea la 742% (măsurat), adică o pată pe jumătate de ecran; acum rămâne fix la 100%. Sfera mage e AOE și oricum mare, deci poate crește, dar se oprește la 250%.

**Plafonul e pe REZULTAT, nu pe stat.** Adică prinde ȘI `bullet_scale` (Doză dublă, +0,3 pe luare), nu doar `weapon_size_*`. Așa cele două cifre din cerință se citesc la fel: pistol = plafon 100%, mage = plafon 250%. Doza dublă rămâne utilă la pistol pentru cei +5 damage.

**Ce NU s-a atins:** statul „Weapon Size" din panou. El e real și lucrează mai departe la **dârele de foc/gheață** (`fire_trail_size`/`frost_trail_size` × `weapon_size_scale()`), la aura stingătorului și la tăietura sabiei — se oprește doar creșterea glonțului. Efect secundar: un pistolar poate vedea „Weapon Size 464%" cu glonțul la 100%. Dacă deranjează, se schimbă textul rândului din `stat_lines()` (are nevoie de o cheie i18n nouă, fiindcă ar fi text asamblat).

**Verificat pe rulare** — tabel pentru toate cele 4 arme × 6 combinații de itemuri, plus captură cu cele trei gloanțe unul lângă altul: la „Puffer ×3 + Burger ×3 + Doză ×2" (brut 742%) pistolul iese **100%**, mage-ul **250%**, stingătorul și sabia neatinse.

---

## Session log — 2026-07-30 (creaturile din Nether te urmează în lumea normală)

**Cerut de Răzvan:** „Dupa ce vii din nether vreau sa se spawneze inamicii de acolo si in overworld."

**Ce s-a făcut.** `nether.gd` are acum steagul public **`escaped`**, aprins la ieșirea prin portal, iar `spawner.gd::_scena_inamic()` îl citește: cât e aprins, **`nether_share` (30%)** din inamicii lumii normale sunt creaturi violete, restul polițiști. Numărul TOTAL de inamici nu se schimbă — doar cine sunt. Lumea devine mai colțuroasă (creaturile au 190 viteză și 50 HP), nu mai aglomerată.

**„și" din cerință = AMESTEC, nu înlocuire.** De aia e o proporție, nu un comutator. `nether_share` e `@export`, deci se reglează din inspector: 0 = ca înainte, 1 = lumea normală rămâne doar cu creaturi.

**Doar la ieșirea VOLUNTARĂ** (`exit_nether(true)`, adică prin portal după ce cade Saratalin). La ieșirea forțată (`anunt = false`) ai murit, deci runda s-a terminat oricum. Steagul NU se salvează nicăieri: la rundă nouă `main.tscn` se reîncarcă și pleacă de la `false` singur.

**Anunț nou**, ca să nu apară creaturi din senin fără explicație: la 2,8 secunde după „BACK" intră „SOMETHING FOLLOWED YOU / Nether creatures now roam the world". ⚠️ Bannerul din HUD e **unul singur** — un `announce` nou îl taie pe cel dinainte — de aia trebuie așteptată stingerea primului (0,25 + 1,6 + 0,6 = 2,45s). Și se leagă prin **`connect`, nu cu `await`**: dacă dai Restart în cele 2,8 secunde, nodul e șters, iar o corutină s-ar trezi pe un obiect mort; la `connect`, Godot rupe singur legătura.

**🐛 Bug reparat din mers (introdus tot azi, la aparatele EGT):** `WORLD_NODES` din `nether.gd` — lista generatoarelor oprite cât ești dincolo — **nu-l conținea pe „EGTs"**, deci aparatele de cazinou rămâneau aprinse și vizibile în Nether, unde n-au ce căuta. Regula, scrisă acum și în cod: **orice generator nou pus în `World` trebuie trecut ȘI în `WORLD_NODES`**.

**Verificat pe rulare** (1000 de trageri de scenă în fiecare stare, plus un lot chiar născut în lume): înainte de Nether **0%** violeți, în Nether **100%**, după întoarcere **30,1%** — exact proporția cerută. `EGTs` oprit în Nether și repornit la ieșire. 41 de inamici născuți cu adevărat în lumea normală au ieșit amestecați, verificat și pe captură.

**⚠️ Testul a omorât player-ul** (i-am teleportat 41 de inamici în cap ca să încapă în cadru) → s-a scris în leaderboard-ul REAL. Verificat: scorul fals (0:03) **n-a intrat în top 10** (ultimul e la 494s) și runda avusese 0 kill-uri, deci 0 monede băgate la bancă. Nimic de curățat, dar tot capcana din regula de sus.

**Traduceri:** 2 chei noi × 8 limbi; `tool_check_i18n` trece pe 206 chei.

---

## Session log — 2026-07-30 (cazinoul: plăți pe tip de pariu + panoul intră în ramă)

**Cerut de Răzvan:** „Nu arata foarte bine la stats la gamble, poti sa faci textul mai mic sa intre in meniu mai bine, nici butoanele nu intra bine. La win la un numar specific vreau sa fie 20x. La rosu sau negru e 2x. 1st 12, 2nd 12 si 3rd 12 vreau sa fie 3x. La toate 2 to 1 column vreau sa fie 3x. la 1-12 vreau sa fie 3x. la 19-36 vreau sa fie 3x. la even si odd vreau sa fie 2x."

**1. Plățile nu mai sunt egale.** `CASTIG_MULT` era un singur număr (2.0), acum e un dicționar pe tip de pariu: **număr plin 20×**, duzini / coloane „2 to 1" / „1-12" / „19-36" **3×**, roșu/negru/par/impar **2×**. Pierderea a rămas 0,5 pentru orice pariu. `_aplica()` primește acum factorul gata calculat, nu un `bool`. Sub eticheta „Bet: 17" apare și „Win x20", ca să știi ce joci înainte să apeși.

**🔑 De ce se lățea panoul peste ramă (adevărata cauză, nu fontul).** O etichetă FĂRĂ `autowrap` își impune lățimea textului ca **mărime minimă**. „Place your bet on the table" cerea **291px** într-un panou de **345,6px**, iar cu marginile de 40+40 conținutul ajungea la **371px** — adică 25px în afara ramei, și odată cu el butoanele. Fontul mai mic singur n-ar fi rezolvat-o, doar ar fi amânat-o. Reparat cu `autowrap_mode` pe etichetele lungi (pariul, subtitlul, rândurile de rezultat) și `clip_text` pe numele statusurilor.

**⚠️ Marginile erau sub grosimea ramei.** `patch_margin` = 46, iar `MarginContainer` avea 40 — deci textul se urca 6px pe chenarul ornat prin construcție. Acum 56 (stânga/dreapta), 58 sus, 50 jos.

**Fonturi micșorate:** titlu 22→17, subtitlu 15→12, statusuri 16→13, pariu 18→14, SPIN 23→17 (înălțime 46→38), BACK 18→15 (38→32), rândurile de rezultat 15→12.

**Verificat pe rulare, în starea cea mai înghesuită** (toate statusurile bifate + rezultat afișat, care e momentul în care panoul are cel mai mult conținut): lățimea conținutului **345,6 = exact lățimea panoului**, în toate cele trei stări (gol / bifat tot / după rotire). Înainte era 371, apoi 365 după rezultat. Plățile tipărite din cod: numar→20, rosu/negru/par/impar→2, jos/sus/duzina/coloana→3.

**⚠️ Ce s-a schimbat în matematică (nu era în cerință, dar merită știut):** acum TOATE pariurile sunt în favoarea jucătorului pe termen lung — număr plin 1,03×, roșu/negru 1,23×, duzină/coloană 1,31× pe rotire. Iar **„19-36" e strict mai bun decât „1-12"**: acoperă 18 numere față de 12, la aceeași plată de 3× (1,72× față de 1,31×). Vine din faptul că poza scrie „1-12" unde o masă adevărată scrie „1-18" — dacă se pune `JOS_MAXIM = 18`, perechea devine simetrică.

**Traduceri:** cheia „Win = x2   Lose = half" a ieșit (nu mai e adevărată), au intrat „Lose = half the stat" și „Win x%s". `tool_check_i18n`: 204 chei, tot tradus.

---

## Session log — 2026-07-30 (pietrele nu mai cresc în trunchiul copacilor)

**Cerut de Răzvan:** „ti-am pus un screenshot in debugging vezi care e problema si rezolva, isi fac overlapping copacii cu pietrele" (`debugging/Screenshot 2026-07-23 182612.png` — o piatră fix în trunchiul unui copac).

**Cauza:** cele două generatoare **nu se vedeau deloc între ele**. `props.gd::_too_close()` compara copacul doar cu alți copaci, `rocks.gd::_too_close()` piatra doar cu alte pietre. Fiecare avea grijă de ai lui și niciunul de celălalt. Ironia: **statuile, portalurile, cuferele și aparatele EGT se fereau de amândoi de la bun început** — doar perechea copac/piatră, cea mai deasă din joc, rămăsese neverificată.

**Reparația:** `rocks.gd` a primit `_langa_copac()`, pe același tipar ca `statues.gd` (întreabă `Props._chunk_trees_raw()` pe cele 9 chunk-uri din jur).

**🔑 Cedează PIATRA, nu copacul, și e destul una singură.** Ambele generatoare sunt deterministe — poziția depinde doar de cheia chunk-ului, nu de ordinea încărcării — deci nu există „cine a fost primul". Dacă s-ar feri și copacii de pietre, aceeași ciocnire i-ar șterge pe **amândoi** și ar rămâne o pată goală în pădure.

**⚠️ Distanța se socotește din mărimile REALE, nu dintr-o cifră fixă**, fiindcă pietrele nu-s deloc egale: măsurate, au între **52 și 124px** lățime în lume, iar trunchiurile între **22 și 82px**. Un prag fix ori lăsa pietrele mari lipite de trunchi, ori mătura pietrele mici din toată pădurea. Acum: `raza vizibilă a pietrei + raza trunchiului + tree_clearance (30px)`, cu conturul opac citit din `GroundShadow` (care are deja cache, scanarea pixelilor e scumpă).

**⚠️ TRUNCHIUL, nu coroana.** O piatră sub coroană arată firesc — coroanele au **186–269px** lățime, deci verificarea pe coroană ar fi șters aproape toate pietrele din pădure. Intră și descentrarea trunchiului față de nod (arta nu e simetrică).

**⚠️ Ne ferim și de copacii care nu vor crește.** `_chunk_trees_raw()` întoarce copacii BRUȚI, inclusiv pe cei refuzați mai încolo (prea aproape de alt copac, sau pe potecă). E aceeași aproximare pe care o fac deja statuile și EGT-urile, și e partea sigură a greșelii: pierdem câteva pietre în plus, dar nu punem niciuna în copac.

**Măsurat pe 3721 de chunk-uri, înainte și după:** din **1184** de pietre, **39 (3,3%) erau înfipte într-un trunchi**, cea mai rea intra **82,2px** în copac. Acum: **0** suprapuneri, cea mai mică distanță margine-la-margine **30,7px** (peste pragul de 30), cu **5,6%** pietre pierdute. Verificat și vizual: am dus player-ul fix în locul celui mai rău caz — piatra nu mai e, restul pădurii și pietrele din jur sunt neatinse.

**Ce NU s-a atins:** `_chunk_rocks_raw()` a rămas neschimbat (filtrul e în `_build_chunk`), deci ce cred cuferele/statuile/EGT-urile despre pozițiile pietrelor e exact ca înainte.

---

## Session log — 2026-07-30 (structură nouă: aparatul EGT + ruleta „Let's go gambling")

**Cerut de Răzvan:** „Vreau sa implementez o noua structura, o ai in folderul harta -> EGT -> egt. Vreau atunci cand apesi E pe structura asta se opreste jocu ca la upgrades si iti deschide o interfata noua. Interfata vreau sa scrie sus Let's go gambling. Apoi are 2 butoane sub asta, unul se numeste Gamble your stats, iar celalalt Gamble your items. Pentru Gamble your stats dupa ce apesi te baga in alt meniu unde e o Roulette Table (…) vreau ca toate numerele de la Roulette Table sa mearga. (…) poti tu sa decupezi moneda rosie si sa o folosesti atunci cand player-ul da click pe un numar. Vreau sa ai niste optiuni in dreapta de Roulette Table ca sa selectezi ce statusuri vrei sa faci gamble cu ele. Vreau sa fie pe bune codata ruleta sa mearga random."

**Decis împreună înainte de scris:** miza = **„totul sau nimic"** (câștigi → statusul se dublează, pierzi → se înjumătățește, **la fel indiferent pe ce ai pariat**); „Gamble your items" = **buton gri „Coming soon"**; aparatul apare pe **2% din chunk-uri** și e **refolosibil**.

**1. Aparatul (`egt.gd` + `egt.tscn` + `egts.gd`).** Aceleași convenții ca statuia/cufărul: grupul `"interactable"` (deci primește „Press E to interact" gratis din `interact_ui.gd`), regula celor **74px** de acoperire sub linia de sortare, generator pe chunk-uri determinist cu salt propriu. Se ferește de copaci, pietre **și** de statuia chunk-ului (prin `Statues.chunk_statue_pos()`, care merge și pe chunk-uri neîncărcate). `poate_invoca()` întoarce **mereu `true`** — spre deosebire de statuie și cufăr, aparatul nu se consumă.

**⚠️ Scara stă pe Sprite2D, NU pe nodul rădăcină** (la cufăr e pe rădăcină). Motivul: dacă scara e pe rădăcină, `CollisionShape2D` se scalează odată cu ea și trebuie socotit invers de fiecare dată când umbli la mărimea artei. Așa, hitbox-ul rămâne în pixeli de lume.

**2. Cele 3 imagini derivate (`tool_egt_assets.gd`).** Poza mare `Roulette Table.png` (1648×954) nu se folosește direct: unealta scoate din ea **`table.png`** (fundalul alb → transparent; fără asta se vedea un dreptunghi alb în jurul mesei pe fundalul întunecat), **`wheel.png`** (discul roții decupat rotund, ca să-l pot roti separat) și **`chip_red.png`** (jetonul roșu, al 4-lea din rândul de jos). Ștergerea fundalului e **flood fill din margini**, nu un test de culoare pe toată imaginea — altfel dispăreau și liniile albe ale grilei, și albul de pe jetoane.

**3. Zonele de click — MĂSURATE, nu ghicite.** Am scanat poza după coloanele/rândurile de pixeli albi (liniile grilei) și de acolo au ieșit constantele din `casino.gd`: grila e `x 658→1486` (12 coloane de 69,0px) × `y 306→545` (3 rânduri de 79,67px), duzinile `y 547→623`, rândul de jos `y 626→703` (6 căsuțe egale). Fiecare zonă e un buton transparent legat prin **ancore** (fracții din poză), deci masa merge identic la orice rezoluție. Verificat pe rulare: pariul pe 17 pune jetonul fix pe căsuța lui, iar cele 6 căsuțe de jos cad exact pe 1-12 / EVEN / roșu / negru / ODD / 19-36.

**4. Ruleta e cinstită.** `randi() % 37` (0–36, ruletă europeană cu un singur zero), tras **înainte** de animație. Numerele roșii din `ROSII` sunt cele adevărate și **coincid număr cu număr** cu poza.

**🔑 Roata care se învârte e DECOR, și trebuie să rămână așa.** Ordinea numerelor desenate pe roată e **inventată de artist**: apare „38" (care nu există pe o ruletă), iar „29" e de două ori. Deci nu se poate opri fix pe buzunarul câștigător fără să mintă. De-aia rezultatul se anunță altfel: numărul apare în **butucul roții**, pe fundalul culorii lui, iar căsuța lui de pe masă se **încadrează cu auriu**. Dacă vreodată cineva vrea bilă care aterizează pe buzunar, trebuie întâi desenată o roată cu ordine corectă.

**5. Plafoanele de la statusuri nu sunt cosmetice.** O înjumătățire fără plafon te lăsa cu **0 proiectile** (nu mai tragi deloc) sau cu **0 viață maximă** (mori pe loc) — adică jocul se termina dintr-o rotire, altceva decât „pierzi jumătate din status". Minimele: proiectile 1, max HP 10 (și `hp` se mută cu aceeași cantitate, dar nu sub 1), damage 1, damage taken 1 (altfel devii invulnerabil la atingere), viteză 60. La `Attack Speed` se cheamă **`upgrade_fire_rate()`**, nu se scrie direct în `fire_interval` — altfel cronometrul de tragere rămâne pe valoarea veche și cadența nu se schimbă.

**⚠️ Statusurile pe 0 NU apar în listă.** Dublul lui 0 e tot 0, deci ar fi fost un pariu fără risc.

**⚠️ Matematica pariului, ca să se știe ce s-a ales:** la „totul sau nimic", roșu/negru are 18/37 = 48,6% șansă → valoare așteptată **1,23× din status pe rotire**, adică pariul e în favoarea jucătorului. Un număr plin are 1/37 și plătește la fel, deci e strict mai prost — nimeni n-are motiv să parieze pe număr. Dacă vrei să conteze pe ce pui, schimbi `CASTIG_MULT`/`PIERDERE_MULT` în plăți pe tip de pariu.

**6. ESC.** `pause.gd::_blocked()` întreabă acum și de grupul `"casino"` — altfel ESC deschidea meniul de pauză PESTE cazinou. În cazinou, ESC te duce un pas înapoi (masă → meniu → afară).

**⚠️ Căsuța „1-12" de pe poză** ar trebui să scrie „1-18" (așa e pe o masă adevărată). Am lăsat-o să facă exact ce scrie pe ea, ca să nu pară că jocul trișează; e o constantă, `JOS_MAXIM`.

**Traduceri:** 11 chei noi × 8 limbi; `tool_check_i18n` trece pe 203 chei. Numele pariurilor (RED/BLACK/EVEN/ODD/1st 12) rămân netraduse — sunt scrise în engleză chiar pe poza mesei.

**Verificat pe rulare reală** (nu pe hârtie): aparatul apare corect în lume cu eticheta deasupra, meniul se deschide și oprește jocul, pariul pe 17 cade pe căsuța potrivită, o rotire pierzătoare a dat Damage 24 → 12 și Move Speed 230 → 115, una câștigătoare (a ieșit chiar 17) a dat 24 → 48 și 230 → 460.

**Codexul NU s-a atins:** n-a apărut niciun item, nicio raritate și nicio cifră din `ARME`/`BASE` nu s-a schimbat. ⚠️ Dar dacă vreodată cazinoul ajunge să dea **iteme** („Gamble your items"), atunci codexul devine relevant.

---

## Session log — 2026-07-28 (inamicii revin din cerc + sabia chiar ajunge la Saratalin)

**Cerut de Răzvan:** „Vreau ca inamicii sa se spawneze in cerc, nu doar in fata playerului. E un bug la cursed sword nu da damage in saratalin decat foarte aproape"

**1. Spawn în cerc.** `spawn_cone_deg` înapoi la **180** (era 45 de pe 2026-07-22). Codul conului n-a fost atins, doar valoarea implicită — orice între 45 și 180 merge în continuare.

**⚠️ Ce nu se vedea din cerință:** `spawn_distance` = 700px e **mai mic decât ecranul**. Măsurat: se văd **1645×925px** de lume la zoom 0.7, deci colțul e la **944px**. În față nu se observa, dar în SPATE inamicii ar fi apărut pur și simplu în plin ecran. Am adăugat `_distanta_spawn()`: ia dreptunghiul vizibil din `canvas_transform` (inversată) și naște la `max(spawn_distance, jumătate de diagonală + spawn_margin)` → **1034px** pe fereastra de 1152×648, mai mult pe ecran mai mare. **Din transformare, nu din „viewport / zoom"** — altfel ignori scara părintelui camerei și pe alt telefon iese greșit.

**2. Bug-ul de la Cursed Sword.** `_sword_rect_hit()` compara **un singur punct** — centrul inamicului — cu dreptunghiul tăieturii. La un inamic normal (corp de 15px) nu se simte; la **Saratalin** (cerc de coliziune 46px, sprite 224×240) însemna că nu-i dădeai damage până nu-i intrai cu centrul în dreptunghi, adică până nu erai suprapus peste el. Gloanțele n-au avut problema: ele lovesc prin fizică, pe cercul de coliziune. Acum și sabia face **cerc vs. dreptunghi**, cu raza citită din `CollisionShape2D`-ul inamicului (`_raza_corp()`, măsurată o dată și ținută în `meta`, deci moare odată cu nodul).

**Verificat pe rulare:** dreptunghiul ajunge la **104,5px** în față; centrul lui Saratalin e prins până la **150,5px** (104,5 + 46). În jocul real, cu sabia: la 110px lua damage și înainte, **la 140px lua 0 înainte și 37 acum**, la 165px tot nimic (deci s-a lungit brațul, nu a devenit infinit). Spawn-ul, măsurat pe o rundă de 6 secunde: inamici în **toate cele 4 cadrane** (1/1/1/1), la 671–1028px, toți născuți dincolo de colțul ecranului.

**⚠️ Rămâne la fel (nu era în cerință):** aura Stingătorului și unda de șoc tot testează doar punctul-centru (`distance_to(enemy.global_position)`). Dacă vreodată pare că un boss nu simte aura lipit de el, acolo e.

**Codexul NU s-a atins:** nu s-a schimbat niciun item, nicio raritate și nicio cifră din `ARME`/`BASE` — doar raza la care lovește sabia.

---

## Session log — 2026-07-28 (item nou: 5G Tower + BUG vechi la XP, prins cu ocazia asta)

**Cerut de Răzvan:** „mai am un upgrade - upgrade_58 (epic) - 5G Tower - Enemies drop 15% more xp"

**Ce s-a făcut:** `p.xp_gain_mult += 0.15` (multiplicatorul exista deja, din meta-progresie) — 50 → **51 de iteme**. Dar itemul, așa cum era codul, **n-ar fi făcut absolut nimic**.

**🔑 BUG-UL (vechi, nu introdus acum):** `gain_xp()` făcea `xp += int(amount * xp_gain_mult)`, iar `int()` TAIE zecimalele. **Gema mică de XP valorează 1**, deci `int(1 × 1.15) = 1`. Adică orice bonus de XP sub +100% era **complet invizibil pe gemele de 1** — și alea sunt majoritatea a ce ridici. Nu doar 5G Tower era mort din start: și nivelurile de „XP gain" din magazinul permanent (+8% fiecare, până la +64%) nu făceau nimic pe gemele mici. Bug-ul era acolo dinainte; itemul nou doar l-a scos la lumină.

**Reparația:** `gain_xp()` ține acum restul sub 1 în `_xp_rest` și-l adaugă la următoarea gemă. La +15%, a șaptea gemă de 1 aduce 2 în loc de 1, iar pe termen lung totalul e exact procentul cerut.

**⚠️ Și un `+ 1e-9`, care nu e paranoia:** 1.15 nu se scrie exact în binar, așa că după 20 de geme suma ajungea la 22.999999… și `int()` dădea **22 în loc de 23**. Punctul nu se pierdea (rămânea în rest), dar cifrele n-ar mai fi fost cele pe care le socotește jucătorul. Cu epsilon iese fix 23. **Prins pe rulare, nu pe hârtie** — prima rulare a testului a scos 22 și de-aia am mai umblat o dată.

**Verificat pe rulare reală:** `xp_gain_mult` 1.00 → 1.15 → 1.30 la a doua luare (se ADUNĂ). 20 de geme de 1 la +15% → **23 XP** (înainte: 20). 5 geme de 10 → **57** (= 50 × 1.15). Iconița există și se încarcă.

**Traduceri:** 2 chei noi × 8 limbi. `tool_check_i18n`: 192 de chei, tot tradus.

**Codex:** card nou (epic, `isNew`) + iconița base64 + o notă în „Ce nu scrie în joc" despre bug-ul de rotunjire — e exact genul de lucru pe care jucătorul n-are cum să-l ghicească. Verificat: 51 de carduri complete, id-uri identice cu `levelup.gd`, toate iconițele au base64, randat în Chrome fără erori.

---

## Session log — 2026-07-28 (3 iteme noi: Hermes' Sandals · Aussie Special · Old Reliable)

**Cerut de Răzvan:** „3 new upgrades. upgrade_56 - Hermes' Sandals (legendary) - +100 Movement Speed +10% Attack Speed. upgrade_57 - Aussie Special (legendary) - Projectiles ricochet +1 time. upgrade_55 - Old Reliable (common) - Reflect 15% of damage taken (reflects everytime an enemy hits the player, stacks with Mike's Hedgehog but doesn't block the hit every 6s like that one does)"

**Ce s-a făcut:** 47 → **50 de iteme**. Două dintre ele au avut nevoie de mecanică nouă, nu doar de o linie în `_apply`.

**Hermes' Sandals** — `p.speed += 100.0` + `p.upgrade_fire_rate(0.90)`. Viteza e FIXĂ, nu procent ca la Hellas: pe 215 de bază e aproape jumătate în plus dintr-o singură luare, de-aia e Legendary. 🔑 **Convenția din fișier pentru cadență e `factor = 1 − procent`** (Rolling Papers „+10%" = 0.90), nu `1/1.1`. M-am ținut de ea ca să nu am două iteme scrise diferit; strict matematic, ×0.90 pe interval înseamnă +11.1% lovituri/s, nu +10%.

**Aussie Special** — mecanică nouă în `bullet.gd`: `ricochet` (câte sărituri au mai rămas) + `_loviti` (id-urile celor loviți deja). Când glonțul ar muri (`_hits > pierce`), în loc să dispară caută cel mai apropiat inamic nelovit în **420px** — **inclusiv în spate**, altfel n-ar fi ricoșeu — se întoarce spre el și primește o viață minimă de 1.2s (fără asta, un glonț care sare la ultima zecime de secundă n-ar apuca să ajungă). 🔑 **Ordinea contează:** întâi se consumă străpungerea, abia apoi sare — așa Drill și Aussie se adună în loc să se anuleze. 🔑 **`_loviti` nu e paranoia:** cu doi inamici lipiți unul de altul, un glonț fără memorie ar sări înainte-înapoi între ei la nesfârșit.

**Old Reliable** — `reflect_pct` în player.gd, aplicat în `_take_contact_damage()` pe RAMURĂ SEPARATĂ de Mike's Hedgehog, deci se adună cu el exact cum a cerut. Diferența: ariciul reflectă 100% **și te apără**, o dată la 6s; ăsta reflectă 15% din **fiecare** lovitură și nu apără deloc. 🔑 **Minim 1 damage:** la începutul rundei damage-ul de contact e 5, iar 5 × 15% = 0.75 s-ar fi rotunjit la **zero** — itemul ar fi părut stricat exact în minutele în care îl iei.

**Traduceri:** 6 chei noi (3 nume + 3 descrieri) × 8 limbi, adăugate în `i18n.gd`. `tool_check_i18n` zice „TOTUL E TRADUS" pe 190 de chei.

**Verificat pe rulare reală:** Hermes → speed 215→315, interval 0.750→0.675 (1.33→1.48 lovituri/s). Old Reliable → `reflect_pct` 0.15, damage de contact 5 → reflect 1, iar după 3 lovituri inamicul a pierdut exact 3 HP (deci chiar nu are cooldown). Aussie → glonțul a lovit inamicul din traiectorie ȘI pe al doilea, pus intenționat în lateral unde numai un ricoșeu ajunge, apoi a dispărut. Plus poză cu toate trei pe cardurile REALE din meniul de level up (chenare de raritate corecte, iconițe întregi).

**Codex actualizat și republicat:** 3 carduri noi (cu `isNew`) + iconițele base64 + o notă în „Ce nu scrie în joc" despre cum se adună Old Reliable cu ariciul. Verificat: 50 de carduri, fiecare cu `game:` și `eff:`, id-urile identice cu `levelup.gd` (`diff` gol), fiecare iconiță folosită are base64, randat în Chrome fără erori.

**⚠️ Rămas nerezolvat, spus pe față:** descrierea lui Hermes' Sandals („+100 Movement Speed +10% Attack Speed") e cea mai lungă din joc și **se rupe pe două rânduri** pe cardul de level up. Nu clipește nimic și nu iese din card, dar dacă vrea un rând, „Move Speed" în loc de „Movement Speed" ar încăpea (așa scrie și Hellas). N-am schimbat textul: e copy-ul lui.

---

## Session log — 2026-07-28 (codexul: secțiune nouă „Statusuri de start")

**Cerut de Răzvan:** „Pune in artfact care sunt default stats - ce statusuri are playerul cand incepe un run"

**Ce s-a făcut:** secțiune nouă în `codex.html`, prima după hero: două tabele — `ARME` (ce depinde de arma aleasă) și `BASE` (identic la toate patru). Republicat pe același URL.

**🔑 Cifrele NU sunt citite din cod, sunt scoase rulând jocul.** Scenă de test care instanțiază player-ul cu fiecare din cele 4 arme și tipărește `stat_lines()` — adică exact rândurile pe care le vede Răzvan în panoul din meniul de level up, nu o listă paralelă care poate să se rupă de joc.

**⚠️ Meta-progresia trebuia scoasă din ecuație.** `_apply_meta()` rulează în `_ready()`, deci un player instanțiat pornește cu upgrade-urile CUMPĂRATE (salvarea lui Răzvan are `damage: 3, speed: 1`). Am golit `GameSettings.upgrades` **doar în RAM** înainte de instanțiere, ca să iasă baza curată; nu se cheamă nimic care salvează. Verificat cu `md5sum` pe `scores.save` înainte și după — neatins. Tabelul spune explicit că peste el se adaugă magazinul.

**Statusurile de start (fără meta):** Max HP 100 · Regen 0 · Speed 215 · Crit 0% (×2) · Instakill 0% · Luck 0 · Projectiles 1 · Pierce 0 · Weapon Size 100% · Knockback 0 · Damage Taken 5 la 0.5s sub 60px · XP pentru nivelul 2 = 20 (prag ×1.2/nivel). Pe armă: pistol 15 @1.33/s, mage 10 @2.00/s, extinguisher 12 @1.33/s (**16** pe puls: 10 + jumătate din 12), sabie 20 @1.33/s (**28** pe tăietură: 8 + 20).

**Montaj:** o singură trecere de `sed` cu două `-e 'Nr fisier'` (datele după array-ul META, render-ul după `app.append(hero, …)`), din fișiere scrise cu Write — deci diacriticele n-au trecut prin literale de shell. Zero stiluri noi: refolosește tabelul din „Magazin permanent" (`.shop-scroll` + `.num` cu cifre tabulare).

**Verificat:** randat în Chrome headless (fără erori, poză), 47 carduri cu `game:` + `eff:` fiecare, iar id-urile din codex vs `levelup.gd` — `diff` gol. La publicare am primit 409 („sesiunea n-a văzut ultima versiune"); am luat versiunea publicată cu WebFetch și am comparat-o cu baza locală — **identice**, deci n-avea nimeni altcineva modificări de pierdut. Fără `force`.

---

## Session log — 2026-07-28 (inamicii se opresc la marginea player-ului, fără să se lipească)

**Cerut de Răzvan:** „Vreau ca inamicii sa nu treaca prin sprite-ul de la player. Vreau inamicii sa nu mai treaca prin player, vreau sa se opreasca cand se lovesc sprite-urile. Dar nu vreau sa fie iar bugul de se lipesc unul de altul"

**Ce s-a făcut:** oprire **pe distanță, în cod** (`enemy.gd`), NU coliziune fizică. `stop_dist` = 41 la polițist, 53 la creatura din Nether (`enemy_nether.tscn`).

**🔑 De ce nu prin layere de coliziune** — asta e tot răspunsul la „nu vreau iar bug-ul". Bug-ul vechi venea exact din fizică: inamicii se opreau unul în altul și se strângeau ciorchine, iar player-ul era împins de gloată. Layerele au rămas **neatinse** (toți au `mask = 1`, adică doar obstacolele), deci fizica nici nu știe unii de alții — nu are ce să se lipească și nu are ce să împingă. Oprirea e o socoteală de distanță în `_viteza_mers()`.

**De unde ies cifrele:** măsurate pe pixelii chiar desenați (`get_used_rect()`, fără marginea transparentă), în px de lume: player 30×58 (jumătate de lățime **15**), polițist 53×87 (**26**), creatura din Nether 75×81 (**38**). 15+26 = **41**, 15+38 = **53**.

**⚠️ Plafonul de 60 e obligatoriu, nu decorativ.** Damage-ul de contact se dă tot pe distanță (`player.contact_range = 60`), deci un inamic care s-ar opri mai departe de-atât **nu te-ar mai atinge niciodată** — jocul ar deveni imposibil de pierdut, în tăcere. `_oprire()` plafonează la `contact_range - 6` și scrie un warning în consolă. Dacă vreodată un inamic nou e mai lat, se mărește `contact_range`, nu se micșorează pe furiș oprirea.

**Trei cazuri în `_viteza_mers()`:** peste `stop` → merge normal; între `stop-4` și `stop` → stă (aici se ating desenele); sub `stop-4` → **iese înapoi** din player. Al treilea nu e teoretic: player-ul nu e oprit de nimeni (așa a fost cerut), deci intră EL peste inamici. Ieșirea merge cu viteza întreagă, nu cea încetinită de gheață, altfel un inamic înghețat prin care ai trecut ar sta secunde bune peste tine.

**🔑 Bug prins de test, nu de ochi:** dacă player-ul nimerește **exact** centrul unui inamic, `normalized()` pe vectorul nul dă tot zero → inamicul rămânea înțepenit în player pe veci (fix bug-ul de care fugeam). Acum are o direcție de ieșire fixă per inamic (din `get_instance_id()`), aceeași la fiecare cadru (ca să nu vibreze) dar diferită între ei (ca doi suprapuși să nu plece în același sens).

**Verificat pe rulare reală:** patru polițiști din patru părți + o creatură de Nether s-au oprit toți la 40.0 px (zona bună 37–41), Nether-ul la 51.0 (49–53), toți sub `contact_range` — deci încă te lovesc. Teleportat player-ul peste unul, de două ori (suprapunere perfectă și 10.8 px): a ieșit la 38.0, respectiv 38.8. Plus poză de aproape, cu Y-sort pornit ca în lume.

**Ce NU rezolvă (spus pe față):** lateral desenele se ating curat, dar **sus-jos tot se suprapun pe ecran** — sprite-urile au 58–87px înălțime, sunt centrate pe nod, iar inelul are doar 41px. E comportament normal de joc top-down (Y-sort desenează în față pe cine e mai jos) și nu poate fi lărgit peste ~54 fără să pice damage-ul de contact. **Boss-ii nu sunt incluși:** `garda.gd` și `saratalin.gd` au codul lor de urmărire și încă intră peste player.

---

## Session log — 2026-07-28 (sunet la cheie și la cufăr: Key Pickup · Chest Opening · Chest Animation)

**Cerut de Răzvan:** „ti am adaugat la audio - Key Pickup - se aude atunci cand ridici o cheie de pe jos. si Chest Animation - incepe dupa ce s-a deschis chest-ul si incepe animatia. Ti-am mai bagat si Chest Opening, se aude atunci cand apesi E sa deschizi chest-ul"

**Ce s-a făcut:** trei intrări noi în `Audio.SFX` (`key_pickup` / `chest_open` / `chest_anim`) și trei locuri de unde se cheamă — `key.gd::_on_body_entered`, `chest.gd::invoca()` și `chest.gd::_capac_ridicat()`.

**🔑 Cheia nu se auzea deloc până acum.** `key.gd` cerea `Audio.play("xp", -3.0)`, iar `"xp"` a fost șters din `SFX` demult (n-avem fișier) — `play()` iese tăcut când numele nu există, deci ridicatul unei chei era mut de la bun început, nu de azi. Acum are sunetul ei.

**🔑 Cele două sunete de cufăr NU pornesc odată.** `chest_open` intră fix pe apăsarea lui E, iar `chest_anim` abia când animația capacului s-a terminat (semnalul `animation_finished` al lui `AnimatedSprite2D`, adică ~0.43s la `open_fps = 7`) — exact cum a cerut, „după ce s-a deschis chest-ul". Numerele arată că se așază bine: `Chest Opening` are 1.64s și e deja la ~-10 dBFS când intră al doilea, explozia de raze ține ~2.4s, iar `Chest Animation` are 1.50s, deci încape întreagă peste ea. Dacă le vrea odată, se mută o linie (scrie în comentariu unde).

**Volume:** `open_db = 0`, `anim_db = +3`, amândouă `@export` pe cufăr (se reglează din inspector, ca `open_fps`). Cei +3 nu sunt gust: măsurat cu `tool_audio_info`, `Chest Animation` are vârful la **-12 dBFS** față de 0 la `Chest Opening` (rms aproape egal, -27.6 vs -27.8), deci la volum egal momentul de recompensă s-ar fi auzit mai șters decât scârțâitul capacului. Rămâne mult cap până la tăiere. `pitch_rand = 0` la toate trei: sunt evenimente rare și „compuse", iar un ton ușor diferit de fiecare dată sună ieftin (aceeași alegere ca la `teleport` și `saratalin_flash`).

**Verificat pe rulare reală** (scenă de test, ștearsă după): toate trei fișierele s-au încărcat în `Audio._streams`, iar boxele chiar cântau — la ridicarea cheii `["key_pickup"]`; la apăsarea E `["chest_open"]`, la 0.30s tot doar el, iar de la 0.55s `["chest_open", "chest_anim"]`. Cheia s-a și consumat corect (2 → 1).

**⚠️ WAV-urile noi n-aveau `.import`.** Godot nu importă singur la o rulare directă, doar la deschiderea editorului, deci a trebuit `--headless --path . --import` înainte de orice test. Valabil de fiecare dată când Răzvan pune fișiere noi în `audio/`.

---

## Session log — 2026-07-27 (viteză înjumătățită, fiecare armă cu plusul și minusul ei, contur galben pe cheie)

**Cerut de Răzvan:** „vreau playerul Sa inceapa cu speed de 2x mai putin. Fiecare arma vreau sa aibe un avantaj si dezavantaj. Pistolul are 15 damage dar attack speed mai mic(e prea mare asta de e acum la inceput fa-l cu 1.5x mai putin). Fire staff are 10 damage dar attack speed mai mare(cu 1.5x mai mult decat la pistol) la stingator are 12 damage si attack speed ca la pistol. la cursed sword 20 damage si attack speed ca la pistol. Cheia sa aiba un stroke galben de 1px"

**Ce s-a făcut:** `speed` 300 → **150**; tabelul `ARME` la începutul lui `player.gd` + `_aplica_arma()`; `key_contur.png` din `tool_contur_foaie.gd`.

| armă | damage | interval | lovituri/s |
|---|---|---|---|
| pistol | 15 | 0.75 | 1.33 |
| mage staff | 10 | 0.50 | 2.00 |
| extinguisher | 12 | 0.75 | 1.33 |
| cursed sword | 20 | 0.75 | 1.33 |

**🔑 `_aplica_arma()` se cheamă ÎNAINTE de `_apply_meta()`.** Invers, arma ar fi ȘTERS ce a cumpărat din magazin (meta scrie `bullet_damage += ...`, deci trebuie să se adune peste valoarea armei, nu să fie suprascrisă). Pe salvarea lui Răzvan (Damage nivel 3 = +9) numerele văzute în joc sunt 24/19/21/29, nu 15/10/12/20 — diferențele dintre arme se păstrează exact.

**🔑 `sword_slow_start` (1.9×) a DISPĂRUT.** Era acolo intenționat, ca sabia să pornească lentă și să simți creșterea de attack speed. Dar a cerut explicit „attack speed ca la pistol", deci dezavantajul sabiei rămâne raza, nu viteza. L-am spus, nu l-am ascuns.

**⚠️ Consecința vitezei — spusă pe față:** la 150, polițiștii (120 de bază, +3.5%/minut) te ajungeau pe la minutul 7 și făceau 264 la plafon = 1.76× cât tine, iar creaturile din Nether (190) erau mai rapide din prima secundă. **A doua zar, la câteva minute după: „fa viteza basic cu 35% mai rapid decat e acum" → 150 × 1.35 = 202.5.** Măsurat cu matematica reală a jocului (pe salvarea lui, cu Speed nivel 1 = 217.5): polițiștii te depășesc abia la **12:12** (deci toată faza 1 le fugi) și fac 264 la plafon = **1.21×**; creaturile din Nether te depășesc la **4:12** din rundă și ajung la 418 = **1.92×**. Pe viteza curată (202.5): ~11:37, respectiv ~1:53. Concluzia care contează: **în lume poți fugi, în Nether nu.**

**A treia rundă, tot în aceeași zi: „viteza initiala vreau sa fie de 215"** → `speed = 215`, cifră fixă, nu procent. Măsurat din nou (pe salvarea lui, 230 cu meta): polițiștii te depășesc la **12:36**, plafon 264 = **1.15×**; creaturile din Nether la **6:06**, plafon 418 = **1.82×**. Deci și în Nether ai acum jumătate de rundă în care le fugi, nu doar două minute.

**Tot atunci: „fa tot textul Press E to interact / you need a key ... de 2x mai mic"** → în `interact_ui.gd`, font 28 → **14**. 🔑 **Conturul a trebuit coborât ODATĂ cu fontul** (6 → 3): la 14px, un contur de 6 e mai gros decât liniile literelor, iar textul iese ca o pată neagră. Toate textele de structuri (statuie, portal, portal de invocare, cufăr, cufăr încuiat) vin din ACEEAȘI etichetă, deci s-au micșorat toate dintr-un singur loc.

**Conturul cheii:** `tool_contur_foaie.gd` știe acum o culoare PE LUCRARE (`"culoare"`, implicit movul) și acceptă imagini simple cu `"cadre": 1`. Scrie `key_contur.png`; `key.png` rămâne neatins, deci unealta se poate rula oricând fără să se îngroașe conturul. Îl folosesc și obiectul de pe jos, și iconița din HUD.

**Verificat pe rulare reală,** instanțiind player-ul cu fiecare din cele 4 arme: intervalele au ieșit exact 0.750 / 0.500 / 0.750 / 0.750 (adică 1.33 și 2.00 lovituri/s), viteza 150 + 15 din meta = 165. Plus poză cu cheia conturată pe jos și în HUD — la scara 0.45 conturul de 1px se vede bine, fiindcă desenul cheii e subțire și galbenul e o bună parte din siluetă.

---

## Session log — 2026-07-27 (fără cufere și fără poteci în Limbo)

**Cerut de Răzvan:** „chest-urile nu vreau sa se spawneze in limbo si nici path-urile"

**🔑 Au fost DOUĂ probleme, nu una.** `Chests` lipsea pur și simplu din `WORLD_NODES` — asta era ușor. Dar `Paths` **nu e în `World`**, e frate cu el, direct sub `Main`. Bucla veche din `limbo.gd` se plimba doar prin copiii părintelui player-ului, deci n-avea CUM să găsească potecile, oricâte nume i-ai fi pus în listă. A fost nevoie de a doua listă, `ROOT_NODES`, exact ca în `nether.gd` (care avea deja despărțirea asta din 2026-07-26).

**De reținut:** dacă mai adaugi un generator de decor, întreabă-te întâi **unde stă în `main.tscn`** — în `World` sau lângă el. Cele două dimensiuni (Limbo și Nether) au fiecare două liste tocmai din motivul ăsta, iar acum arată la fel.

**Verificat pe rulare reală, cu numărătoare, nu din ochi:** în lume `Chests` avea 81 de containere de chunk cu un cufăr desenat și `Paths` 48 de tile-uri; în Limbo amândouă 0 și invizibile; după întoarcere, exact aceleași cifre ca înainte (golirea lui `_loaded` e ce face ca reîntoarcerea să meargă). Plus poze din toate cele trei momente.

**Observat, NEatins:** frunzele care cad (`leaffall.gd`, din `Atmosphere`) continuă să cadă și în Limbo — `Atmosphere` nu e generator de decor, deci nu intră în listele astea. Într-o lume goală, fără copaci, arată ciudat. I-am spus; n-a cerut-o.

---

## Session log — 2026-07-27 (Saratalin plătește 3 niveluri când moare)

**Cerut de Răzvan:** „Dupa ce moare Saratalin, iti da 3 levele de upgrade orice level ai avea in momentul ala"

**Ce s-a făcut:** `player.gd::da_niveluri(n, cu_sunet)` + chemarea din `saratalin.gd::_die()`.

**🔑 Sunt niveluri ADEVĂRATE, nu 3 ecrane de ales.** Crește `level` cu 3 și urcă pragul de XP de 3 ori (×1.2 fiecare), exact ca o creștere normală. Dacă dădeam doar 3 ecrane, „nivel" ar fi însemnat aici altceva decât în tot restul jocului. Ecranele se așază singure la rând: `levelup.open()` are deja un contor pentru cazul „ai urcat mai multe niveluri deodată".

**🔑 Timer legat de PLAYER, nu `await` în `saratalin.gd`.** Boss-ul se șterge (`queue_free`) la capătul animației de moarte, iar un `await` pe un nod mort nu se mai reia NICIODATĂ — premiul s-ar fi pierdut în tăcere. Legăm `timeout` direct de metoda player-ului; dacă moare și el între timp, Godot rupe singur legătura (semnalele către un obiect șters se desfac).

**De ce 1.4 secunde întârziere:** fără ea, ecranul de level up pune jocul pe pauză PESTE animația de moarte a boss-ului și peste anunțul „THE WAY IS OPEN" — nu apucai să vezi că l-ai omorât.

**De ce fără jingle:** `nether.gd::boss_invins()` pornește FIX același sunet („levelup") ca fanfară de „drumul e liber", cu un cadru înainte. Încă unul peste el sună dublat, nu mai festiv. De aia `_level_up()` a primit un parametru `cu_sunet`.

**Verificat pe rulare reală, pornind de la un nivel oarecare (7, nu 1):** level 7 → **10**, prag XP 55 → **94** (exact trei pași de ×1.2), fix **3** ecrane de ales unul după altul, iar după al treilea jocul se depauzează.

---

## Session log — 2026-07-27 (cuferele se deschid cu CHEI, 0.5% drop de la inamici)

**Cerut de Răzvan:** „Ti-am pus o poza in folderul chest, se numeste key. Vreau sa trebuiasca sa ai chei ca sa poti sa deschizi chest-uri. 1 key = 1 chest. Key poate fi dropat doar cand omori un inamic, la fel ca xp-ul. Doar ca are sansa de drop de 0.5% per inamic mort."

**Ce s-a făcut:** `key.tscn` + `key.gd` (obiect de cules, ca gema de XP), `GameSettings.run_keys`, dropul în `enemy.gd::_drop_xp`, cufărul cere cheie, contor pe HUD.

**🔑 `foloseste_cheie()` VERIFICĂ ȘI SCADE într-o singură chemare.** Dacă cel care cheamă ar întreba întâi „am cheie?" și abia apoi ar scădea, două cufere deschise în același cadru ar trece amândouă cu o singură cheie. Regula „1 key = 1 chest" trăiește într-un singur loc, în `game_settings.gd`.

**🔑 Cufărul încuiat rămâne cu `poate_invoca()` = true.** Dacă întorcea `false`, `interact_ui.gd` nu mai afișa NIMIC deasupra lui și cufărul arăta ca un obiect de decor — n-ai fi știut niciodată de ce nu se deschide. În loc de asta, `interact_ui.gd` a primit un cârlig nou, opțional: dacă obiectul are `eticheta()`, textul vine de la el. Cufărul fără cheie zice **„You need a key"** (tradus în toate cele 9 limbi, verificat cu `tool_check_i18n.tscn`).

**🔑 `key.gd` e mult mai simplu decât `xp.gd`, INTENȚIONAT.** Gema de XP are toată mașinăria de contopire în bule fiindcă în Final Swarm cad mii și omoară framerate-ul. Cheia cade la ~200 de morți, deci n-are cum să se strângă grămadă — copiat doar pulsul, plutirea și magnetul (rază 150 în loc de 130: un obiect atât de rar n-ai vrea să-ți scape pe lângă picior).

**Rata NU scalează cu nimic** — nici cu dificultatea, nici cu norocul. Așa „câte chei iau pe rundă" e pur și simplu „kill-uri ÷ 200". Măsurat pe 5000 de morți: **26 de chei = 0.52%** (și 22, și 28 la alte rulări — exact zgomotul așteptat pentru 0.5%).

**Ce am adăugat FĂRĂ să ceară, fiindcă altfel nu se putea juca:** contorul de chei pe HUD (iconița lui `key.png` + cifra, sub KILLS). Fără el n-ai cum să știi dacă merită să te duci la un cufăr. I-am spus.

**Verificat pe rulare reală:** cules → run_keys 0→1; E fără cheie → cufărul rămâne închis și contorul rămâne 0; E cu 2 chei → se deschide și rămâne exact 1. Plus poze: cheia pe jos, cufărul încuiat cu textul, cufărul deschis.

---

## Session log — 2026-07-27 (cufărul dă un upgrade random + explozia multicoloră)

**Cerut de Răzvan:** „ti-am pus un folder nou in chest, se numeste Chest Animation 2 - e o animatie de mai multe culori intr-o singura poza, faci tu frame-urile. Vreau ca fiecare frame sa fie randomizat cu o culoare diferita, mereu arata altfel. Animatia vreau sa apara cand deschizi chestul deasupra lui si vreau sa iti dea un upgrade random din toate care sunt bagate in joc. dupa ce se termina animatia o sa apara iconita de la upgrade 2 secunde dupa sa isi ia fade out."

**Ce s-a făcut:** `chest_fx.gd` (nod din cod, fără scenă — ca `firetrail.gd`) + `levelup.gd::da_random_acum()`.

**🔑 Foaia NU s-a tăiat în fișiere.** `652.png` e 1024×576 = **16 coloane (cadrele) × 9 rânduri (culorile)**, celule de 64×64, fundal transparent, aceeași formă în 9 culori (verificat: 561 de pixeli opaci în fiecare rând). Cadrele se decupează la rulare cu `AtlasTexture` — 144 de PNG-uri ar fi fost aceeași imagine de 144 de ori.

**🔑 „Fiecare cadru altă culoare" = rândul se trage la întâmplare PENTRU FIECARE CADRU**, cu o singură regulă: niciodată aceeași culoare de două ori la rând (altfel se vede ca o sacadare, nu ca o pâlpâire). Măsurat pe 3 rulări: 6-9 culori folosite din 9, 0 repetări consecutive.

**🔑 Efectul se agață de `World`, NU de cufăr.** Cufărul stă într-un container de chunk care se ȘTERGE când te îndepărtezi; ca fiu al lui, animația ar fi murit la jumătate, iar `await`-urile ar fi rămas agățate de un nod mort. (Notă: `statue.gd::_rise_enemy` pune boss-ul invocat în `get_parent()`, adică fix în containerul de chunk al statuii — dacă fugi ~1500px de statuie, containerul se descarcă și boss-ul dispare din luptă. N-am atins-o, dar merită reparată.)

**🔑 Upgrade-ul se dă la DESCHIDERE, nu la sfârșitul animației** — dacă mori sau pleci în cele ~3.4 secunde, tot l-ai luat. Animația doar ARATĂ ce ai primit.

**Alegere de echilibru, spusă lui Răzvan:** „random din toate" l-am făcut cu **aceeași tragere ca la level up** (`_trage_unul`), nu uniform peste cele 47. Uniform ar fi însemnat 5 legendare / 47 iteme = **10.6% șansă de Legendary dintr-un cufăr**, față de 2.5% la level up — de 4 ori mai probabil, la 35% din poteci. Așa, rarităţile și norocul rămân cele din joc. Verificat pe 300 de trageri cu noroc 0: **40.7 / 32.7 / 16.0 / 8.3 / 2.3%** = exact tabelul din `RARITY_CHANCE`.

**⚠️ Lucky Die e scos din tragerea cufărului.** Efectul lui e „mai dă-mi o pagină de iteme", iar cufărul nu deschide nicio pagină — ar fi fost pur și simplu un cufăr irosit.

**Capcană Godot:** un `SpriteFrames.new()` vine DOAR cu animația `"default"`. Fără `add_animation("boom")`, `set_animation_speed`/`add_frame` dau „Animation 'boom' doesn't exist" și animația iese goală. (`statue.gd` scapă fiindcă folosește chiar `"default"`.)

**Verificat pe rulare reală, de 3 ori:** diferența pe proprietățile player-ului a arătat de fiecare dată alt upgrade aplicat cu adevărat (Borat's Mankini, Bloody Situation, Rabbit's Foot), nodul de efect s-a șters singur (0 rămase), plus poze din fiecare fază: explozie → iconiță → fade.

**Reglaj cerut imediat după:** „Animatia fa-o de 3x mai SLOW - si de 2x mai mica. Poza de upgrade fa-o de 2.5x mai mica" → `BURST_FPS` 20 → **6.67** (16 cadre: 0.8s → **2.4s**), `BURST_SCALE` 2.0 → **1.0** (128px → 64px), `ICON_SCALE` 0.9 → **0.36** (115px → 46px). Toată secvența ține acum ~5s de la apăsat E până dispare iconița.

**Și încă un reglaj, imediat după:** „Fa upgrade-urile la chest de 2x mai mari si sa stea doar jumate din timp" → `ICON_SCALE` 0.36 → **0.72** (46px → 92px), `PAUZA` 2.0 → **1.0**. „Cât stă pe ecran" l-am citit ca timpul cât stă NEATINSĂ (ăla pe care l-a cerut inițial: „2 secunde"), nu ca total cu tot cu fade — deci fade-ul a rămas 0.6s, iar iconița se vede în total ~1.6s. Măsurat pe rulare: apare la 2.40s de la apăsat E, începe să se stingă la 3.41s, dispare la 4.00s.

**⚠️ Capcană la verificat, nu la cod:** prima măsurătoare părea să arate că efectul „nu se mai șterge" (rămânea 1 nod viu la final). De fapt testul se oprea la 5.8s, iar secvența abia se termina la ~5.9s — plus `save_png` la 1920×1080 mănâncă ~0.4s de ceas real la fiecare poză, deci momentele cerute se duc în urmă. Cu prints pe stare (cadrul curent, `is_playing`, alpha iconiței) s-a văzut imediat că totul mergea corect. **Când un test „pică" pe timing, întâi verifică ceasul testului.**

---

## Session log — 2026-07-27 (cufere lângă poteci, la 20px, pe 10% din poteci)

**Cerut de Răzvan:** „ai un nou folder in harta, se numeste Chest - Vreau sa se spawneze chest-uri in jurul Pathblock-urilor, adica la o distanta de 20px de un path. Nu vreau sa fie la fiecare path, vreau sa aiba o rata de spawn de 10% langa orice path. Vreau sa aiba un scris tot ca la statuie Press E to interact. Si cand apesi E face animatia."

**Ce s-a făcut:** `chest.tscn` + `chest.gd` (StaticBody2D, AnimatedSprite2D cu cele 3 cadre din `harta/Chest/Chest Animation/`) și `chests.gd`, nod nou în `World` din `main.tscn`.

**🔑 Primul generator care se agață de ALT generator, nu de grila de chunk-uri.** Ceilalți (copaci, pietre, statui, portaluri) dau cu zarul pe chunk. Ăsta întâi întreabă `Paths` ce tile-uri are poteca chunk-ului și abia apoi aruncă cei 10% — altfel „10% din poteci" ar fi însemnat de fapt „10% din chunk-uri", adică de zece ori mai multe cufere.

**🔑 `pathways.gd` a primit `path_tiles(key)`, nu m-am legat de `_raw_path()`.** O potecă prea apropiată de o vecină CEDEAZĂ (`_yields_to_neighbor`) — are tile-uri brute, dar nu se desenează niciodată. Cu `_raw_path()` ar fi apărut cufere singure pe iarbă, lângă o potecă invizibilă.

**🔑 Cei 20px se măsoară de la MARGINEA cufărului, nu de la originea nodului.** Cufărul are ~102px lățime; dacă puneam originea la 20px de potecă, jumătate din ladă intra peste pământ. De aia `chest.gd` are `cutie()` (Rect2 cu arta față de origine) și e `static`, ca generatorul s-o poată cere fără să existe încă un cufăr.

**🔑 Se ferește de PIETRE (130px).** Pietrele sunt singurul decor care NU se ferește de poteci (`rocks.gd` nici nu se uită la ele), deci pot sta exact unde ar cădea cufărul. Copacii nu sunt o problemă: `props.gd` ține 2 tile-uri libere de fiecare parte a potecii. Verificarea se face în jurul chunk-ului în care CADE cufărul, nu al celui care a pornit poteca — o potecă lungă se întinde pe 2-3 chunk-uri.

**Verificat pe rulare reală, pe 14 400 de chunk-uri:** 655 de poteci desenate → 59 de cufere = **9.0%** (restul de 1% se pierde la pietre), gol până la potecă **exact 20.0px la toate** (min = max), cea mai apropiată piatră 146px. Plus 4 poze: cufăr închis cu textul deasupra, player-ul ascuns în spatele lui (y-sort corect), cadrul din mijloc al animației și cufărul deschis cu textul dispărut.

**Detaliu de UI:** `interact_ui.gd` avea o singură înălțime pentru text (`world_offset_y = -175`, potrivită statuii). Peste un cufăr de 90px textul cădea fix pe capac, așa că fiecare obiect poate acum cere `label_offset_y` (cufărul: -125, adică peste capacul RIDICAT, care urcă la -85). Cine n-o are rămâne pe valoarea veche.

**⚠️ Cufărul nu dă NIMIC deocamdată** — s-a cerut doar animația. Cârligul pentru recompensă e la sfârșitul lui `chest.gd::invoca()`.

**Rundă 2, aceeași zi — „fa spawn-rateu la chesturi de la 10% la 35%".** `chest_chance = 0.35`. Măsurat din nou: 655 de poteci → 230 de cufere = **35.1%**.

**🔑 Între timp Răzvan reglase `chest.tscn` din editor (`scale = 0.7`, hitbox 150×50) — și asta STRICASE cei 20px.** `cutie()` întorcea cifrele din textură (102×91), deci generatorul credea cufărul cu 43% mai mare decât e și îl împingea la ~35px de potecă, nu la 20. Reparat: `cutie()` nu mai e `static`, înmulțește cu `scale`, iar `chests.gd` **măsoară un exemplar de probă** (`_cutie_cufar()`, făcut o dată și aruncat) în loc să aibă cifrele scrise în el. Acum, orice scară pune el în editor, distanța rămâne 20. Verificat: min = max = 20.0px la toate cele 230.

**De reținut:** ăsta e al doilea caz (după hitbox-ul portalului, 2026-07-26) în care o valoare reglată cu mâna în editor și o valoare scrisă în cod se bat cap în cap. Regula care iese: **codul citește ce e în scenă, nu presupune.**

---

## Session log — 2026-07-27 (Nether-ul are inamicii lui: creaturile violete, mult mai rapide)

**Cerut de Răzvan:** „Ti-am facut un folder in homeless directii, se numeste Nether Enemies, vreau in nether sa se spawneze doar baietii astia, sunt mult mai rapizi ca enemies normali."

**Ce s-a făcut:** 8 GIF-uri (o direcție fiecare, 4 cadre, 124×124) → 32 PNG-uri în `homeless directii/Nether Enemies/frames/` → `enemy_nether_frames.tres` → `enemy_nether.tscn` (**același `enemy.gd`**, doar alte cadre și `speed = 190` față de 120 la polițist). În Nether curg numai ei.

**🔑 Sunt DOUĂ locuri care nasc inamici în Nether, nu unul.** `nether.gd` face valul de la intrare (`BURST = 25`) — acolo scena nouă e pusă direct, fiindcă acolo ești prin definiție în Nether. Dar **spawner-ul rundei CONTINUĂ să lucreze cât ești dincolo** (Nether-ul nu-l oprește, cum face Limbo), deci și el trebuie să aleagă: `_scena_inamic()` întreabă nodul din grupul `"nether"` dacă `active`. Dacă schimbam doar `nether.gd`, în Nether ar fi curs în continuare polițiști din spawner.

**🔑 `.tres`-ul de animații e GENERAT, nu scris de mână** (`tool_frames_nether.gd`). 8 direcții × 4 cadre = 32 de referințe cu UID; scrise de mână, o greșeală se vede abia la rulare ca „resource not found". Unealta le încarcă cu `load()` și se plânge pe loc dacă lipsește vreun cadru.

**🔑 GIF → PNG: `tool_taie_gifuri.ps1`** (rămâne în repo, ia folderul ca parametru). Godot nu încarcă GIF-uri, iar pe mașina asta nu există ImageMagick/ffmpeg/Python — System.Drawing din .NET citește cadrele (`FrameDimension.Time`). Fiecare cadru se desenează pe o pânză goală, altfel GIF-urile cu cadre parțiale ies mânjite. După tăiere, OBLIGATORIU `--import`.

**Verificat pe rulare reală, cu numărătoare:** în lume → „polițiști: 2 · creaturi Nether: 0", viteze `[120]`; după `nether.enter()` → „polițiști: 0 · creaturi Nether: 24", viteze `[190, 191]`. Plus două poze: grila cu toate cadrele (curate, fără mânjeli de la GIF) și una din joc, din Nether.

**⚠️ De reținut pentru echilibru:** polițiștii sunt plafonați de `SPEED_CAP` (2.2×) la 264 px/s, adică **mereu sub cei 300 ai player-ului** — de aia poți fugi de ei la nesfârșit. Creaturile astea pornesc de la 190, deci după destul Nether Swarm trec de 300 și **nu mai poți fugi**. *(Depășit la câteva ore după: pe 2026-07-27 viteza player-ului a coborât la 202.5, deci acum și polițiștii te prind — vezi log-ul „viteză înjumătățită…" de mai sus.)* E consecința directă a lui „mult mai rapizi"; i-am spus. Se reglează din `speed` pe `enemy_nether.tscn`.

**Notă:** testul cu player-ul lăsat pe loc a murit în 3 secunde (25 de creaturi rapide în jur) — a scris în leaderboard, dar 0:03 n-a intrat în top 10 (cel mai slab e 62.7s), deci n-a stricat nimic. Verificat, nu presupus.

---

## Session log — 2026-07-27 (sunet nou: Mage Staff + cutremur)

**Cerut de Răzvan:** „Ti-am bagat mage staff audio pt proiectilele de la mage staff. Si ti am bagat si earthquake (la earthquake vreau sa se auda mai tare)".

**Ce s-a făcut:** două intrări noi în `audio.gd` — `mage_shoot` (`audio/Mage Staff Audio.wav`) și `earthquake` (`audio/Earthquake.wav`). `_fire_bullets()` din `player.gd` alege sunetul după `weapon_type`, deci Mage Staff nu mai împrumută `Bullet.mp3`-ul pistolului. Cutremurul se aude în **toate cele cinci locuri unde se zguduie ecranul**: invocarea Gărzii (`statue.gd`), invocarea lui Saratalin (`summoning_portal.gd`), cinematica lui de la jumătate (`saratalin.gd` — acolo era `levelup` pus ca placeholder pentru bubuitură), **Panic Button** (`player.gd`, unde era `hurt` cu comentariul „placeholder") și portalul care se scufundă la ieșirea din Nether (`nether.gd`).

**🔑 Volumul cutremurului stă într-o singură constantă: `Audio.QUAKE_DB`.** Cinci locuri de chemare ⇒ dacă valoarea e scrisă de cinci ori, sigur rămâne una în urmă. `pitch_rand = 0`, ca toate cutremurele să sune identic.

**A doua rundă, tot 2026-07-27: „sa se auda earthquake de 2x mai tare" → 6.0 → 12.0.** Decibelii se ADUNĂ, nu se înmulțesc: „de 2 ori mai tare" = +20·log10(2) ≈ **+6 dB**. **Peste plafon, în cunoștință de cauză:** fișierul are vârful la −2.4 dBFS, deci la +12 vârful iese la **+1.6 dBFS cu slider-ul lui (0.4)** și +9.6 cu slider-ul la maxim — placa de sunet îl taie și bubuitura poate pârâi. I-am spus. Dacă se aude spart, se coboară RESTUL efectelor, nu ăsta: la urechi contează doar diferența dintre sunete.

**🔑 Măsoară fișierul înainte să-i dai un volum.** `tool_audio_info.gd` (unealtă nouă, rămâne în repo) citește WAV-ul **de pe disc**, nu resursa importată — Godot importă WAV-urile ca **QOA comprimat** (`format 3`), din care nu poți citi probele, așa că prima variantă a uneltei n-a putut măsura nimic. Parsează RIFF-ul de mână și scoate durata, vârful, rms-ul și profilul pe sferturi de secundă.

**🔑 Ambele fișiere aveau ~1s de LINIȘTE lipită la coadă** (2.5s de 96kHz/24 biți, cu sunet doar până pe la 1.5s). Contează: o boxă din pool rămâne ocupată cât ține stream-ul, inclusiv liniștea. Le-am importat cu **`edit/trim=true`** în `.import` (1.37s și 1.17s după) **și** am urcat `POOL_SIZE` de la **12 la 20** — cu attack speed mare, Mage Staff-ul singur ar fi ținut vreo 8 boxe și ar fi început să taie pașii și loviturile.

**Verificat pe o rundă REALĂ**, nu doar citind codul: test care pornește `main.tscn` cu `weapon_type = "mage"`, îl lasă 7 secunde și apoi se uită în `Audio._ultima` (dicționarul care ține minte ce s-a redat) — a ieșit `["enemy_hit", "game_start", "mage_shoot"]`, deci sunetul nou chiar cântă și `shoot`-ul de pistol NU mai apare. Cutremurul cerut direct a prins o boxă la volumul așteptat. Plus compilate toate cele 6 scripturi atinse.

---

## Session log — 2026-07-27 (Saratalin: contur mov de 1px pe fiecare cadru)

**Cerut de Răzvan:** „da-i lu saratalin in fiecare frame cate un stroke de 1px mov".

**Ce s-a făcut:** unealtă nouă, `tool_contur_foaie.gd` (+ `.tscn`), fratele lui `tool_contur.gd` — acela face proiectile (le rotește și le pune contur de 2px), asta conturează **foi de cadre**. Ia `Saratalin.png`, o taie mental în cele 15 cadre de 224×240 și scrie o foaie nouă, `Saratalin_contur.png`, cu contur mov plin de 1px lipit de desen (același `Color(0.72, 0.28, 1.0)` ca la ștreang). `SHEET` din `saratalin.gd` arată acum spre foaia conturată.

**🔑 Sursa NU se suprascrie.** Conturul e pixel opac, deci dacă unealta ar scrie peste `Saratalin.png`, a doua rulare ar contura conturul și marginea s-ar îngroșa la fiecare rulare. Scriind alt fișier, unealta e re-rulabilă oricând (util când Răzvan schimbă foaia).

**🔑 Conturul se face ÎN INTERIORUL ferestrei fiecărui cadru.** Cadrele sunt lipite unul de altul în foaie și se taie la rulare cu `AtlasTexture`; dacă vecinătatea s-ar căuta peste toată imaginea, desenul dintr-un cadru ar scoate mov pe marginea celui de lângă el și în joc ai vedea o dâră pe muchie. Unealta îți și spune dacă desenul atinge marginea cadrului (acolo conturul ar ieși tăiat) — la Saratalin nu atinge, are loc peste tot.

**Verificat pe poză**, feliind foaia exact cum o feliază jocul (`AtlasTexture`, `TEXTURE_FILTER_NEAREST`): 3 cadre din animație plus un decupaj mărit 4×, pe fundal întunecat ca în Nether. Conturul e continuu, de exact 1px, și nu intră în cadrul vecin. Scena de test a fost ștearsă după verificare.

**De actualizat la pachet:** nimic în codex (nu s-a atins `levelup.gd`).

---

## Session log — 2026-07-27 (meniul arată ca jocul: ramă ornată, titluri aurii, ierarhie)

**Cerut de Răzvan:** „Cum pot sa fac meniul sa arate mai aesthetic?" → i-am dat diagnosticul, a ales „toate cinci".

**Diagnosticul (partea utilă, nu sfaturi generice):** meniul avea **două limbaje vizuale care se băteau cap în cap** — lemn cald (logo + butoane) versus titluri **cyan neon cu glow magenta** și sloturi de armă bleumarin cu bordură cyan, rămășițe din tema cyberpunk de dinainte de logo. Chiar comentariul din `menu.gd` spunea asta: subtitlul „CYBER SURVIVOR" fusese scos fiindcă „textul cyan se bătea cu stilul de lemn" — dar titlurile de pagină rămăseseră. În plus, sub-paginile n-aveau niciun recipient (text plutind peste fundalul blurat), deși **rama ornată perfectă exista deja în proiect și nu era folosită în meniu**: `Upgrades/Menu UI/Menu.png`, cea din ecranul de level up.

**Ce s-a făcut (toate în `menu.gd`, fără artă nouă):** titluri aurii în loc de cyan+magenta · rama `Menu.png` pe toate sub-paginile · armele în chenarele de raritate (`Border Rare/Common.png`) · START mai mare și mai luminos decât restul · butoanele cresc la hover și se înfundă la apăsare. Plus titlul din `pause.gd`, tot pe auriu.

**🔑 PanelContainer + StyleBoxTexture, NU NinePatchRect.** În `levelup.gd` NinePatch-ul merge fiindcă panoul are mărime FIXĂ. Aici paginile au înălțimi diferite (LEADERBOARD crește cu scorurile, SETTINGS e cea mai înaltă), iar un `NinePatchRect` **nu se strânge pe copii**. `PanelContainer` face exact asta.

**🔑 Marginile nine-patch de 46 (cele din `levelup.gd`) sunt GREȘITE — măsurate, nu ghicite.** Am scanat `Menu.png` (400×328) după unde începe umplutura interioară: ornamentul ține **61px stânga, 60 dreapta, 50 sus, 48 jos**. Cu margine 46, vreo 15px de ornament cad în zona ÎNTINSĂ — pe panoul mare și fix din level up nu se vede, dar pe panourile mici care se strâng pe conținut colțurile ieșeau vizibil trase. Acum 62/52/50, cu padding-ul de conținut puțin peste.

**🔑 Titlul paginii se desenează DEASUPRA ramei, nu în ea.** Două motive: ornamentul de sus e mai gros decât marginea, deci titlul dinăuntru se lipea de el; și scoate ~66px din interior, de care pagina SETTINGS chiar avea nevoie ca să încapă în cei 648px ai ecranului de referință.

**🔑 Hover-ul animează `scale`, NICIODATĂ `position`.** Butoanele stau în `VBoxContainer`, iar containerul își rescrie copiii la fiecare layout — o poziție animată e ștearsă imediat. `scale` nu e atins de containere. Iar `pivot_offset` trebuie re-centrat la fiecare `resized`, altfel butonul crește spre dreapta-jos.

**Bugetul de înălțime — pagina SETTINGS dictează tot.** 648px ecran − titlu (62) − padding ramă (114) ≈ 456px pentru conținut, iar blocul de setări cerea ~474. Am subțiat rândurile de taste/comutatoare (40→32) și separația paginii (8→6). Blocul e comun cu meniul de pauză, unde e loc berechet, deci acolo nu s-a pierdut nimic. **Dacă mai adaugi un rând de setări, verifică pe poză că rama nu iese din ecran.**

**Verificat pe poze, iterativ** (trei runde): prima a arătat butonul BACK întins până în ornament (lipsea `SIZE_SHRINK_CENTER` — VBox-ul din ramă întinde copiii) și pagina SETTINGS ieșită din ecran; a doua, titlul suprapus peste ornament și colțurile trase; a treia e curată. Plus meniul de pauză, ca să văd că rândurile mai scurte nu strică nimic acolo.

**Curățenie:** un test de-al meu lăsase iar un scor în leaderboard (1:17, level 7, 82 kills) — șters. E a treia oară azi; orice test care lasă player-ul să moară scrie în `user://scores.save`.
---

## Session log — 2026-07-27 (Grasu: 3 direcții de alergare făcute prin oglindire)

**Cerut de Răzvan:** „la grasu vreau sa facem mirroring la niste animatii - ti-am sters running west, north-west, si south-west. Iei tu counterparts de la directiile astea, le faci mirroring".

**Perechea de sud s-a inversat pe parcurs — starea FINALĂ e `south_west ← south_east`.** Prima dată el ștersese `south-east.gif` (deși în mesaj zicea „south-west"), așa că am făcut `south_east` din `south_west`. I-am semnalat nepotrivirea, a zis „am gresit eu", a pus la loc GIF-ul original `south-east` și l-a șters pe `south-west`. Deci acum **toate trei oglindirile merg spre vest**: `west ← east`, `north_west ← north_east`, `south_west ← south_east` — aranjamentul mai curat, în care tot ce e desenat de mână se uită spre est.
**De reținut:** merită verificat ÎNTOTDEAUNA în folder ce lipsește de fapt, nu doar ce scrie în mesaj — a doua rundă a costat o retăiere de GIF și o reoglindire.

**Ce s-a făcut:** `tool_mirror_grasu.gd` (unealtă nouă, se rulează ca scenă) încarcă cadrele-sursă cu `Image.load_from_file`, le dă `flip_x()` și le salvează peste cele 12 nume existente (3 direcții × 4 cadre). Numele și `.import`-urile păstrate ⇒ UID-urile rămân valabile ⇒ **`player_frames.tres` și `player.gd` n-au fost atinse**.

**🔑 Capcana reală — oglindirea se face față de PERSONAJ, nu față de pânză.** `flip_x()` întoarce toată imaginea de 124×124, deci dacă arta nu e fix în mijloc, personajul ajunge în altă parte a pânzei — iar în joc **sare lateral** exact când te întorci. Unealta măsoară conturul opac înainte și după și mută rezultatul înapoi pe coloanele originalului (corecții de 1–6 px aici).

**Verificat pe rulare reală** (nu doar în fișiere): apăsat fiecare din cele 8 direcții în joc și tipărit ce animație pornește + unde cade centrul artei față de nod:
```
east/west              -2.0 / -2.0 px
north_east/north_west  -2.5 / -2.5 px
south_east/south_west   0.0 /  0.0 px
```
Identice în fiecare pereche, deci întoarcerea nu mișcă sprite-ul. Plus randate toate cele 8 direcții × 4 cadre și o poză din joc.

**De reținut:** cele 3 direcții sunt acum **derivate**. Dacă se redesenează `east` / `north_east` / `south_west`, trebuie rulată din nou unealta, altfel cele două jumătăți o iau în direcții diferite.
---

## Session log — 2026-07-27 (inamicul e acum polițist)

**Cerut de Răzvan:** „ti-am pus sprite-uri noi in homeless directii, le schimbi tu si le faci si frame uri".

**Ce s-a făcut:** cele 8 GIF-uri noi (`A_faceless_police_officer_in_walk_<dir>.gif`, 124×124, 6 cadre fiecare) tăiate cu PowerShell + `System.Drawing` (`FrameDimension.Time` + `SelectActiveFrame`) **peste aceleași 48 de nume** din `homeless directii/frames/` — `walk_<dir>_<0..5>.png`.

**🔑 De ce n-a trebuit atins nimic altceva:** păstrând numele **și fișierele `.import`**, UID-urile rămân valabile, deci `enemy_frames.tres` (care le referă cu `uid://`) merge mai departe neschimbat. La fel `enemy.gd`, `enemy.tscn` și hitbox-ul. Sesiunea din 2026-07-18 a trebuit să regenereze `.tres`-ul tocmai fiindcă atunci s-au schimbat și numele.

**Hitbox-ul — măsurat, nu presupus:** conturul opac al polițistului e **27–39 × 61–63 px** (adunat pe toate cadrele), față de 31×59 la personajul vechi. Practic identic, deci `CircleShape2D` (rază 10 × scale 1.5) rămâne bun. Canvasul a crescut de la 120×120 la 124×124, dar asta singură nu înseamnă nimic — contează conturul opac, nu pânza.

**Numele de fișiere sunt „greșite" intenționat:** folderul se cheamă în continuare `homeless directii` și cadrele `walk_*`, deși nu mai e niciun homeless în joc. Redenumirea ar rupe căile și UID-urile din `enemy_frames.tres`, fără să câștigăm nimic.

**Verificat pe rulare reală:** randate toate 8 direcțiile × 6 cadre (orientări corecte: east→dreapta, west→stânga, north→din spate, south→din față, diagonalele la fel), fundal transparent, fără urme de la GIF. Apoi poză din joc, cu 8 inamici în cerc în jurul playerului.

**Capcană (m-a prins de două ori azi):** un test care lasă playerul să moară **scrie un scor real în leaderboard** (`show_gameover` → `add_score` → `user://scores.save`). Am șters de fiecare dată scorurile false după verificare. Fie ții inamicii departe, fie cureți după tine.
---

## Session log — 2026-07-27 (jocul în 9 limbi + UPGRADES scos din meniu)

**Cerut de Răzvan:** „sterge sectiunea de upgrades din main menu. Vreau langa butonul de setari sa ai si change language (tot un buton mic cu un steag)" — English, Chinese, German, Spanish, Russian, French, Japanese, Polish, Turkish, cu tot textul din joc tradus. „unele cuvinte sunt mai ciudate poti sa le lasi asa (eg. Duridama nu inseamna nimic)".

**Ce s-a făcut:**
- **`i18n.gd`** (autoload nou `I18n`) — un singur dicționar `TRAD` cu **183 de chei × 8 limbi**: meniu, settings, pauză, game over, HUD, anunțurile de pe ecran, cele 47 de nume + descrieri de upgrade-uri, raritățile și panoul de statusuri. La pornire construiește câte un `Translation` per limbă și îl dă lui `TranslationServer`.
- **`menu.gd`** — secțiunea UPGRADES ștearsă (butonul + `_build_shop` / `_on_shop` / `_on_buy` / `_refresh_shop`), iar în locul ei un panou **LANGUAGE** cu 9 steaguri. Butonul-steag stă lângă rotiță; helperul nou `_corner_button(cb, pozitie)` ține offset-urile colțului într-un singur loc.
- **`menu/flags/*.png`** — steaguri pixel-art 24×16 **desenate din cod** cu `tool_flags.gd`, ca să nu depindem de imagini de pe net (licențe) și ca să se poată regenera oricând la altă mărime.
- `game_settings.gd` — `language` + `set_language()`, salvat/încărcat ca restul setărilor.

**🔑 Descoperirea care a făcut difful mic: Godot traduce SINGUR textul pus pe Label/Button.** Nu trebuie `tr()` peste tot — lași `b.text = "START"` și iese tradus, iar la schimbarea limbii nodurile primesc `NOTIFICATION_TRANSLATION_CHANGED` și se rescriu singure. De aia `levelup.gd`, `pause.gd`, `settings_ui.gd` și `player.gd` **n-au fost atinse deloc**, deși tot textul lor apare tradus.
**⚠️ Reversul, care e o capcană reală:** un `tr()` pus pe o etichetă simplă ar STRICA schimbarea limbii — nodul ar reține textul deja tradus, iar a doua căutare n-ar mai găsi nimic, deci ar rămâne în limba veche. `tr()` se folosește **doar** unde textul are `%d`/`%s` (`hud.gd`, `gameover.gd`, `interact_ui.gd`, rândul de leaderboard din `menu.gd`) — acolo cheia oricum n-ar mai fi găsită după ce se pun numerele în ea.

**Fontul — verificat ÎNAINTE de a scrie traducerile,** fiindcă putea să pice tot: `HomeVideo-Regular.otf` are latina completă (inclusiv ą/ę/ł/ż și ğ/ş/ı) **și chirilica**, dar zero glife CJK. Chineza și japoneza ies din **system fallback** (`allow_system_fallback=true` în `.import`) — se văd corect, doar cu alt font (nu pixel). Verificat cu `font.has_char()` + poză, nu presupus.

**Verificat pe rulare reală:** `tool_check_i18n.tscn` (unealtă nouă) confirmă 183 chei × 8 limbi complete, zero nume/descrieri din `levelup.gd` fără traducere, zero `tr(...)` fără rând în tabel; singurele texte netraduse rămase în cod sunt „Nicotine & Knives" (titlul de rezervă) și „+" (prefixul cronometrului). Plus poze din joc: meniu (en/de/ru), panoul de limbi, settings (zh/pl), level up + panoul de statusuri (ru/zh), HUD (pl), pauză și game over (de). Panoul de statusuri are lățime FIXĂ — de-aia etichetele lungi sunt scurtate în tabel („Erlitt. Schaden", „Otrzym. obraż.") și s-a verificat pe poză că încap.

**De reținut pentru unelte:** o unealtă care are nevoie de autoload-uri **nu merge cu `--script`** („Identifier not found: GameSettings") — se rulează ca **scenă**: `godot --headless --path . res://tool_check_i18n.tscn`.

**Curățenie:** testul de game over chiar scrie în leaderboard-ul real (`show_gameover` cheamă `add_score`) — scorul fals (10:23, level 12) a fost șters din `user://scores.save` după verificare. Dacă mai rulezi așa un test, curăță după el.

**Ce NU s-a atins:** meta-progresia din spatele magazinului (`META`, `buy()`, monedele, upgrade-urile deja cumpărate) e neatinsă — a dispărut doar ecranul; ce era cumpărat se aplică în continuare. Și **codexul rămâne în urmă**: încă descrie „magazinul permanent" ca pagină de meniu. L-am lăsat intenționat (datele sunt reale, doar inaccesibile), dar e de decis cu Răzvan ce facem cu secțiunea aia.
---

## Session log — 2026-07-26 (28 de descrieri rescrise + Psychic Flip Flop)

**Cerut de Răzvan:** o listă cu descrieri noi pentru 28 de iteme, plus redenumirea „Psychic Flip Flops" → **„Psychic Flip Flop"**.

**Ce s-a făcut:**
- `levelup.gd` — cele 28 de câmpuri `desc` rescrise + `nume` schimbat la `psychic_flip_flops`. Aplicate **cu script**, dintr-o listă `id|text`, nu editate una câte una.
- `codex.html` — câmpul `game:` regenerat pentru **toate** cele 47 de iteme din `levelup.gd` (nu doar cele 28), plus `name:` sincronizat. Artifact republicat.
- Comentariile din `bullet.gd` și `player.gd` care numeau itemul, plus intrarea din README, actualizate la numele nou. Log-urile vechi din CLAUDE.md rămân cu numele vechi — sunt istorie.

**Verificat pe rulare reală, nu în fișier:** rulat jocul și tipărită lista pe care o vede chiar meniul de level up (`menu.UPGRADES`) — toate 28 apar cu textul nou, iar itemul se numește „Psychic Flip Flop". Apoi comparat `codex.html` cu `levelup.gd`: **47 identice, 0 diferite**. Codexul randat în Chrome headless: 0 erori de consolă.

**Detaliu de acces:** `UPGRADES` e `var`, nu `const` — deci se citește direct (`menu.UPGRADES`). Pe `const` ar fi trebuit `get_script().get_script_constant_map()`. Am pierdut două rulări încercând întâi `ITEMS` (nume greșit) și apoi harta de constante.

**Verificare de conținut, nu doar de sincronizare:** noile texte pun cifre acolo unde înainte era vag („+damage - +fire rate" → „+10 Damage +18% Attack Speed" la Stroh). Am confirmat în `_apply` că Stroh chiar dă `bullet_damage += 10`, deci cifra de pe card e reală.

**De observat:** multe descrieri noi renunță la partea cu stivuirea („1% instakill (+0.5% / stack)" → „1% instakill"). Nu e o scăpare, e alegerea lui — cardul din joc e scurt. Informația despre stack n-a dispărut: e în rândul **CE FACE DE FAPT** din codex.
---

## Session log — 2026-07-26 (codexul arată textul EXACT din joc + pagina era spartă)

**Cerut de Răzvan:** „la artifact fa descrierile exact cum sunt scrise in joc sa stiu cum le schimb".

**🔴 Descoperire importantă: codexul publicat era o PAGINĂ ALBĂ, și eu îl publicasem așa mai devreme în aceeași zi.**
Linia 229 din `codex.html` avea `+ „Blocked".` — ghilimea de deschidere e cea românească (`„`), dar cea de închidere era **`"` normal**, care termină string-ul JS pe loc. Restul rândului devenea cod invalid: `Uncaught SyntaxError: Unexpected token '<'`. Tot randarea e în JS, deci **nu se afișa absolut nimic** — doar fundalul. Greșeala venea dintr-o sesiune anterioară (editarea Mike's Hedgehog), iar eu am republicat fișierul fără să-l fi randat vreodată. Reparat: `„Blocked”.`
**➡️ REGULĂ NOUĂ: `codex.html` NU se publică fără să fie randat întâi.** Chrome headless merge și dă erorile de consolă:
```
"C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --no-sandbox --disable-gpu \
  --enable-logging=stderr --log-level=0 --hide-scrollbars --window-size=1280,3000 \
  --virtual-time-budget=8000 --screenshot=OUT.png "file:///C:/.../codex.html"
```
Pagina goală = ~154 KB PNG; randată = ~900 KB. Zero linii `CONSOLE` = JS curat. (`--dump-dom` NU merge — dă DOM-ul dinainte de JS.)

**Ce s-a făcut pentru cerere:**
- Câmp nou **`game:`** la fiecare din cele 47 de iteme = `desc`-ul din `levelup.gd`, **generat cu script**, nu copiat de mână.
- Cardul are acum două rânduri etichetate: **ÎN JOC** (mono, chenar cyan punctat = textul de pe cardul de level up, literă cu literă) și **CE FACE DE FAPT** (efectul real din cod). Plus `id`-ul, care era deja acolo — cu el găsești linia în `levelup.gd`.
- Lede-ul explică unde se schimbă textul (`levelup.gd`, câmpul `desc`).

**Verificat:** script care despachetează entitățile HTML din `game:` și compară cu `desc` din `levelup.gd` → **47 identice, 0 diferite**. Plus randare în Chrome: 0 erori de consolă, carduri vizibile.

**De reținut:** cele 3 descrieri cu `&` (Wine, Jean's Bomb, Death Sentence) sunt scrise `&amp;` în `codex.html`, fiindcă `el()` folosește `innerHTML`. În pagină se văd corect ca `&`. Dacă regenerezi câmpul `game:`, păstrează escapările.
---

## Session log — 2026-07-26 (fundalul meniului, la rezoluție întreagă)

**Cerut de Răzvan:** „Background-ul de la meniu arata prost, nu e hd, rezolva".

**Cauza:** cadrele erau **640×360**, întinse pe tot ecranul. Ideea inițială (log-ul din 2026-07-19) era că se văd doar blurate, deci rezoluția n-ar conta — dar între timp animația a fost pornită din **primul cadru**, iar `INTRO_CLEAR = 1.0` ține imaginea **CLARĂ** o secundă întreagă. Deci în exact secunda în care te uiți la ea, era o poză mărită de 3 ori. Cadrul clar de 720p (`bg_still.webp`) rămăsese doar rezervă, nefolosit.

**Ce s-a făcut:** cadrele re-extrase din `menu/main menu background.mp4` la **1920×1080** (rezoluția sursei), aceleași 6 secunde de la t=0, același 10 fps, aceleași 60 de cadre — verificat cu PSNR că vechiul `frame_001` corespunde cu t=0 din video, deci segmentul e identic și animația arată la fel. `bg_still.webp` la fel, 1080p.

**Cheia e MODUL DE IMPORT, nu rezoluția.** La `compress/mode=0` (lossless, cum erau), 60 de cadre 1080p = **486 MB memorie video — măsurat, nu estimat**. De asta refuzase sesiunea veche 720p. Trecute pe **`compress/mode=2` (VRAM Compressed)**, aceleași cadre costă ~62 MB. Memoria totală de texturi: **62.5 MB → 77.5 MB**, pentru **de 9 ori mai mulți pixeli**.
**⚠️ Dacă regenerezi cadrele, verifică să rămână pe `compress/mode=2`** — Godot rescrie `.import`-urile și, pe lossless, meniul încearcă să aloce o jumătate de gigabyte.

**Capcană de măsurare — PSNR minte aici.** Cadrul nou (1080p comprimat VRAM) iese **mai prost** la PSNR față de original decât cel vechi mărit: **30.2 vs 32.3 dB**. Explicația: PSNR premiază neclaritatea (o poză blurată „greșește" puțin peste tot) și pedepsește artefactele de bloc pe contururi dure — exact ce are arta asta plată, cu culori mari și margini tăiate. **Am tăiat un crop și m-am uitat:** varianta nouă are brazii și norii cu contur clar, unde înainte era pastă. Deci s-a mers pe ochi, nu pe cifră. (De reținut pentru orice comparație viitoare de imagini.)

**Verificat:** captură în secunda clară (contur curat, fără scări) + captură la 5 s, cu blur, titlu și butoane — meniul e neschimbat în rest. Scenele de test au fost șterse după.

**Pe disc:** cadrele trec de la 1.3 MB la 5.1 MB. `main menu background.mp4` rămâne gitignorat (79 MB, doar pe discul lui Răzvan) — regenerarea cere `ffmpeg`:
```
ffmpeg -ss 0 -t 6 -i "menu/main menu background.mp4" \
  -vf "fps=10,scale=1920:1080:flags=lanczos" -c:v libwebp -quality 92 \
  menu/bg_frames/frame_%03d.webp
```
---

## Session log — 2026-07-26 (Enemy Hit, încă de 1.5× mai încet)

**Cerut de Răzvan:** „fa-l cu 1.5x mai incet" (despre sunetul de la sesiunea de mai jos).

**Ce s-a făcut:** `bullet.gd` — `Audio.play("enemy_hit", -8.0)` → `-11.5`. Din nou: decibelii se SCAD, nu se împart. −20·log10(1.5) = 3.5 dB, deci −8 − 3.5 = −11.5.

**Unde ajunge în mix:** fișierul are RMS −20.0 dBFS, deci acum iese la **~−31.5 dBFS efectiv** — între stingător (−25) și pași (−37). Vârful fișierului e 1.0, deci atenuarea e sigură (nu poate face clipping).

**N-am refăcut testul de rulare.** Cablajul (fișier importat, cheie în `SFX`, apel la impact, 10 porniri în 5s) a fost verificat la sesiunea precedentă și nu s-a schimbat; aici s-a mutat doar o constantă. Dacă ajunge prea încet, e o singură cifră de urcat.
---

## Session log — 2026-07-26 (sunet când un proiectil rănește un inamic)

**Cerut de Răzvan:** „ti-am adaugat un sunet se numeste - Enemy Hit - vreau de fiecare data cand un inamic e ranit de un proiectil sa se auda usor sunetul ala".

**Ce s-a făcut:**
- `audio.gd` — `"enemy_hit": "res://audio/Enemy Hit.wav"`.
- `bullet.gd::_on_body_entered()` — `Audio.play("enemy_hit", -8.0)` imediat după `take_damage`. Pus în glonț, nu în `enemy.gd::take_damage`, din două motive: (1) cererea zice **„de un proiectil"**, iar `take_damage` e chemat și de sabie, stingător, Thunder God și explozii; (2) așa prinde și **boss-ii**, care au `take_damage` propriu și n-ar fi sunat niciodată dacă hook-ul stătea în `enemy.gd`.
- Fișierul a fost importat (`--import`) înainte de test.

**De ce −8 și nu altceva (nu din ureche):** măsurat RMS-ul fișierului cu un script GDScript peste PCM-ul brut → **−20.0 dBFS**, vârf 1.0 (deci „hot": se poate doar atenua, nu mări). La −8 iese **~−28 dBFS efectiv**, care se așază exact unde trebuie în mixul măsurat pe 2026-07-2x: sub stingător (−25, celălalt sunet care pulsează încontinuu) și mult peste pași (−37).

**Limită de recunoscut:** nu se poate compara direct cu sunetul de tras. `Bullet.mp3` e comprimat, deci RMS-ul lui n-a fost măsurabil niciodată — cei −12.5 dB ai lui sunt o estimare din ureche (vezi log-ul din 2026-07-25). Am ancorat sunetul nou în WAV-urile măsurate, nu în el.

**Prima variantă a fost prea încet.** Am pornit de la −14 (≈ −34 efectiv), adică sub pași — practic inaudibil sub gloanțe. Măsurătoarea RMS a arătat asta; de aia se măsoară, nu se ghicește.

**Verificat pe rulare reală**, cu trei inamici cu 100 000 HP lângă player (ca să fie RĂNIȚI, nu uciși):
```
TEST: porniri Enemy Hit in 5s = 10
TEST: enemy_hit=-15.96 dB | shoot=-20.46 dB
```
(cifrele includ slider-ul „Efecte"; ele sunt volume SETATE, nu loudness — comparația reală e cea pe RMS de mai sus). Scena de test a fost ștearsă după.
---

## Session log — 2026-07-26 (sunetul glonțului, de 1.5× mai încet)

**Cerut de Răzvan:** „Fa cu 1.5x audiou de la gloante mai incet".

**Ce s-a făcut:** `player.gd::_fire_bullets()` — `Audio.play("shoot", -9.0)` → `Audio.play("shoot", -12.5)`. Un singur loc în tot jocul cheamă sunetul de glonț (verificat prin căutare după `play("shoot"`).

**Atenție la matematică — decibelii NU se împart.** „De 1.5 ori mai încet" nu înseamnă `-9 / 1.5 = -6` (ăla ar fi mai TARE). Decibelul e logaritmic: „de N ori mai încet" = **scazi** `20·log10(N)` dB. Pentru N = 1.5 asta face 3.52 dB, deci −9 − 3.5 = **−12.5 dB**. Scris și în comentariu la linia respectivă, ca să nu fie „împărțit" data viitoare.

**Verificat pe rulare reală**, măsurând amplitudinea liniară a boxei, nu numărul din cod:
```
TEST glonț: volume_db=-20.46 | amplitudine=0.0949 | inainte=0.1419 | raport vechi/nou=1.496
```
(`-20.46` include și reglajul „Efecte" din Settings; raportul 1.496 ≈ 1.5 e ce contează.) Scena de test a fost ștearsă după.
---

## Session log — 2026-07-26 (boss-ii nu mai pot fi omorâți instant)

**Cerut de Răzvan:** „Vreau sa nu poti sa dai instakill la bosses (saratalin si garda)."

**Ce s-a făcut:**
- Grup nou **`"boss"`**, la care se înscriu în `_ready()` atât `garda.gd` cât și `saratalin.gd`. Un singur loc de adevăr; un boss viitor devine imun doar adăugându-se în grup.
- `bullet.gd::_on_body_entered()` și `player.gd::_sword_damage_pass()` — condiția de instakill are acum `and not <ținta>.is_in_group("boss")`. Erau EXACT două locuri care fac instakill (ambele calculau `dealt = int(hp)`); nu există altele — verificat prin căutare după `999999` și după `.hp) if`.
- `codex.html`: `warn: "Nu merge pe boss (Garda / Saratalin)"` la ambele Hacksaw-uri, plus „· nu pe boss" la Duridama. **Artifactul a fost republicat.**

**Duridama era deja imună, structural.** Aurirea trăiește în `enemy.gd` (`_try_golden` + ramura `if golden` din `take_damage`), iar boss-ii au `take_damage` propriu, care n-o cheamă niciodată. N-a trebuit atins nimic — dar merită scris, ca să nu pară o scăpare la o citire viitoare.

**Textul de pe cartonașul din joc a rămas neschimbat** („1% instakill (+0.5% / stack)"). N-a cerut asta și pe cartonaș nu prea e loc; dacă vrea, se adaugă în `levelup.gd`.

**Verificat** cu instakill setat la 100%, pe ambele căi de atac:
```
=== CALEA GLONȚULUI ===
  Garda: în grupul boss=true | hp 305 -> 295 | mort=false -> OK
  Saratalin: în grupul boss=true | hp 10000 -> 9990 | mort=false -> OK
  inamic normal: în grupul boss=false | hp 30 -> 0 | mort=true -> OK
=== CALEA SĂBIEI ===
  Garda: atins de sabie=true | hp 306 -> 296 | mort=false -> OK
  Saratalin: atins de sabie=true | hp 10000 -> 9990 | mort=false -> OK
```
Al treilea rând e important: **inamicul normal moare în continuare din prima**, deci Hacksaw n-a fost stricat, doar limitat. Scena de test a fost ștearsă după.

**⚠️ Codexul publicat rămăsese în urmă cu mai multe sesiuni.** `codex.html` din repo era mai nou decât artifactul (Undying Spirit la 6s + „Blocked" + Unic, Angel Wings +10 nu +15, șansele 40/35/15/7.5/2.5 nu 30/30/20/15/5, nota despre proiectile pe Sabie & Stingător). Cineva a editat fișierul și n-a mai republicat. **Publicarea cere întâi `WebFetch` pe URL-ul artifactului** (altfel tool-ul refuză cu „hasn't viewed the latest version"), apoi `Artifact url=…`. Înainte de publicare am comparat live-ul cu repo-ul și am verificat în `levelup.gd` că șansele din repo sunt cele reale (`"common": 40.0`) — deci nu s-a pierdut nimic din ce era publicat.
---

## Session log — 2026-07-26 (meniul pornește muzica fără fade-in)

**Cerut de Răzvan:** „muzica de la meniu sa fie fara fade in".

**Ce s-a făcut:** `_play_track()` a primit un parametru nou, `fade_in: float = FADE`. `play_menu_music()` îi dă `0.0` → boxa pornește direct la volumul ei, fără tween. Restul (joc, Nether, revenire din Nether) rămâne pe `FADE = 3.0`, nemodificat.

**Ce NU s-a atins:** stingerea. Fade-out-ul de 3 s al meniului rămâne, deci când pleci în rundă cele două melodii tot se încrucișează. Cererea era doar despre intrare.

**Verificat** cu o scenă de test peste `menu.tscn`, citind `Audio._music.volume_db` față de `_volum_muzica()`:
```
MENIU: [   2 ms] -20.94 dB (țintă -20.94)   ← deja la volum din primul cadru
MENIU: [1335 ms] -20.94 dB (țintă -20.94)
--- Audio.play_music() ---
JOC:   [  48 ms] -59.21 dB (țintă -18.94)   ← fade-ul de rundă a rămas intact
JOC:   [1541 ms] -38.84 dB (țintă -18.94)
```
Scena de test a fost ștearsă după.
---

## Session log — 2026-07-26 (sunet pe fiecare puls mov al lui Saratalin)

**Cerut de Răzvan:** „vreau atunci cand e flashing purple saratalin sa fie un audio fx - e in nether audio se numeste Saratalin Flashing Purple. Vreau sa se auda de fiecare data separat cand e un singur flash."

**Ce s-a făcut:**
- `audio.gd` — o linie nouă în `SFX`: `"saratalin_flash": "res://audio/Nether Audio/Saratalin Flashing Purple.wav"`.
- `saratalin.gd`, `_cinematica_faza2()` — `Audio.play("saratalin_flash", -4.0, 0.0)` **la fiecare aprindere**: în bucla celor două pulsuri (deci de două ori, la momentul fiecărui puls) și încă o dată când se aprinde movul ținut peste cutremur. **Trei redări separate**, nu un sunet lung întins peste tot filmulețul — asta a cerut („de fiecare data separat cand e un singur flash").
- `pitch_rand = 0.0` intenționat. Implicit `Audio.play()` variază tonul cu ±8% ca gloanțele să nu sune identic; aici pulsurile TREBUIE să sune la fel, altfel al doilea pare alt sunet.

**De ce merge suprapunerea:** `Audio.play()` ia o boxă liberă din `POOL_SIZE = 12` la fiecare apel, deci redările nu se taie una pe alta. Singurul lucru care le-ar fi putut înghiți e `MIN_GAP_MS = 45` (același sunet nu repornește mai des de atât) — dar între pulsuri sunt ~420 ms, deci nici pe departe. **Se aud prin îngheț** fiindcă `Audio` e autoload `PROCESS_MODE_ALWAYS`, la fel ca fade-urile.

**Fișierul avea nevoie de import.** Răzvan pune `.wav`-ul în folder, dar fără `.wav.import` Godot nu-l vede și `ResourceLoader.exists()` întoarce `false` — `play()` iese în tăcere, fără nicio eroare roșie. Rulat `Godot --headless --path <proj> --import` înainte de test. **Dacă un sunet nou „nu se aude", ăsta e primul lucru de verificat.**

**Cum s-a verificat (măsurat, nu presupus):** scenă de test cu observatorul **frate** cu `Main` (vezi capcana din log-ul de mai jos), care se uită direct în `Audio._players` și strigă când o boxă începe să redea exact fișierul de flash. Rezultat:
```
TEST: [ 548 ms] flash SFX pornit pe boxa 86067119792 | pitch=1.0 | pauzat=false | tree.paused=true
TEST: [ 967 ms] flash SFX pornit pe boxa 86100674226 | pitch=1.0 | pauzat=false | tree.paused=true
TEST: [1390 ms] flash SFX pornit pe boxa 86134228660 | pitch=1.0 | pauzat=false | tree.paused=true
TEST: total porniri sunet flash = 3
```
548 ms = după intrarea camerei (`cin_intrare = 0.55`), apoi la fix `cin_puls = 0.42` distanță unul de altul — **boxe diferite**, deci chiar sunt redări separate, nu una repornită. Scena de test a fost ștearsă după.

**Capcană repetată (a doua oară în aceeași zi):** `var cheie := p.get_instance_id()` → *„Cannot infer the type of «cheie»"*, scriptul de test n-a mai încărcat deloc. În scripturile astea, când valoarea vine dintr-un obiect netipat, **scrie tipul explicit** (`var cheie: int = ...`).
---

## Session log — 2026-07-26 (cinematica: îngheț total, movul pe boss, salvă de 5)

**Cerut de Răzvan:** player-ul să nu mai tragă în timpul cutscene-ului și TOTUL să fie înghețat; movul să pulseze pe Saratalin, nu pe ecran; iar după cinematică să mai aibă un atac — 5 proiectile țintite, unul după altul, rapid (ca rafala Gărzii, doar că de 5).

**⚠️ Capcană de TESTARE care m-a costat două rulări — de citit înainte să testezi ceva cu `paused`:**
1. **Scena de test nu are voie să fie PĂRINTELE lui `main.tscn` dacă are `process_mode = 3`.** Modul se moștenește în jos, deci punând observatorul deasupra jocului făceam TOT jocul „rulează mereu" — pauza nu îngheța nimic și măsurătorile ieșeau fals. Corect: rădăcină simplă (pauzabilă), cu `Main` și observatorul ca FRAȚI, doar observatorul cu ALWAYS.
2. **Pe pauză, cadrele curg mult mai repede** (fără fizică, fără procesare: ~210fps în loc de 60). 45 de cadre înseamnă ~0.2s reale, nu 0.75. Măsurătorile din timpul unei cinematici se fac pe `Time.get_ticks_msec()`, nu pe număr de cadre — altfel pare că tween-urile nu rulează, când de fapt abia au început.

**Ce s-a dovedit despre reclamația „player-ul trage în cutscene":** în arborele corect, pauza ÎL oprea deja (`can_process=false`, cronometrul de tras nu mișcă). Ce se mișca peste filmuleț era **`Fx`** — autoload cu `PROCESS_MODE_ALWAYS`, deci numerele de damage și scânteile curgeau mai departe. Cinematica îl trece acum pe `PAUSABLE` pe durata ei. În plus **oprim explicit `player.fire_timer`**: cinematica pornește dintr-o lovitură, adică din mijlocul fizicii, iar un ultim glonț putea ieși chiar în cadrul ăla.

**Bug real găsit tot aici:** `_flash()` (sclipirea albă de la fiecare lovitură) animează ACEEAȘI proprietate ca pulsurile mov — `anim.modulate`. Fiindcă lovitura care declanșează cinematica pornește și flash-ul, movul era tras înapoi spre alb și nu se vedea. Cinematica omoară `_flash_tween` și pornește de la culoare curată.

**Movul a ieșit de pe ecran:** `flash_mov()` și `ColorRect`-ul mov din `boss_bar.gd` au fost șterse. Acum boss-ul se aprinde mov și RĂMÂNE aprins cât ține cutremurul, apoi revine la alb.

**Salva de 5** (`salva_shots`/`salva_gap`/`salva_interval`), doar în faza 2, derulată cu contor din `_physics_process` (nu cu `await`, ca la Gardă: dacă moare la mijloc, contorul dispare odată cu nodul). Ținta se recitește la fiecare proiectil → salva te urmărește dacă fugi.

**Verificat prin rulare, măsurat pe timp real:** îngheț total (player `can_process=false`, `fire_timer` oprit, `Fx` pe PAUSABLE) ✅; zoom 0.7 → 1.19 ✅; modulate-ul boss-ului urcă la (3.20, 0.80, 4.00) în cutremur, cu fundalul ecranului neatins — verificat pe captură ✅; după cinematică totul revine (zoom 0.7, modulate alb, `Fx` înapoi pe ALWAYS, `fire_timer` pornit) ✅; salva scoate **exact 5** proiectile ✅.

---

## Session log — 2026-07-26 (Saratalin: 10k viață, bară Dark Souls, cinematică la jumătate)

**Cerut de Răzvan:** 10.000 HP, bară de viață cu nume ca în Dark Souls, iar la jumătate (5k) un filmuleț: îngheață jocul, zoom pe Saratalin, glow mov de două ori, cutremur cu efect mov, apoi înapoi la normal și atacă de 3 ori mai repede.

**Viața e FIXĂ, fără `Difficulty.enemy_hp_mult()`.** Toți ceilalți inamici (inclusiv Garda) își înmulțesc viața cu dificultatea, dar aici pragul de fază trebuie să însemne același lucru de fiecare dată — altfel „jumătate" ar cădea aiurea față de build-ul tău. Damage-ul și viteza lui urmează în continuare ceasul rundei.

**`boss_bar.gd` (nou)** — CanvasLayer generic (`arata(nume, hp_max)` / `set_hp` / `ascunde`), deci merge și pentru alt boss. Două `ProgressBar`-uri suprapuse: dedesubt „urma" roz care coboară cu întârziere, deasupra viața reală. **Bara de deasupra are `StyleBoxEmpty` ca fundal** — cu fundalul normal, dreptunghiul ei opac acoperea exact urma pe care voiam s-o vedem (prima variantă arăta un gri mort în loc de roz). Bara se ascunde din `saratalin._exit_tree()`, ceea ce prinde și moartea, și ștergerea la ieșirea din Nether.

**Cinematica rulează cu jocul pe pauză.** Cheia: un tween e legat de nodul care l-a creat și stă dacă acel nod e pe pauză. Deci pe durata filmulețului boss-ul își pune `process_mode = ALWAYS` (și `_cinematic` ține `_physics_process` mut), la fel și `BossBar`. **Netezirea camerei se OPREȘTE pe durata cinematicii** — ea se face în procesarea internă a camerei, care nu rulează pe pauză; lăsată pornită, camera ar fi rămas blocată pe loc.

**Cutremurul din cinematică nu poate folosi `_zguduie_camera()`** (cel de la aterizare): ăla creează tween-ul pe cameră, care e copil al player-ului, deci pe pauză. Filmulețul își face al lui, pe boss. Tot de aia tween-ul de întoarcere readuce `offset`-ul la zero — curăță și reziduul de zguduire.

**`pause.gd._blocked()`** refuză ESC cât rulează filmulețul: altfel meniul de pauză și cinematica s-ar fi certat pe `get_tree().paused`.

**Verificat prin rulare, cu capturi la fiecare pas:** viață 10000 fixă ✅; bara cu numele deasupra, umplere 0.69 cu urma rămasă la 0.92 după o lovitură ✅; la 5000 → `paused=true`, zoom 0.7 → 1.19 (×1.7), offset mutat pe boss (0, −182) ✅; pulsul mov (modulate 1.79/0.93/2.09) ✅; spălarea mov peste tot ecranul + zguduire ✅; la final `paused=false`, zoom și offset EXACT înapoi la (0.7, 0.7) și (0, 0) ✅; atacul 1.8 → 0.6 și cercul 8.0 → 2.67 ✅; bara dispare la moarte ✅.

---

## Session log — 2026-07-26 (fade de 3s la muzică + liniște pe ecranul de moarte)

**Cerut de Răzvan:** „fade in și fade out de 3 secunde la toate melodiile" + „muzica și ambientul să nu se mai audă în death screen".

**Fade-ul e CROSSFADE, nu fade-out-apoi-fade-in.** Dacă stingeam melodia veche și abia apoi o porneam pe cea nouă, la intrarea în Nether ar fi ieșit 6 secunde de tranziție cu liniște la mijloc. Acum melodia care pleacă rămâne pe boxa ei (`_music_vechi`) și coboară în timp ce noua urcă pe o boxă proaspătă. `_play_track` creează de fiecare dată un `AudioStreamPlayer` nou; `_stinge()` o eliberează pe cea veche la capătul tween-ului (și o eliberează și dacă nu cânta, altfel se adunau boxe).

**„Zero"-ul fade-ului e -60dB, nu -80.** Sub ~-60 nu se mai aude nimic, deci prima secundă a unei urcări de la -80 ar fi fost tăcere moartă și fade-ul ar fi părut mai scurt decât e.

**`refresh_music_volume()` omoară fade-in-ul în curs** și sare la volumul cerut. Altfel, dacă miști slider-ul de Muzică în primele 3 secunde ale unei melodii, tween-ul ar trage volumul înapoi spre ținta veche și ar părea că slider-ul nu face nimic.

**Ambientul de pădure n-a primit tween**, ci un steag `_ambient_se_stinge`: `_process` deja mișcă `_ambient_level` spre o țintă în fiecare cadru, așa că îi spunem doar că ținta e tăcerea și, când ajunge sub 0.01, oprim boxa. Un tween peste el s-ar fi bătut cap în cap cu bucla aia.

**De ce merge pe ecranul de moarte, care pune tot arborele pe pauză:** autoload-ul `Audio` e `PROCESS_MODE_ALWAYS`, iar tween-urile create pe el moștenesc asta. Verificat explicit — `tree paused=true` și fade-ul a continuat.

**Verificat prin rulare:** fade-in la începutul rundei −53.6 → −42.8 → −29.2 → −18.9 dB (ținta) în 3s ✅; crossfade la intrarea în Nether — ambele cântă simultan, noua urcă (−56.8 → −35.9 → −18.9) în timp ce vechea coboară (−22.2 → −43.0) și e eliberată ✅; moarte în lumea normală — muzica −18.9 → −33.4 → −47.2 → oprită, ambientul 1.00 → 0.20 → 0.04 → oprit, ambele tăcute la 3.2s ✅.

---

## Session log — 2026-07-26 (proiectilul lui Saratalin: ștreangul, cu contur mov)

**Cerut de Răzvan:** „ți-am pus o poză în Nether Boss cu atacul lui Saratalin — se numește Saratalin Attack. Vreau să-i faci un stroke mov cum are Garda la armă."

**Poza e un ȘTREANG** (funie cu laț), care se leagă frumos de structura de invocare — și ea are un ștreang atârnat de arcadă.

**`tool_baton.gd` → `tool_contur.gd`:** unealta care făcea conturul mov al bastonei a fost generalizată cu o listă `LUCRARI` (sursă, folder, câte cadre), fiindcă acum are două de făcut. Aceeași rotire completă în 16 cadre × 22.5° și același contur de 2px (1px mov plin lipit de desen + 1px la jumătate de alfa — de aia arată a strălucire, nu a chenar). **Dovada că refactorizarea n-a stricat nimic:** după re-rulare, cadrele bastonei au ieșit identice bit cu bit (`git status` nu le-a marcat deloc).

**`lightning.gd`:** `FRAME_DIR`/`FRAME_COUNT` erau constante; au devenit `@export var frame_dir` / `frame_count`, cu bastona ca implicit. Scena `lightning.tscn` e acum comună: Garda o folosește cum era, Saratalin îi pune `frame_dir` pe folderul lui. **Se pune ÎNAINTE de `add_child`**, ca și `tint` — `_build_frames()` rulează în `_ready()`, adică fix când nodul intră în arbore (aceeași capcană ca la culoarea proiectilelor, acum două session log-uri mai jos).

**Colorizarea a scăzut** de la magenta agresiv (1.6, 0.5, 1.5) la (1.2, 1.0, 1.25): înainte proiectilul era o pată roz fiindcă trebuia să se distingă de bastonă. Acum are propria formă și propriul contur mov, deci tintul doar ridică luminozitatea ca să prindă glow-ul.

**Verificat prin rulare:** boss chemat și aterizat, cerc de 12 ștreanguri în aer, toate cu `frame_dir` pe folderul nou și 16 cadre încărcate, captură cu conturul mov vizibil ✅. **Notă de testare:** prima captură a ieșit goală fiindcă am tras-o la 1.6s după E — boss-ul are 1.0s de scufundare a structurii + 1.9s de coborâre. Trebuie ~3.4s.

---

## Session log — 2026-07-26 (Settings pe două pagini: KEYBINDS + GRAPHICS)

**Cerut de Răzvan:** „add a separate window in the settings tab that is named Graphics — the main one should be named keybinds."

**`settings_ui.gd`** are acum o bară cu două butoane sus și două pagini (`_pagini`, un dicționar nume → VBox; se vede una, restul ascunse). Tab-ul deschis stă aprins, ca să se vadă unde ești.
- **KEYBINDS** = exact ce era înainte (slidere de volum + remaparea tastelor), doar redenumit. N-am mutat sliderele de sunet într-o pagină separată: n-a cerut-o, iar o a treia pagină pentru două slidere ar fi fost în plus.
- **GRAPHICS** = `FULLSCREEN`, `V-SYNC`, `VIGNETTE`, `GLOW`, ca butoane ON/OFF (`_toggle_row`, care ține valoarea în `set_meta("valoare")` pe buton).

**Ce e în spate:** patru câmpuri noi în `game_settings.gd`, salvate în `scores.save` alături de restul, plus `aplica_grafica()` (fereastră + vsync) chemat la pornire și la fiecare schimbare. `vignette`/`glow` le desenează `atmosphere.gd`, care e doar în joc → `_refresh_atmosfera()` caută grupul „atmosphere" și, dacă nu-l găsește (adică ești în meniul principal), pur și simplu nu face nimic; setarea se aplică la începutul rundei. Pagina scrie asta sub butoane: „effects apply in-game".

**Fullscreen-ul NU pornește de la `false`:** în `_ready()` citim întâi modul real al ferestrei și abia apoi `_load()`. Altfel, la prima rulare fără fișier de salvare, am fi forțat fereastra în „windowed" chiar dacă proiectul pornește altfel.

**O regresie prinsă de captură, nu de cod:** bara de taburi a împins conținutul cu ~60px, iar butonul BACK ieșea sub marginea ecranului pe pagina KEYBINDS (2 slidere + 5 taste + titlu). Reparat strângând spațierea: separația paginilor 12→8, butoanele 44→40px, spacer-ul de după bara de taburi scos. Verificat în AMBELE locuri unde apare blocul — meniul principal ȘI meniul de pauză, care are alt fundal și altă înălțime de titlu.

**Verificat:** ambele pagini comută corect (vizibilitatea și tab-ul aprins); apăsarea comutatoarelor schimbă `GameSettings` ȘI starea reală — `window_get_vsync_mode()` a trecut pe 0 la V-SYNC OFF ✅; valorile puse înapoi la loc după test, ca să nu-i stric setările; capturi din meniul principal și din meniul de pauză, cu BACK întreg pe ecran ✅.

---

## Session log — 2026-07-26 (înapoi la hitbox „ca la statuie": butoanele au fost o greșeală)

**Reclamat de Răzvan, a doua oară:** „ba tot nu pot să schimb hitbox-ul la portal, poți să-i faci hitbox-ul ca la statuia lu' Garda?"

**Ce se întâmpla de fapt** — s-a văzut în `git status`, nu din ce ziceam eu: `portal.tscn` avea forma dusă la **320×100**. Adică Răzvan CHIAR reușise s-o schimbe, trăgând de pătrățelele lui `CollisionShape2D`. Doar că `_aplica_hitbox()` din scriptul `@tool` o suprascria la fiecare încărcare din exportările Nord/Sud/Est/Vest. Din perspectiva lui: „trag, salvez, se întoarce la loc" = „nu pot să schimb hitbox-ul". Scena mai avea și `sink_duration = null` / `sink_depth = null`, semn că editorul lui se încurcase de tot cu scriptul.

**Lecția, scrisă aici ca să nu se repete:** dacă o valoare e reglată CU MÂNA în editor, niciun script nu are voie să i-o scrie la încărcare. „Butoane comode" peste o valoare trasă cu mouse-ul înseamnă că mouse-ul pierde mereu, tăcut. Prima reclamație („nu văd butoanele") am pus-o pe seama cache-ului de editor — plauzibil, dar tratamentul corect era să întreb ce încearcă să facă, nu să lustruiesc butoanele.

**Ce s-a făcut:**
- `hitbox_reglabil.gd` **șters**;
- `portal.gd` și `summoning_portal.gd` sunt iar scripturi simple (`extends StaticBody2D`, fără `@tool`), care NU ating `CollisionShape2D`. Exact tiparul din `statue.gd`;
- `portal.tscn` păstrează **320×100** (valoarea lui) și a scăpat de liniile `= null`;
- pentru „vreau să văd hitbox-ul cât joc" există deja meniul Godot **Debug → Visible Collision Shapes**; nu ne trebuie cod.

**Verificat:** forma rămâne 320×100 după încărcare (înainte se întorcea la 250×60) ✅; lanțul complet încă merge — intrare în Nether pe un portal real, invocare, boss omorât, ieșire, portalurile se închid, 0 rămase ✅.

---

## Session log — 2026-07-26 (bug: la începutul rundei camera nu e pe player)

**Reclamat de Răzvan:** „când dau start la joc, ecranul nu e pe player din prima, e un bug dubios."

**Cauza:** camera player-ului are `position_smoothing_enabled = true` (în `player.tscn`), adică urmărește ținta lin, cu întârziere. `spawner._muta_player_aleator()` aruncă player-ul într-un punct aleator din lumea infinită (până la 100.000px pe fiecare axă), dar netezirea camerei pornea din `(0, 0)` — poziția din scenă, dinainte de mutare. Rezultatul: primele ~2 secunde din FIECARE rundă arătau lumea zburând pe lângă tine până prindea camera din urmă.

**Măsurat înainte de reparare:** decalaj **89.526px** în primul cadru, 8.118px la cadrul 6, 788px la cadrul 60, **încă 36px la cadrul 120** (două secunde).

**Reparat:** `cam.force_update_scroll()` + `cam.reset_smoothing()` imediat după teleportare, în `_muta_player_aleator()`. `force_update_scroll()` întâi, ca ținta să fie deja cea nouă când o „lipim". După reparare: **0px de la cadrul 2 încolo**.

**Atenție la o capcană de măsurare:** `get_screen_center_position()` citit din `_process`-ul unui nod aflat DEASUPRA camerei în arbore întoarce încă valoarea veche pentru cadrul curent — camera își face actualizarea internă mai târziu în cadru. Măsurat așa, părea că mai rămâne un cadru greșit și după reparare. Verificarea corectă e captura primului cadru desenat: player-ul e fix în mijloc. Deci: la bug-uri de cameră, capturile bat API-ul.

---

## Session log — 2026-07-26 (un singur Nether pe rundă: portalurile se închid după victorie)

**Cerut de Răzvan:** „când ai ieșit din Nether după ce l-ai bătut pe Saratalin să fie cutremur și să intre portalul în pământ — să nu mai poți să intri tot run-ul ăla. Dacă sunt mai multe pe hartă în momentul ăla, să fie șterse și alea."

**Cum e făcut** — `nether._inchide_portalurile()`, chemat doar de pe drumul VOLUNTAR de ieșire (care există numai după ce boss-ul a căzut):
1. așteaptă **două cadre** — `_set_world_enabled(true)` tocmai a repornit generatorul, iar portalurile se nasc la următorul `_process`; fără așteptare n-ar avea ce scufunda;
2. ia portalul cel mai apropiat de player (ăla prin care tocmai ai ieșit — stăteai lângă el când ai apăsat E) și îl **`reparent()`-ează în `World`**;
3. `portals.opreste()` → șterge toate chunk-urile încărcate și ridică steagul `oprit`, pe care `_process` îl verifică primul;
4. cutremur + `portal.intra_in_pamant()` (coboară + se stinge, ca statuia, apoi `queue_free`).

**De ce pasul 2 e obligatoriu:** portalurile stau în containere pe chunk, în interiorul generatorului. Dacă îl lăsam acolo, `opreste()` l-ar fi eliberat odată cu containerul lui și scufundarea nu s-ar fi văzut niciodată — ar fi dispărut instant, ca ceilalți.

**Filtrul din grupul „interactable":** statuile sunt în același grup, deci căutarea merge pe `has_method("intra_in_pamant")`, nu pe grup. Altfel ar fi putut nimeri o statuie mai apropiată.

**Subtitlul de la întoarcere** s-a schimbat din „The world is where you left it" în **„The portals are closing"** — acum chiar asta se întâmplă pe ecran.

**Consecință acceptată, nu bug:** dacă îl bați pe Saratalin dar mori în Nether înainte să ieși, ieșirea e forțată (`anunt = false`), deci portalurile RĂMÂN deschise. N-ai ieșit pe picioarele tale, deci n-ai încasat închiderea. Dacă Răzvan vrea altfel, se mută verificarea pe `_boss_invins` singur.

**Verificat prin rulare** (cu `portal_chance` urcat la 100% în test, ca să existe portaluri reale generate): 43 portaluri pe hartă înainte → intrare pe unul real → boss chemat și omorât → ieșire pe portal → `oprit=true`, rămâne **1** (cel care se scufundă, cu părintele `World`, prins la jumătatea scufundării: y=30.6, alpha=0.66) ✅; după scufundare **0** ✅; după ~6000px de plimbare prin lume nouă tot **0**, cu 0 chunk-uri în generator ✅; captură cu portalul intrând în pământ sub textul „BACK / THE PORTALS ARE CLOSING" ✅.

---

## Session log — 2026-07-26 (Nether-ul devine o luptă cu boss: nu ieși până nu-l bați)

**Cerut de Răzvan:** „ca să poți să ieși din Nether trebuie să-l bați pe Saratalin, să scrii asta ca text pe ecran (înlocuit cu ce era înainte când intrai). Statuia de summon a lui Saratalin vreau să fie random într-un cerc cu apotemă de 1000px față de portalul de intrare și la minim 600px de el."

**Ce s-a schimbat:**
- Textul de la intrare: „Press E at the portal to go back" → **„Kill Saratalin to leave"**.
- `exit_nether()` refuză ieșirea cât `_boss_invins` e fals și anunță **„SARATALIN LIVES / The portal will not open until he falls"**. `saratalin._die()` cheamă `nether.boss_invins()`, care anunță **„THE WAY IS OPEN"**.
- Structura de invocare: în loc de offset fix, cade pe un **inel 600–1000px** în jurul portalului de intrare, la unghi aleator. Raza se ia ca `sqrt(lerp(min², max², randf()))` — cu o distanță pur aleatoare punctele s-ar înghesui spre marginea interioară a inelului, fiindcă inelul are mai multă suprafață în exterior.

**Capcana de proiectare, rezolvată tot aici:** `exit_nether(anunt=false)` e drumul pe care îl folosesc **moartea player-ului** (`player.die()`) și plasa de siguranță din `_process`. Dacă blocam ieșirea necondiționat, un player mort ar fi rămas agățat într-o dimensiune fără decor, cu `Difficulty.frozen` pe true. De aia poarta se aplică **doar** când `anunt == true` (adică „ieșire voluntară, pe portal"); parametrul are acum și înțelesul ăsta, scris explicit în comentariu.

**Busola urmărește acum obiectivul, nu portalul** (`_tinta_busola()`): structura de invocare → Saratalin → portalul de întoarcere. Altfel săgeata te-ar fi trimis insistent spre o ușă încuiată, iar structura, mutată la 600–1000px, e acum ceva ce chiar trebuie găsit pe o câmpie identică peste tot.

**Verificat prin rulare:** 10 intrări la rând → distanțe 650…954px, unghiuri împrăștiate pe tot cercul, toate în interval ✅; E pe portal fără boss → rămâi în Nether, cu mesajul pe ecran (captură) ✅; busola: `SummoningPortal` → `Saratalin` → `Portal` ✅; după ce cade → E pe portal → ieși ✅; capturi cu toate cele trei texte.

---

## Session log — 2026-07-26 (SARATALIN, boss-ul Nether-ului + structura care îl cheamă)

**Cerut de Răzvan:** „ți-am băgat o structură nouă și un boss nou în `harta/nether/Nether Boss`. Saratalin e bossul — îl faci tu frumos pe frame-uri că trebuie tăiat. Summoning Portal e structura care îl sumonează. Vreau la fel, cu un cutremur să se sumoneze și statuia să se ducă în pământ ca cealaltă. Dar bossul Saratalin vreau să coboare din tavan (coboară de unde nu vede player-ul)."

**Tăierea foii, măsurată nu ghicită:** `Saratalin.png` e 3360×240. Am numărat coloanele complet transparente cu un script headless → **15 benzi pline**, deci **15 cadre de 224×240**. Centrele benzilor cad la ±2px de centrele feliilor de 224 (legănarea naturală a animației), deci felierea uniformă e corectă. NU am tăiat-o în 15 fișiere: `saratalin.gd` face 15 `AtlasTexture` peste aceeași imagine (ca frunzele din `leaffall.gd`). Schimbi foaia → schimbi `FRAMES`/`FRAME_W`, atât.

**`summoning_portal.gd`** e sora statuii: simbol de alertă, cutremur, structura se scufundă și dispare, apoi cheamă boss-ul. Diferența cerută: **`saratalin.coboara_din_tavan()`** îl mută cu o jumătate de ecran + `ceiling_margin` DEASUPRA locului de aterizare și îl lasă să plutească în jos. Jumătatea de ecran se calculează în pixeli de LUME (`viewport.y / cam.zoom.y * 0.5`) — cu zoom 0.7 ies ~463px, deci 260 de margine peste. **Mutăm tot nodul, nu doar sprite-ul** (cum face `statue.gd` cu Garda): dacă mutam doar arta, corpul era deja jos și te lovea un boss invizibil cât „cobora".

**`hitbox_reglabil.gd` (nou):** butoanele Nord/Sud/Est/Vest + conturul au ieșit din `portal.gd` într-un script de bază `@tool`, din care moștenesc acum și `portal.gd`, și `summoning_portal.gd` (`extends "res://hitbox_reglabil.gd"`). O singură copie a codului, aceleași butoane pe ambele structuri.

**Două lucruri prinse de capturile de ecran, nu de cod:**
1. **Proiectilele boss-ului rămâneau violet ca ale Gărzii.** Cauza: puneam `proj.tint` DUPĂ `add_child()`, iar `lightning.gd` citește `tint` o singură dată, în `_ready()` — care se declanșează exact când nodul intră în arbore. `tint` se pune ÎNAINTE de `add_child`. (`damage`/`speed` se citesc în fiecare cadru, de aia pe alea nu le deranja ordinea — și de aia bug-ul nu se vedea în `garda.gd`.)
2. Aceeași capcană de inferență ca la conturul portalului, de data asta în scenă de test: `var altar_y := altar.global_position.y` nu compilează când `altar` e untyped.

**⚠️ `portal.tscn` fusese modificat de Răzvan** între sesiuni: hitbox-ul dus la 250×60 (a tras de pătrățelele lui `CollisionShape2D`). Fiindcă acum comanda o dau exportările, valoarea lui s-ar fi pierdut tăcut la următoarea încărcare — am mutat-o în butoane (`nord/sud = 30`, `est/vest = 125`). **De verificat la fiecare sesiune viitoare:** dacă `git status` arată `.tscn`-uri atinse de el, prima întrebare e dacă valoarea aia mai supraviețuiește logicii din script.

**Verificat prin rulare reală** (scenă de test, tasta E apăsată pe bune, apoi ștearsă): structura apare lângă portalul de întoarcere cu „Press E to interact" ✅; E → se scufundă și dispare ✅; boss-ul apare cu **719 HP** (700 × dificultate) și **15 cadre** cu regiunile exacte (cadrul 14 la x=3136) ✅; pornește la **898px deasupra player-ului**, cu ecranul de ~926px înălțime în lume — deci în afara câmpului vizual ✅; aterizează la ținta ei și pornește după player (dy=50px într-o secundă) ✅; cercul de 14 proiectile magenta, verificat pe captură ✅.

**Rămas de făcut, dacă vrea:** proiectilul e tot bastonul Gărzii, doar recolorat — e artă provizorie.

---

## Session log — 2026-07-26 (butoane pentru hitbox-ul portalului)

**Cerut de Răzvan:** „pune-mi butoane să pot să fac eu hitbox-ul manual la portal."

**`portal.gd` a devenit `@tool`** — rulează și în editor, deci cifrele se aplică pe loc în fereastra de editare, fără să pornească jocul. Butoane noi pe nodul `Portal`, în grupul „Hitbox":
- **`nord` / `sud` / `est` / `vest`** — cât se întinde zidul din talpa portalului în fiecare direcție, în pixeli. **A doua iterație:** prima variantă avea `hitbox_size` + `hitbox_pos` (mărime + centru, cum gândește Godot), dar Răzvan a cerut explicit pe laturi — mult mai ușor de reglat când vrei „doar puțin mai sus". Traducerea e în `_aplica_hitbox()`: `size = (vest+est, nord+sud)`, `position = ((est-vest)/2, (sud-nord)/2)`.
- `vezi_hitbox` — desenează conturul, **și în joc**: dreptunghi roșu cu literele N/S/E/V pe laturi, cerc albastru = `interact_range` (de unde apare „Press E"), punct+linie galbenă = originea nodului / linia de Y-sort.

**⚠️ Capcana care ne-a costat o tură** — Răzvan a zis „nu e niciun meniu de hitbox în Inspector". Cauza reală, găsită abia când am cerut lista de proprietăți a nodului: în clasa internă `Contur`, `var sus := -portal.nord` **nu compilează** — `portal` e declarat `Node2D`, deci GDScript nu știe ce tip are `nord` și refuză inferența. Un `@tool` care nu compilează **nu dă niciun semn în Inspector**: nodul apare pur și simplu fără proprietățile din script, ca și cum n-ar avea script. Tipurile din clasa internă se scriu explicit (`var sus: float = ...`).
**Cum se verifică**, fiindcă `--check-only --script res://portal.gd` a trecut fără să sufle o vorbă: instanțiezi scena într-o scenă de test și tipărești `get_property_list()`, filtrat pe `PROPERTY_USAGE_GROUP` / `PROPERTY_USAGE_SCRIPT_VARIABLE`. Aia e exact lista pe care o vede Inspector-ul. Dacă grupul tău nu e acolo, nici Răzvan nu-l vede.

**Restul lucrurilor de reținut, dacă se mai umblă pe aici:**
1. **Conturul e un nod separat** (clasa internă `Contur`), nu `_draw()` în `Portal`. Copiii se desenează PESTE părinte, deci liniile ar fi rămas ascunse sub `Sprite2D`. Nodul e adăugat ultimul, cu `z_index = 100`. Nu are `owner`, deci nu se salvează în `.tscn` când Răzvan salvează scena din editor.
2. **Forma se duplică la rulare.** `RectangleShape2D` e sub-resursă a scenei → toate portalurile ar împărți același obiect și ultimul încărcat ar redimensiona-o pentru toate. În editor NU duplicăm (acolo vrem exact resursa din fișier, ca modificarea să se salveze). Testat cu două portaluri cu hitbox-uri diferite: nu se calcă.
3. **Sursa adevărului s-a mutat.** Înainte, README-ul zicea „scriptul nu atinge niciodată hitbox-ul, ce vezi în editor aia iese". Acum comanda o dau exportările; dacă tragi de pătrățelele portocalii ale lui `CollisionShape2D`, modificarea se pierde la următoarea încărcare. Scris explicit în comentariul de sus din `portal.gd` și în README.

**Valorile implicite dau exact hitbox-ul de dinainte:** N20 S20 E115 V115 → 230×40. Singura diferență e că centrul cade la `(0, 0)` în loc de `(0, 0.4)` — 0.4px, adică nimic, în schimb cifrele sunt rotunde. `portal.tscn` a rămas neschimbat.

**Verificat:** lista de proprietăți conține `[GRUP] Hitbox` + `nord/sud/est/vest/vezi_hitbox`; N80 S20 E40 V115 → `size=(155, 100)`, `pos=(-37.5, -30)` (exact cât trebuie); două portaluri cu hitbox-uri diferite nu se calcă (forme duplicate); captură din joc cu conturul + literele desenate peste artă; `portal.tscn` deschis în editor headless, zero erori de la `@tool`.

**Dacă Răzvan zice iar că nu vede butoanele:** întâi întreabă dacă avea Godot deschis când s-a schimbat scriptul — editorul ține minte versiunea veche a unui `@tool`; **Project → Reload Current Project** rezolvă. Al doilea suspect: click pe nodul de sus `Portal`, nu pe `CollisionShape2D`.

---

## Session log — 2026-07-26 (sunetul Nether-ului: muzică, pași, teleport)

**Cerut de Răzvan:** „ți-am făcut un folder în audio — `Nether Audio`. `sky-lines` să fie melodia care e mereu pe loop când ești în Nether. `Footsteps_nether` sunt pașii. `Teleport sfx` e sunetul când apeși E pe Portal 1."

**`audio.gd`:**
- două sunete noi în `SFX`: `footsteps_nether` și `teleport`; muzica Nether-ului stă separat, în `MUSIC_NETHER` (una singură, nu listă ca `MUSIC_GAME` — în Nether e mereu aceeași).
- `play_nether_music()` / `restore_world_music()`. Partea interesantă: la intrare ținem minte **ce** cânta ȘI **din ce secundă** (`_music.get_playback_position()`), iar la întoarcere dăm `seek()` acolo. Altfel melodia lumii ar fi luat-o de la capăt la fiecare ieșire din Nether — s-ar fi auzit ca și cum ai reporni runda. `play_music()` (rundă nouă) uită ce era memorat, ca să nu rămână agățat între runde.
- fișierele sunt în `audio/Nether Audio/` — folder cu **majusculă și spațiu**, dar de data asta fără probleme: nu l-am redenumit, deci `.import`-urile au fix aceeași scriere ca pe disc (spre deosebire de pățania cu `harta/Nether`).

**`nether.gd`:** la intrare `Audio.play("teleport", TELEPORT_DB, 0.0)` + `Audio.play_nether_music()`; la ieșire `Audio.restore_world_music()` și whoosh-ul **doar dacă ieși pe portal** (dacă ai murit, nu — nu e o teleportare). Jingle-ul de „levelup" folosit înainte ca sunet de intrare/ieșire a fost scos, acum e whoosh-ul adevărat. `pitch_rand = 0.0` la teleport — e un sunet-semnătură de 3.2s, nu vrem alt ton de fiecare dată (`play()` variază implicit ±8%).

**`player.gd`:** pasul verifică întâi Nether-ul, apoi biomul: `footsteps_nether` / `footsteps_sand` / `footsteps_grass`. Căutarea în grup e ieftină aici — pașii sunt oricum rari (`STEP_GAP`).

**Verificat** (scenă de test cu tasta E apăsată pe bune, ștearsă după): lumea pornește pe una din cele două melodii random (`tiny-rpg-town`) → E pe portal → muzica devine `sky-lines.ogg` cu `loop=true`, whoosh-ul chiar sună pe o boxă (nu doar „cerut"), pașii devin `footsteps_nether` → E pe portalul de întoarcere → revine `tiny-rpg-town` **de la 2.63s** (era la 2.19 când am plecat, deci a continuat, n-a repornit), pașii revin la `footsteps_grass`. ✅

**Rămas neatins:** `harta/nether/Nether Boss/Agis.png` — asset pus de Răzvan, încă nefolosit de vreun script. L-am lăsat necommis, e materie primă pentru un boss de Nether.

---

## Session log — 2026-07-26 (dimensiune nouă: NETHER — intri pe Portal cu E)

**Cerut de Răzvan:** „vreau să fac o nouă dimensiune (într-un fel ca Limbo) — când apeși E pe Portal 1 să te teleporteze într-o dimensiune nouă; ai un folder Nether în Harta, acolo e tileset-ul pentru floor." A ales apoi: **întoarcerea DOAR prin portal** (stai cât vrei), **cronometru propriu de 7:00**, la **0:00 începe Nether Swarm**, înăuntru sunt **inamici + XP dublu**, iar **cronometrul rundei stă înghețat** cât ești acolo.

**`harta/nether/Brick32.png`** e o textură de 128×128 care se repetă fără cusătură (cărămidă roșu-închis) — nu un atlas de tileset, deci merge direct ca podea infinită.

**Ce am făcut — `nether.gd`** (nod `Nether`, CanvasLayer în `main.tscn`, grup „nether"), copiind tiparul din `limbo.gd`: NU se încarcă altă scenă, rămâi la aceleași coordonate, dar:
- **podeaua** trece pe cărămidă. Truc: `biome.gdshader` amestecă `grass_tex` cu `desert_tex` după harta de biomuri — dacă îi dai ACEEAȘI textură pe amândouă, iese cărămidă peste tot, fără să scoți materialul și fără să atingi harta de biomuri. Butonul de mărime e `nether_tile_size` (96; fișierul e 128, iarba e 64). Vezi `ground.set_nether()`; nodul `Ground` intră acum în grupul „ground".
- **decorul e oprit și golit**: `Props`, `Rocks`, `DesertStructures`, `Statues`, `Portals` (din `World`) + `Paths` (frate cu `World`). Ca la Limbo, nu e destul să le ascunzi — le golim de copii ȘI le resetăm `_loaded`, altfel la întoarcere ar crede că bucățile există deja și lumea ar rămâne goală.
- **cronometrul rundei îngheață** (`Difficulty.frozen`), iar tăria inamicilor o dictează `_diff_time()`: maximul dintre `intrare + cât stai` și, după 0:00, `RUN_LENGTH + cât a trecut de la 0:00`. Două drepte, luăm maximul → nu scade niciodată brusc, și după 0:00 intri automat pe curba exponențială de Final Swarm.
- **XP dublu**: `Difficulty.xp_bonus` (nou), înmulțit în `xp_mult()`; `nether.gd` îl pune pe 2.0 la intrare și 1.0 la ieșire.
- **portalul de întoarcere** e tot `portal.tscn`, cu `retur = true`, pus **exact pe locul portalului prin care ai intrat** — nu peste player. (Prima variantă îl punea pe player și zidul portalului îl împingea afară: la test ajunsese la 40px de unde trebuia.) Stă direct în `World`, nu în `Portals`, ca golirea generatorului să nu-l șteargă.
- **busolă**: cât portalul nu se vede pe ecran, o săgeată portocalie lipită de marginea ecranului arată încotro e, cu distanța sub ea. Fără ea te pierzi — Nether-ul e o câmpie infinită identică peste tot, cu o singură ieșire.
- **inamicii** vin din spawner-ul normal (deja reglat), plus un val de `BURST` la intrare. Ambientul de pădure se oprește cât ești acolo.

**`portal.gd`** joacă acum ambele roluri, după steagul `retur`: fals (portalurile din lume) → intri; adevărat (cel pus de `nether.gd`) → ieși. `invoca()` nu mai e gol.

**Bug real găsit și reparat pe drum:** `Difficulty` e autoload, deci dacă ieșeai în meniu din Nether (sau **din Limbo — bug care exista deja**), rămâneai cu `frozen = true` și override-urile agățate, iar **runda următoare pornea cu cronometrul blocat**. Am adăugat `Difficulty.reset_run()` (curăță time + frozen + override + xp_bonus), chemat din `spawner._ready()` în locul lui `Difficulty.time = 0.0`.

**Moartea în Nether:** `player.die()` scoate ÎNTÂI din dimensiune (`exit_nether(false)`, fără anunț), abia apoi merge pe drumul normal. Altfel Limbo (Undying Spirit) ar reporni decorul peste podeaua de cărămidă și cele două s-ar călca reciproc pe `mult_time_override`. `nether.enter()` refuză și el să pornească peste un Limbo activ.

**Folder redenumit `harta/Nether` → `harta/nether`:** Godot dădea „Case mismatch… stored as res://harta/nether/…", ceea ce ar fi crăpat la exportul pe Android (sistem case-sensitive). Restul folderelor din `harta/` sunt oricum lowercase.

**Verificat (rulare reală, 3 teste, capturi):**
- Intrare/ieșire cu **tasta E apăsată pe bune** (`InputEventKey` prin `Input.parse_input_event`): nether activ true→false, cronometrul rundei se ascunde și reapare. ✅
- Generatoare: `Props/Rocks/DesertStructures/Statues/Portals = 49 → 0 → 49`, `Paths = 81 → 0 → 81`; podeaua `grass → Brick32 → grass`. ✅
- Cronometrul rundei chiar stă (1.50 → 1.50 după o secundă), cel de Nether curge (418.8 → 417.8). ✅
- La 0:00: `mult_time_override` sare la 601, viața inamicilor **1.04× → 32.4×**, iar în 2 secunde mai urcă la 33.2× (exponențial); cronometrul devine roșu și scrie `+0:02`. ✅
- Ieșire în meniu din Nether → rundă nouă: `frozen=false`, `override=-1`, `xp_bonus=1`, cronometrul curge, podeaua e iarbă. ✅
- Un fals-pozitiv de test: la un moment dat E nu mai funcționa — cauza era ecranul de **Level Up deschis** (XP-ul de 102× îl urcase la nivel 5) care pune jocul pe pauză. Comportament corect, nu bug.

**Ce reglezi ușor (toate în capul lui `nether.gd`):** `NETHER_TIME` (7:00), `XP_BONUS` (2.0), `BURST`/`BURST_RADIUS` (valul de la intrare), `COMPASS_MARGIN`, culorile cronometrului. Mărimea dalelor de cărămidă: `nether_tile_size` pe nodul `Ground`.

---

## Session log — 2026-07-26 (ESC pune pe pauză TOT sunetul)

**Cerut de Răzvan:** „vreau să se pună pauză la tot sunetul atunci când dau ESC."

**Ce am făcut:**
- **`audio.gd`: `pause_all()` / `resume_all()`** — pun `stream_paused = true` pe muzică, pe ambientul de pădure și pe toate cele 12 boxe din pool. **`stream_paused`, nu `stop`**: la Resume totul continuă exact de unde a rămas (ca butonul de pauză de la un player), inclusiv un efect prins la jumătate.
- **Excepție necesară:** `play()` face acum `p.stream_paused = false` pe boxa pe care o ia. Fără asta, clicurile din meniul de pauză și clicul-preview de la slider-ul SFX (`settings_ui.gd:100`) ar fi fost mute — boxele erau înghețate, iar `_find_free_player()` le vede tot ca „ocupate" (o boxă pe pauză raportează `playing = true`).
- **`pause.gd`:** `Audio.pause_all()` în `_open_menu()`, `Audio.resume_all()` în `_close_menu()` — **și în `_on_main_menu()` + `_on_restart()`**. Ultimele două sunt obligatorii: `Audio` e autoload, supraviețuiește schimbării de scenă, deci boxele înghețate ar fi rămas mute în meniu / în runda nouă (tema de meniu ar fi „cântat" fără sunet).

**Verificat (end-to-end, joc real):** scenă de test care instanțiază `main.tscn` și trimite un `InputEventKey` ESC prin `Input.parse_input_event` → meniu vizibil, `tree.paused = true`, muzică și ambient pauzate, iar după 1 secundă pe pauză **muzica a avansat cu 0.000s**. ESC din nou → meniul se închide și în următoarea secundă muzica avansează **0.981s**. Separat: un clic de buton dat în timpul pauzei chiar dezgheață o boxă și se aude, muzica rămânând pe pauză. Fișierele de test șterse.

**De știut:** din pauză → Settings, slider-ul **Music** nu-ți dă feedback audibil (muzica e pe pauză); cel de **SFX** da, fiindcă are clicul de preview. Dacă te încurcă, se rezolvă ușor: `Audio.resume_all()` la intrarea în pagina de Settings și `pause_all()` la ieșire.

---

## Session log — 2026-07-26 (muzică de fundal în joc: 2 melodii, aleasă random la fiecare rundă)

**Cerut de Răzvan:** „ți-am adăugat un folder în audio — acolo sunt 2 melodii de fundal pentru când începe jocul. Le dai play random de fiecare dată."

**Ce am făcut** (tot în `audio.gd`):
- Folderul nou e `audio/First 5 Minutes - Main World/` cu `Ruined_Place.ogg` și `tiny-rpg-town.ogg`. N-aveau `.import` → rulat `"<godot>" --headless --path <proiect> --import` (fără asta `ResourceLoader.exists()` dă fals la rulare directă și n-ar fi sunat nimic).
- `MUSIC_GAME` era `""` (muzica din joc era **oprită** de la refactorul de dificultate). Acum e un **array** cu cele două căi. Ca să adaugi o melodie nouă: pui fișierul în folder + o linie în array, nimic altceva.
- `play_music()` filtrează întâi căile care chiar există (`ResourceLoader.exists`) și alege una la întâmplare cu `randi() % size()`. Dacă lista iese goală (fișier șters/redenumit) → `stop_music()`, adică tăcere, nu eroare.
- N-am atins fluxul: `spawner._ready()` cheamă `Audio.play_music()` la începutul rundei, `menu.gd` face `stop_music()` când intri în joc → `_music_path` e gol, deci verificarea „cântă deja aceeași piesă" nu blochează niciodată alegerea nouă. Loop-ul infinit și volumul (slider-ul „Music") merg ca înainte, sunt în `_play_track()`.

**Verificat (rulare reală, scenă temporară de test):** 8 porniri consecutive au dat `tiny, tiny, Ruined, tiny, Ruined, tiny, Ruined, Ruined` — deci chiar alternează random; `playing=true`, poziția înaintează (0.88s după 1s), `stream.loop = true`, volum `-15.1 dB` (−12 de bază + slider-ul). Fișierele de test șterse după.

**Ce reglezi ușor:** volumul de bază = argumentul lui `play_music()` (implicit `-12.0`, în `audio.gd`); lista de melodii = `MUSIC_GAME`.

---

## Session log — 2026-07-26 (structură nouă: Portal 1 — rar, interactibil, momentan fără efect)

**Cerut de Răzvan:** „ți-am băgat o structură nouă în folderul harta, Portal 1. Să se spawneze mai rar ca statuia și să fie tot interactibil la fel ca statuia, dar momentan nu face nimic." A ales: **1.5%** raritate și **zid ca statuia**.

**Ce am făcut:**
- **Import:** `harta/Portal 1.png` (128×128, artă folosită 104×113) n-avea `.import` — rulat `--headless --import`, altfel `load()` crapă la rulare directă (editorul importă la deschidere, jocul nu).
- **`portal.tscn` + `portal.gd`** (`StaticBody2D`) — copiat tiparul statuii: hitbox `RectangleShape2D` 230×40 la `y=0.4` (statuia are 130×40; portalul e mult mai lat — arta lui face 249px pe ecran la scale 2.4), `ACOPERIRE_JOS = 74` cu `_aseaza_pe_origine()` calculat din `get_used_rect()` la rulare, ca să acopere player-ul complet la y-sort. `invoca()` e **gol intenționat**.
- **`portals.gd`** — geamăn cu `statues.gd`: chunk-uri de 512, `load_radius 3`, sămânță proprie `SEED_SALT = 0x9C4E` (altfel ar cădea peste statui, fiind aceeași `hash(key)`). `portal_chance = 0.015`. Pe lângă copaci și pietre se ferește și de **statui** (`min_dist_statue = 260`) — poate întreba `Statues.chunk_statue_pos()` chiar și pentru chunk-uri neîncărcate, fiindcă e determinist, fără noduri.
- **Grup nou `"interactable"`** — `interact_ui.gd` itera grupul `"statue"`; acum iterează `"interactable"`, iar statuia intră în ambele (grupul `"statue"` nu-l mai folosește nimeni altcineva, dar l-am lăsat). Orice obiect viitor cu `interact_range` + `poate_invoca()` + `invoca()` primește textul „Press E to interact" gratis.
- **`main.tscn`:** nod `World/Portals` (y_sort) lângă `World/Statues`.

**Verificat (runtime + capturi):**
- Portal lângă statuie pe aceeași linie de sol: ambele au baza artei la exact 74px sub linia de sortare. ✅
- Rată pe 10.000 de chunk-uri: **116 portaluri vs 294 statui** → ~1.16% vs ~2.94%, deci de **~2.5× mai rar**. (1.16 < 1.5 fiindcă filtrele de distanță resping ~23% din chunk-urile alese — la fel se întâmplă și la statui.)
- În lumea reală: portalul apare, scrie **„PRESS E TO INTERACT"** deasupra lui, apăsarea nu face nimic (corect).
- Coliziune: `move_and_collide` spre nord → **`BLOCAT de: Portal`**. ✅

**Ce reglezi ușor:** `portal_chance` pe nodul `Portals` (raritate), `interact_range` în `portal.gd` (de la ce distanță apare textul), `CollisionShape2D` din `portal.tscn` (zidul). Când vrei să facă ceva, scrii în `invoca()` din `portal.gd`.

**Corectură în aceeași sesiune — „lasă-mă să fac hitbox-ul manual":** Răzvan vrea să regleze hitbox-ul VIZUAL în editor. Cu `_aseaza_pe_origine()` rulând în `_ready()`, arta se muta la rulare față de cum o vedea în editor → hitbox-ul potrivit vizual s-ar fi dezlipit, iar orice ajustare a lui `Sprite2D.offset` ar fi fost suprascrisă tăcut de script. **Fix:** offset-ul (`-25.166667`) e acum **copt în `portal.tscn`**, iar `_aseaza_pe_origine()` a fost **ștearsă** din `portal.gd`. Scena e singurul adevăr: ce vezi în editor = ce iese în joc. Statuia își **păstrează** funcția — ea are 3 variante care se termină la pixeli diferiți, deci chiar are nevoie de calcul la rulare; portalul are o singură textură. **Verificat:** `offset.y = -25.1667` la rulare și baza artei la **74.0px** sub linia de sortare (identic cu înainte, captura la fel).

---

## Session log — 2026-07-25 (pentru Windows: pagină Settings — sunet + taste remapabile)

**Cerut de Răzvan:** „hai să-l facem pe sistem de Windows; adaugă la meniu o pagină de settings unde poți schimba sunetul și butoanele."

**Context (neevident):** proiectul NU era blocat pe mobil — renderer-ul „Mobile" din Godot merge la fel pe PC, iar `export_presets.cfg` avea deja un preset **Windows Desktop**. Singura problemă reală era controlul: player-ul citea `Input.get_vector("ui_left"…)` (acțiunile implicite Godot), care nu se puteau remapa din meniu. **NU am redenumit** `config/name` din `JOC-BZN-Mobile` — ar muta folderul `user://` și s-ar pierde monedele/scorurile salvate.

**Ce am făcut:**
- **`game_settings.gd`** — sursă de adevăr pentru setări:
  - `music_volume` (0.7) și `sfx_volume` (1.0), salvate în `scores.save`.
  - Acțiunile de mișcare `move_up/down/left/right` le **creez din cod** în `_setup_actions()` (după `_load`), NU în `project.godot` — tocmai ca să le pot remapa. Implicit **WASD + săgeți** (două taste per direcție); când jucătorul alege alta, `rebind()` înlocuiește cu tasta lui și salvează în `keybinds` (physical_keycode, merge pe orice layout). `key_name()` dă textul afișat (ex. „W").
- **`player.gd`** — o linie: `get_vector` folosește acum `move_*` în loc de `ui_*`.
- **`audio.gd`** — volumul se aplică din setări: SFX în `play()` (`+ _lin_to_db(sfx_volume)`, throttle-ul existent limitează clicurile de test), muzica în `_play_track` peste `_music_base_db`; `refresh_music_volume()` ajustează pe loc melodia care cântă când miști slider-ul. `_lin_to_db(0)` = -80 dB (mut, nu -inf).
- **`menu.gd`** — pagina **SETTINGS**:
  - Deschisă dintr-o **rotiță ⚙** ancorată dreapta-sus (NU în lista verticală de butoane — 6 butoane ar fi ieșit din ecranul de 648px; calculul e în comentariul vechi de la titlu). Rotița se estompează/activează odată cu butoanele la intro.
  - Slidere **MUZICĂ** / **EFECTE** (HSlider 0..1), 4 rânduri de remapare **Sus/Jos/Stânga/Dreapta** cu buton ce arată tasta.
  - Remapare: apeși butonul → „apasă o tastă…" → următoarea tastă din `_input` devine comanda (Escape = renunț). Handler-ul de remap stă înaintea skip-ului de intro.

**Capcană rezolvată:** în `_key_row` uitasem `row.add_child(b)` — butonul de tastă exista (în `_remap_buttons`) dar n-avea părinte, deci nu apărea (doar eticheta Sus/Jos…). Prins cu un `_dump()` de arbore pe screenshot.

**Verificat (screenshot-uri + test runtime):** meniul principal cu ⚙ intact (fără overflow); pagina Settings completă (slidere la 0.7/1.0, taste W/S/A/D); `InputMap` chiar are `move_* → [WASD, săgeți]`; în joc, `Input.action_press("move_right")` → `get_vector=(1,0)` și **player.velocity=(315,0)** (se mișcă). Test-scenele temporare șterse după.

**Export `.exe` — BLOCAT:** folderul `AppData\Roaming\Godot\export_templates\` e **gol** (niciun template instalat). Fără el, `--export-release "Windows Desktop"` nu poate construi `.exe`-ul. Jocul rulează deja pe Windows din editor/executabil; pentru un `.exe` dublu-click trebuie descărcate template-urile 4.7 (din editor: *Editor → Manage Export Templates → Download*, ~1 GB), apoi export. De confirmat cu Răzvan înainte de descărcare.

## Session log — 2026-07-25 (balans audio pe tot jocul)

**Cerut de Răzvan:** analizează tot audio-ul și fă-l balansat; stingătorul cu 0.5x mai scăzut.

**Metodă (nu din ureche):** am măsurat **loudness-ul real (RMS dBFS + peak)** al fiecărui fișier citind PCM-ul din WAV-urile ORIGINALE (`od`+`awk`; stream-urile importate sunt QOA, necitibile direct). Apoi offset = `target_efectiv - RMS_fișier`, plafonat ca `peak × gain < 1.0` (fără clipping). RMS măsurate: hurt -13.6, sword/extinguisher -15.1, levelup -16.3, button -19.4, garda -20.0, game_start -30.3, game_over -33.1, footsteps ~-35, forest_ambient **-53.6** (înregistrat extrem de încet).

**Mix nou (efectiv = RMS + offset):**
- Cluster acțiune/evenimente ~-18: `levelup -2`, `hurt -4.5`, `sword -4`, `game_start +12`, `game_over +16` (ultimele două erau la -30/-33 = aproape nimic; boostate, dar peak rămâne <1.0: 0.98 / 0.88).
- `garda_attack 0` (peak fișier deja 1.0 → nu se poate mări, rămâne ~-20).
- `button -3` (UI, ~-22) — la meniu prin constanta `CLICK_DB`.
- **`extinguisher -10`** (era -4): ~-25, adică 0.5x mai încet (cerut) + e continuu.
- `footsteps_grass -1` / `footsteps_sand -3` (egalizați între ei, ~-37, subtili) — înainte ambii -8.
- `AMBIENT_DB 20` (era -6): fișierul e la -54dBFS, deci +20 îl aduce la ~-34 efectiv (bed prezent dar discret; peak 0.27).

**De reținut:** sunetele „hot" (peak = 1.0: levelup, hurt, extinguisher, sword, garda) se pot DOAR atenua, nu mări. Cele înregistrate încet (game_start/over, ambient) au avut nevoie de boost mare. `shoot`/`hit`/`enemy_die`/`xp` rămân nemapate (fără fișier) = tăcere. Verificat: parse OK, zero clipping.

**Ajustare (cerut de Răzvan, tot 2026-07-25):** ambient, footsteps și game_start cu 0.5x (-6dB): `AMBIENT_DB 20→14`, footsteps `grass -1→-7` / `sand -3→-9`, `game_start 12→6`. Plus: ambientul se **pune pe pauză cât alegi un power up** și continuă de unde era — `Audio.pause_forest_ambient()` / `resume_forest_ambient()` (folosesc `stream_paused`, nu stop → păstrează poziția), chemate din `levelup.gd` (`_show_choices` la deschidere / `_on_choice` la închiderea finală). `play_forest_ambient` resetează `stream_paused=false` ca siguranță. Verificat: la pauză poziția îngheață (~11ms scurgere = un buffer), la reluare continuă.

## Session log — 2026-07-25 (interacțiune: text „Press E" în loc de buton SUMMON + tastă remapabilă)

**Cerut de Răzvan:** scoate butonul SUMMON de pe ecran; deasupra statuii să scrie „Press E to interact" (font-ul jocului, gri); și adaugă tasta asta în Settings.

**Făcut:**
- **`game_settings.gd`:** `MOVE_ACTIONS` redenumit **`KEY_ACTIONS`** (nu mai e doar mișcare) + adăugat acțiunea `interact` (implicit **E**). E remapabilă la fel ca mișcarea (creată în `_setup_actions`, salvată în `keybinds`). `settings_ui.gd` iterează `KEY_ACTIONS` → apare automat rândul „INTERACT" în Settings (verificat: încape).
- **`interact_ui.gd` rescris:** scos butonul `SUMMON`. Acum un `Label` gri („Press %s to interact" cu tasta reală — se schimbă dacă o remapezi) deasupra statuii celei mai apropiate care `poate_invoca()`. E în CanvasLayer, dar poziționat convertind poziția statuii lume→ecran (`get_viewport().get_canvas_transform()`), ca să stea fix deasupra și să nu intre în y-sort. Apeși `interact` (`_unhandled_input`) → `invoca()`. Fontul global (HomeVideo) se aplică singur → textul iese cu majuscule, ca restul jocului.
- `world_offset_y = -175` (cât de sus deasupra statuii), reglabil din Inspector pe nodul InteractUI.

**Verificat (runtime + screenshot):** acțiunea `interact` există cu E; textul „PRESS E TO INTERACT" apare gri deasupra statuii; apăsarea E o invoacă (`poate_invoca()`→false); pagina Settings arată rândul INTERACT și încape (5 rânduri + BACK).

## Session log — 2026-07-25 (fix: inamici lipiți/teleportare + inamici prin copaci)

**Cerut de Răzvan:** (1) inamicilor li se vede modelul prin copaci când sunt la nord; (2) inamicii rămân lipiți de player sau player-ul e teleportat la ei.

**#2 — lipire/teleportare (cauza reală, reparat complet):** NIMIC n-avea `collision_layer/mask` setat → totul pe layer 1, deci player + inamici + obstacole se ciocneau toți. Player și inamici pe același layer → `move_and_slide` îi împinge, iar o gloată îl ejecta pe player (teleportare). **Fix — layere separate:** L1=obstacole (copaci/pietre/statui), L2=player, L3=inamici. player `layer 2 mask 1` (blocat de obstacole, trece prin inamici); enemy+garda `layer 4 mask 1` (blocați de obstacole, trec prin player și între ei). Detecția Area2D filtrează pe grup DUPĂ mască, deci am actualizat: gloanțe (`bullet*.tscn`) `mask 4` (inamici), fulgerul Gărzii (`lightning.tscn`) și gemele XP (`xp*.tscn`) `mask 2` (player). **Verificat runtime:** player mutat 0px când un inamic intră peste el; inamicul trece peste player (nu se lipește); gloanțele tot lovesc (hp scade); XP tot se ridică. Contact damage rămâne pe distanță (nu pe coliziune), deci nefectat.

**#1 — inamici prin copaci la nord (îmbunătățit, nu perfect):** copacii sortează Y la ~35.5% în sus pe trunchi (`sort_anchor=0.355`), deci un inamic mare (sprite 120px × 1.5) sortează după centrul lui și rămâne desenat „în față" până când picioarele-i trec MULT de bază. **Fix:** coborât `sort_anchor` 0.355→**0.15** pe nodul `Props` (main.tscn) → linia de sortare mai jos, spre bază, inamicii/player-ul trec în spate mai devreme. **Sigur:** matematic `centru_sprite = gen_y − 0.5·h·scale`, INDEPENDENT de `sort_anchor` → copacii rămân plantați; hitbox-ul e deja decuplat (pe rădăcină, nu pe anchor). **Limitare:** ocluzia perfectă e greu pentru sprite-urile mari de inamici — 0.15 ajută dar nu elimină complet; valoarea se poate regla 0.10–0.20 după gust. Y-sort-ul folosește `position.y` a NODULUI (nu offset-ul sprite-ului) — de-aia fix-ul e pe linia copacului, nu pe sprite-ul inamicului.

## Session log — 2026-07-25 (audio ambiental + pași pe biom)

**Cerut de Răzvan:** ambient de pădure care se aude mereu în pădure și se estompează lin la intrarea/ieșirea din deșert; pași separați pe nisip (`Footsteps_Sand_Run_01`) și pe iarbă (`Footsteps_Grass_Run_01`, înlocuiește vechiul `Footsteps.wav`).

**Făcut (`audio.gd`):**
- SFX: scos `footsteps` (fișierul `Footsteps.wav` a fost șters de Răzvan), adăugat `footsteps_grass`, `footsteps_sand`, `forest_ambient`.
- **Ambient de pădure:** un `AudioStreamPlayer` în buclă (`play_forest_ambient` / `stop_forest_ambient`). În `_process`, volumul urmărește **lin** (lerp, `AMBIENT_FADE`) „cât de pădure" e locul de sub player: `target = 1 - clamp(BiomeMap.desertness_at_chunk(pos/512))`. Deci în pădure e la `AMBIENT_DB` (-6), în deșert se stinge spre tăcere; trecerea prin gradient dă fade-ul. Merge pe `sfx_volume` (ca pașii). Pornit în `spawner._ready`, oprit în `menu._ready`.
- **Capcană WAV loop (m-a prins):** setasem `loop_mode=LOOP_FORWARD` + `loop_begin=0` dar NU `loop_end` → el rămâne 0, loop-ul `[0,0]` e gol și playback-ul se blochează pe loc (pornea și se oprea în <0.3s). Fix: `loop_end = int(get_length() * mix_rate)` (în CADRE). `Forest Ambient.wav` e 24-bit → Godot îl importă ca **QOA** (format=3), dar merge la fel.

**Pași pe biom (`player.gd`):** la fiecare pas, `BiomeMap.desertness_at_chunk(global_position/512) >= 0.5` → `footsteps_sand`, altfel `footsteps_grass`.

**Verificat (runtime):** ambient playing; în pădure (d=0) `ambient_level≈0.98` (volum -14dB, pas grass), în deșert (d=1) `≈0.02` (volum -47dB, pas sand). Fade lin între ele.

**De știut:** ambientul e pe slider-ul **SOUND FX** (nu Muzică) — ușor de mutat dacă vrea altfel.

## Session log — 2026-07-25 (Mike's Hedgehog: feedback vizual + unic + cooldown 6s)

**Cerut de Răzvan:** la block-ul lui Mike's Hedgehog să apară un efect (overlay alb pe player + text „Blocked"); itemul să fie unic (nu mai apară restul run-ului după ce-l iei); cooldown-ul de block 3s → 6s.

**Făcut:**
- **Cooldown:** `HEDGEHOG_CD = 6.0` în `player.gd` (era hardcodat 3.0 în bucla de contact-damage).
- **Unic:** adăugat `"unic": true` la intrarea hedgehog din `UPGRADES` (levelup.gd) + desc `once/3s`→`once/6s`. Mecanismul „unic" exista deja (`_e_disponibil`/`_luate_unic` din levelup.gd, ca Undying Spirit) — hedgehog e boolean, oricum nu se stack-uia.
- **Feedback vizual (`_show_block()` în player.gd, chemat pe block):**
  - Flash alb pe sprite: shader nou `white_flash.gdshader` (uniform `flash` amestecă spre alb, păstrează alpha), pus pe `anim.material` în `_ready` cu `flash=0`; pe block `flash` sare la 1 și se tween-uiește la 0 în 0.35s. Player-ul n-avea material (limbo aplică shader pe un overlay separat, nu pe player), deci fără conflict.
  - Text „Blocked" plutitor: metodă nouă `Fx.text_popup(pos, text, color, size)` (ca `damage_number`, dar text liber; fără contorul `_numere`).
- **Codex:** actualizat `eff` hedgehog (6s + „fulgeră alb + Blocked" + „Unic"). **Neapublicat** (doar la cererea lui Răzvan).

**Verificat (screenshot + runtime):** pe block, sprite-ul se albeşte (flash 1→0) și apare „BLOCKED" deasupra capului; shaderul se încarcă fără erori. `white_flash.gdshader` se încarcă prin cale (fără `.uid`).

## Session log — 2026-07-25 (proiectile pe Sabie & Stingător — burst stil Megabonk)

**Cerut de Răzvan:** proiectilele multiple să meargă și cu stingătorul și sabia; la sabie să atace „ca în Megabonk, un atac rapid după altul, și cu cât ai mai multe proiectile cu atât le dă mai repede"; la stingător la fel.

**Context:** proiectilele extra (`stacked_armory_stacks` de la Gunslinger/Twin Comets + Broken Watch pe șansă) făceau salve bonus DOAR în `_fire_bullets` (pistol/mage). Sabia (`_sword_swing`) și stingătorul (`_aura_pulse`) le ignorau.

**Soluție (`player.gd`):** un mic „burst runner" cu contor în `_physics_process` (`_tick_burst`), NU await (ca la Garda — dacă mori/schimbi scena la mijloc, nu rămâne un await agățat). `_fire()` pentru sword/extinguisher face primul atac imediat, apoi `_start_burst(kind)`:
- `_extra_attacks()` = aceeași socoteală ca la gloanțe (`stacked_armory_stacks` + Broken Watch pe șansă).
- `_burst_left = extra`; `_burst_gap = clampf(BURST_GAP0/extra, BURST_MIN, BURST_GAP0)` cu `BURST_GAP0=0.16`, `BURST_MIN=0.045` → **mai multe proiectile = pauză mai mică = atacuri mai rapide**.
- `_tick_burst` scade timpul și mai lansează câte un `_sword_swing()` / `_aura_pulse()` (funcțiile de UN atac, care NU repornesc burst-ul).

Gloanțele (pistol/mage) rămân neschimbate — trag salve paralele spre inamici diferiți, nu burst.

**Verificat (test runtime):** gap-ul scade cu numărul de proiectile (extra 1→0.160, 2→0.080, 4→0.045); burst-ul de sabie ȘI cel de stingător se scurg la 0 fără erori (toate atacurile extra se execută). Sincronizat și nota din `codex.html` (SYN „Ce nu ajunge la Stingător" → „Proiectilele merg acum pe Sabie & Stingător") — **artifactul NU a fost republicat** (publicare = acțiune spre exterior, doar la cererea lui Răzvan).

## Session log — 2026-07-25 (sound FX noi legate în joc)

Răzvan a pus 8 WAV-uri noi în `audio/`. Le-am înregistrat în `SFX` din `audio.gd` și legat la evenimente:
- `Choose Item Menu Open - Close.wav` → `"levelup"` (deja se cerea la level up, doar mapat).
- `When enemy hits player.wav` → `"hurt"` (deja se cerea când primești damage).
- `Extinguisher.wav` → `"extinguisher"`: în `player._aura_pulse` (înlocuit placeholder-ul `shoot -12`). **(Ajustare ulterioară:** mutat la ÎNCEPUTUL lui `_aura_pulse`, ca să sune la FIECARE pulsare, nu doar când prinde un inamic — cerut de Răzvan.)
- `Cursed Sword.wav` → `"sword"`: în `player._sword_swing` (înlocuit placeholder-ul `shoot -10`).
- `Garda Attack.wav` → `"garda_attack"`: în `garda._fire_lightning`.
- `Game Start.wav` → `"game_start"`: în `spawner._ready` (start de rundă).
- `Game Over.wav` → `"game_over"`: în `gameover.show_gameover`.
- `Footsteps.wav` → `"footsteps"`: `Footsteps.wav` e UN pas (~0.35s), deci în `player._physics_process` îl redau pe cadență (`STEP_GAP = 0.3s`) cât timp te miști, nu în buclă (fără bătăi de cap cu pauza/scene change; one-shot-urile respectă singure pauza și `sfx_volume`).

**Neacoperit (rezolvat pe 2026-07-25):** pistol/mage acum au sunet — `Bullet.mp3` mapat pe `"shoot"` în `audio.gd`, redat la -9dB în `player._fire_bullets` (se trage des → moderat, reglabil). MP3-ul e 1.34s; nu i-am putut măsura RMS ca la WAV-uri (comprimat) nici auzi — volumul e o estimare de reglat după ureche. „hit"/„enemy_die"/„xp" la fel (fără fișiere). Verificat: toate cele 9 sunete se încarcă (`_streams`), zero warning-uri „lipsește", zero erori. **WAV + `.otf/.import` commituite** (necesare la rulare standalone).

## Session log — 2026-07-25 (balans: șanse de raritate)

Răzvan a cerut `RARITY_CHANCE` din `levelup.gd` la **Common 40 · Uncommon 35 · Rare 15 · Epic 7.5 · Legendary 2.5** (era 30/30/20/15/5) — iteme bune mai rare. Sincronizat și `codex.html` (nota SYN „Raritatea chiar contează" + exemplul de noroc recalculat pe noua bază: 17.5 noroc → C 31.25 · U 26.25 · R 22 · E 14.5 · L 6). **Artifactul codex NErepublicat** (doar la cererea lui).

## Session log — 2026-07-25 (balans: Stolen Halo)

Răzvan a cerut Stolen Halo la **10 damage** (era 15). Schimbat în `levelup.gd`: efectul (`p.bullet_damage += 10`) + descrierea (`+10 Damage - +5 Max HP`). Sincronizat și `codex.html` (`eff:` → `+10 damage`) — doar text, structura codex-ului neatinsă. **Artifactul codex de pe claude.ai NU a fost republicat** (publicare = acțiune spre exterior, o fac doar când Răzvan zice explicit).

## Session log — 2026-07-25 (partea 3: font global + tot textul în engleză)

**Cerut de Răzvan:** „ți-am pus în folderul menu un font; vreau ca tot textul din joc să fie în ENGLEZĂ și cu fontul ăla."

**Fontul:** `menu/HomeVideo-Regular.otf` (font pixel — Godot dezactivează singur hinting/subpixel la import). L-am setat ca **font implicit al întregului UI** prin `project.godot`:
```
[gui]
theme/custom_font="res://menu/HomeVideo-Regular.otf"
```
Merge global fiindcă tot codul de UI suprascrie doar *mărimea* și *culoarea* fontului (`add_theme_font_size_override` / `font_color`), niciodată *familia* — deci fontul implicit se aplică peste tot (meniu, arme, Settings, pauză, HUD, Level Up + panoul STATS, Game Over, Limbo). Verificat pe screenshot: la Level Up cele 13 rânduri de STATS tot încap, descrierile stau pe un rând (fontul pixel e mai lat, dar layout-urile rezistă). **Fontul + `.otf.import` trebuie commituite** (fără `.import`, o rulare standalone dă „No loader found for resource" — declanșează importul cu `--headless --import`).

**Textul în engleză:** aproape tot era deja engleză. Singurele texte ROMÂNEȘTI de pe ecran (nu comentariile — alea rămân) erau:
- `settings_ui.gd`: MUZICĂ→**MUSIC**, EFECTE→**SOUND FX**, TASTE→**CONTROLS**, „apasă o tastă…"→**"press a key…"**
- `game_settings.gd` (etichetele din `MOVE_ACTIONS`): Sus/Jos/Stânga/Dreapta → **Up/Down/Left/Right**
- `menu.gd`: numele armei STINGĂTOR → **EXTINGUISHER**

Anunțurile de val, HUD, Level Up, Game Over, Limbo erau deja engleză (comentariul vechi din `hud.gd` cu „VALUL 3"/„BOSS!" e doar un exemplu învechit, nu cod). Mesajele de debug din consolă (`push_warning`/`print`) au rămas în română — nu se văd în joc.

**Ajustare (același font):** la HomeVideo, titlul „LEVEL UP! Choose:" din `levelup.gd` intra în rama de sus. Fix: `margin_top` al panoului din stânga 44→**66** (ca la panoul STATS), plus spațierea listei 12→**8** ca al treilea rând să nu ajungă în rama de jos. Verificat pe screenshot: titlul e sub chenar, cele 3 rânduri încap.

## Session log — 2026-07-25 (partea 2: meniu de pauză pe ESC + refactor Settings)

**Cerut de Răzvan:** „vreau să pot da ESC într-un run și acolo să scrie — Main Menu, Restart Run, Settings, Quit Game."

**Refactor întâi (ca să nu dublez Settings):** am scos blocul de setări (slidere volum + remapare taste) din `menu.gd` într-un component refolosibil **`settings_ui.gd`** (`class_name SettingsUI`, un `VBoxContainer` care-și prinde singur tasta în `_input` și expune `cancel_remap()`). `menu.gd` acum doar îl instanțiază în panoul „settings" (titlu + `SettingsUI` + BACK); am șters din `menu.gd` funcțiile `_volume_row/_key_row/_on_music_volume/_on_sfx_volume/_begin_remap/_cancel_remap` și blocul de remap din `_input`. Cel care pune componentul deasupra adaugă singur titlul + BACK.

**Meniul de pauză — `pause.gd`** (nod `Pause`, `CanvasLayer`, adăugat în `main.tscn`):
- `process_mode = ALWAYS`, `layer = 15` (peste HUD, sub Game Over 20). `_unhandled_input` prinde `ui_cancel` (ESC).
- Două pagini: **lista** (`PAUSED` + Main Menu / Restart Run / Settings / Quit Game, în ordinea cerută) și **Settings** (același `SettingsUI` + Back).
- ESC: închis→deschide (`paused=true`); pe Settings→urcă la listă; pe listă→reia jocul (`paused=false`). Nu se deschide peste Level Up / Game Over (`_blocked()` verifică grupurile `levelup_menu` / `gameover_screen`).
- Acțiuni: Main Menu = `change_scene_to_file("res://menu.tscn")`, Restart = `reload_current_scene()`, Quit = `get_tree().quit()` — toate cu `paused=false` întâi (ca în `gameover.gd`).
- ~~Nu am pus buton „Resume"~~ **(adăugat pe 2026-07-25 la cererea lui Răzvan):** buton `Resume` sus în listă (`_on_resume` → `_close_menu`). Se reia și cu ESC în continuare.

**Verificat (screenshot + runtime):** lista de pauză și pagina Settings din pauză se randează corect (peste jocul întunecat); meniul principal neschimbat după refactor; ESC testat cu evenimente reale (`Input.parse_input_event`): deschide+pauză → din Settings urcă la listă (rămâne pe pauză) → din listă reia jocul. Zero erori de script. Test-scenele temporare șterse.

## Session log — 2026-07-25 (pentru Windows: pagină Settings — sunet + taste remapabile)

**Cerut de Răzvan:** o potecă care apare DOAR în pădure (nu în deșert, nici pe gradientul unde deșertul se îmbină cu pădurea), mereu lată de 1 pathblock normal (verticală SAU orizontală), cu câte un tile de margine în stânga/dreapta ales dintre cele care se îmbină cu iarba, lungime random 4–20 tile-uri, ~1 la 5 chunk-uri. Arta pusă de el în `harta/pathblocks/` (5 tile-uri de 64×64).

**Cum funcționează numele tile-urilor (NEEVIDENT — verificat pe pixeli, nu pe nume):** `pathblock x grassblock <DIR>` = tile-ul care are jumătatea de PATH pe latura `<DIR>` (iarba pe opusul). Deci:
- vertical: coloana din STÂNGA (vest) = `east` (path pe E, iarbă pe V); DREAPTA (est) = `west`.
- orizontal: rândul de SUS (nord) = `south` (path pe S, iarbă pe N); JOS (sud) = `north`.
- `pathblock normal` = tot maro (centrul). Le-am dedus măsurând culorile colțurilor/marginilor cu un script; numele singur induce în eroare (pare invers).

**Implementare (`pathways.gd`, nod `Paths` sub `Main` în main.tscn):**
- Chunk-generat determinist, exact ca `props.gd` (load/unload în jurul player-ului). `rng.seed = hash(key) ^ 0x9E3779B9` (salt ca să nu se coreleze cu copacii).
- `spawn_chance = 0.2` (~1 la 5 chunk-uri), `min_len/max_len = 4/20`, orientare 50/50, `tile_px = 64` (= o celulă de iarbă, aliniat pe grila lumii).
- **Filtrul de pădure:** pentru FIECARE tile (centru + cele 2 margini × toată lungimea) verific `BiomeMap.desertness_at_chunk(centru_tile / chunk_size) <= 0.0`. Dacă vreunul atinge deșert SAU gradient (d > 0), renunț la toată poteca. Așa apare mereu doar în pădure curată, la lungimea cerută. `desertness` întoarce exact 0.0 pe iarbă pură (bucla nu-l atinge dacă nu-i deșert în rază), deci `<= 0.0` e sigur.
- **Strat:** tile-uri `Sprite2D` cu `z_index = -5`, `z_as_relative = false` → peste iarbă (Ground e la z=-10), sub umbrele copacilor (z=-1) și sub trunchiuri. NU e y-sortat (e podea plată), de-aia stă sub `Main` direct, nu în `World`.
- `load_radius = 4` (mai mare ca la copaci, fiindcă o potecă de 20 tile-uri se întinde pe ~2.5 chunk-uri de la origine → altfel dispărea la capăt).

**Verificat vizual (screenshot-uri):** poteci pe iarba reală (ambele orientări, marginile se îmbină cu iarba), player-ul pentru scară (~3 tile-uri lățime desenată vs player); și la **granița cu deșertul** — potecile se opresc cu o zonă-tampon curată înainte de nisip, ZERO poteci pe deșert/gradient. Jocul pornește curat.

**De reglat din Inspector** (nodul `Paths`): `spawn_chance`, `min_len`/`max_len`, `tile_px` (mărește dacă vrea poteca mai lată), `load_radius`.

**Ajustare 1 (tot 2026-07-23, după feedback):**
- „*Nu ai folosit toate direcțiile pentru blend*" — la v1 blenduiam doar lateralele; capetele erau tăiate brusc. Am pus capete cu tile-urile prefabricate, dar ieșea crenelură / capete evazate (dog-bone) fiindcă n-avem tile de colț.
- „*Se spawnează prea des*" — `spawn_chance` **0.2 → 0.1** (~1 la 10 chunk-uri).

**Ajustare 2 — blend rescris în Godot (cerut: „folosește doar `pathblock normal` și blenduiește tu din Godot; taie capetele ieșite"):**
- Acum poteca folosește **DOAR `pathblock normal`** peste tot (dreptunghi 3×`length`, toate la fel). Blend-ul îl face `path_blend.gdshader`: estompează alpha spre iarbă DOAR pe laturile EXPUSE ale fiecărui tile (cele fără vecin-potecă — decis din `tset`). Rezultat: se topește lin în iarbă pe toate 4 laturile ȘI la capete, **colțurile ies rotunjite** din `min`-ul celor două căderi de alpha — fără crenelură, fără capete ieșite, fără nevoie de tile de colț. Tile-urile prefabricate `pathblock x grassblock *` nu se mai folosesc (rămân în `harta/pathblocks/`, nefolosite).
- **Capcană rezolvată:** întâi trimiteam masca de laturi cu `set_instance_shader_parameter("fade", ...)`. La densitate mare crăpa cu „*Too many instances using shader instance variables. Increase buffer size...*" (limita de instance uniforms). **Fix:** codific masca în `self_modulate` (R=stânga, G=sus, B=dreapta, A=jos) și shaderul o citește din `COLOR` (culoarea vertexului n-are limită de instanțe). Verificat la densitate extremă (`spawn_chance=1`, `load_radius=8`): 0 erori.
- Reglaj nou: `edge_fade` (0..0.5) pe nodul `Paths` = cât de lat e blend-ul.

**Ajustare 3 — pixeli negri pe margine + capăt (feedback: „la final de pathblock nu e blend-uit și la margini nu vreau să văd pixelii ăia negri"):**
- `pathblock normal.png` are pixeli aproape negri împrăștiați (parte din textura de pământ: top 8 / bot 5 / left 7 / right 5 din 64). La alpha parțial peste iarbă ieșeau ca **puncte negre** pe margine — și făceau capătul să pară netăiat/neblenduit. (Capătul era de fapt blenduit — confirmat la zoom mare; problema erau punctele negre de acolo.)
- **Fix:** curăț textura O DATĂ la pornire (`_clean_texture` în pathways.gd): pixelii sub `dark_floor` (0.32 luminozitate) sunt ridicați păstrând nuanța (scalare RGB); **negrul PUR** (lum ≤ 0.04, unde n-ai ce nuanță scala) e înlocuit cu un maro-închis de pământ `(0.34,0.20,0.15)`. Rezultat: 0 pixeli negri, marginile se estompează cu maro de pământ, nu cu negru. Interiorul rămâne ok (se pierd doar cei mai negri stropi — subtil). Am scos și `darkcut`-ul din shader (nu mai e nevoie).
- **Capcană:** prima versiune de curățare sărea pixelii cu `lum > 0.0001` (gardă anti-împărțire-la-zero) — exact negrul pur rămânea. De-aia trebuie ramura separată pentru lum ≈ 0.
- Reglaj nou: `dark_floor` pe nodul `Paths`.

**Ajustare 4 — copaci pe potecă + poteci suprapuse (feedback cu poză adnotată: albastru = vreau și pe cealaltă parte, roșu = nu vreau umflătura în lateral, + „niciodată copaci pe path/blend"):**
- **Copaci pe potecă:** copacii (`props.gd`) și potecile se generau independent → un copac creștea fix pe potecă. Am refactorat `pathways.gd`: tile-urile unei poteci se calculează acum într-o funcție deterministă `_raw_path(key)` (cache-uită, fără noduri), iar nodul se pune în grupul `"paths"`. Am expus `is_on_path(world_pos, margin)` care recompune determinist potecile din chunk-urile din rază (`_reach`) și zice dacă un punct e pe potecă. În `props.gd`, înainte de a planta un copac, verific `_paths.is_on_path(me["pos"], path_clearance)` (marjă `path_clearance = 2` tile-uri) → niciun copac pe potecă sau pe blend-ul/coroana de lângă ea.
- **Umflăturile în lateral (roșu):** erau două poteci din chunk-uri diferite care se suprapuneau parțial → una ieșea în afara celeilalte. Acum fiecare potecă „cedează" (nu se desenează) dacă se apropie la ≤ `path_gap` (3 tile-uri) de o potecă dintr-un chunk vecin cu cheia MAI MICĂ (`_yields_to_neighbor`, departajare deterministă ca la spacing-ul copacilor). Rezultat: fiecare potecă e o bandă dreaptă, fără bucăți în lateral — asta rezolvă și albastrul (simetrie) și roșul (umflătura).
- `_reach` = câte chunk-uri poate acoperi o potecă (din `max_len`), folosit la ambele verificări. `is_on_path` folosește potecile BRUTE (inclusiv cele care au cedat) → copacii evită conservator; nesemnificativ.
- Reglaje noi: `path_gap` pe `Paths`, `path_clearance` pe `Props`.

**Ajustare 5 — blend-ul se estompa doar în sud/vest (feedback cu poză: „blendul e perfect doar în sud, vreau la fel în nord/est/vest"):**
- **Cauza (măsurată, nu ghicită):** masca de laturi o trimiteam prin `self_modulate = Color(R=stânga, G=sus, B=dreapta, A=jos)`, dar Godot livrează la shaderul 2D **fiabil doar canalele R și A** ale culorii vertexului — G și B se pierdeau. Deci se estompau doar stânga (R) și jos (A); sus (G) și dreapta (B) rămâneau tăiate brusc. Confirmat cu un test pe fundal magenta: mask individual pe fiecare canal → doar R și A funcționau.
- **Fix:** am scos `self_modulate`. Acum shaderul are `uniform vec4 fade` NORMAL, iar `pathways.gd` ține **câte un ShaderMaterial partajat per combinație de laturi** (`_mat_for(mask)`, mască pe biți 1/2/4/8). Sunt doar ~9 combinații → ~9 materiale, se grupează bine la desenat, fără limita de instanțe. Verificat: mask=15 (toate laturile) → toate 4 marginile se estompează (0.00), mijloc opac (0.75). Toate direcțiile arată acum la fel.
- `fade_w` (din `edge_fade`) se actualizează live pe toate materialele în `_process`.

---

## Session log — 2026-07-23 (copaci: 1.2× mai mari + hitbox uniform)

**Cerut de Răzvan:** „fă copacii cu 1.2× mai mari și vreau să aibă toți același hitbox."

**Ce am făcut în `props.gd`:**
1. **1.2× mai mari:** `tree_scale` **1.85 → 2.22** (1.85 × 1.2). ~258px pe ecran în loc de ~215.
2. **Hitbox identic la toți:** înainte `_hitbox_w(tex)` măsura trunchiul FIECĂRUI copac (`_trunk(tex).size.x`) → cutii de mărimi diferite (stejar gros vs mesteacăn subțire). Acum ignoră textura și pornește de la o valoare FIXĂ, `hitbox_trunk_px = 20.0` (px de textură) × `tree_scale` × `hitbox_factor` → aceeași lățime ȘI înălțime la toți. **Poziția rămâne per-copac** (`trunk_center_x` / `base_y`), deci fiecare cutie stă centrată pe trunchiul lui și pe rădăcină. Aceeași valoare intră și în `_min_dist` → spațierea dintre copaci devine uniformă.

**De reglat mai târziu:** dacă vrea cutia mai mare/mică, se schimbă un singur knob: `hitbox_trunk_px`. Restul knob-urilor (`hitbox_north/south/east/west`, `hitbox_vertical`, `hitbox_factor`) merg în continuare.

**Verificat:** randat toți 6 copacii la noua mărime desenând `CollisionShape2D`-ul REAL peste ei — cutiile ies identice ca mărime, fiecare pe baza trunchiului. Jocul pornește curat. `_trunk`/`TRUNK_BAND` rămân folosite doar pentru umbră și pentru centrarea cutiei, nu pentru mărimea ei.

---

## Session log — 2026-07-23 (copaci noi: import, hitbox, y-sort)

**Context:** Răzvan a înlocuit `harta/trees/Tree Variant 1..6.png` cu o serie nouă de copaci (nu-i plăceau cei vechi), a **șters Variant 7** complet și a șters toate fișierele `.import`. Cererea: „vezi ce poți face cu hitbox-ul, iar ca sprite să fie la fel ca ceilalți copaci de erau înainte" + reminder „player-ul în spatele copacilor când e la nord".

**Ce am făcut:**
1. **Crash evitat:** `props.gd` încă avea `preload("res://harta/trees/Tree Variant 7.png")` — l-am scos din array-ul `TREES` (acum 6). Fără asta, jocul crăpa la pornire.
2. **Reimport:** PNG-urile noi veniseră fără `.import` → `--headless --import` le-a regenerat (altfel `load()` la rulare directă dă „No loader found").
3. **Sprite = ca înainte:** măsurat, copacii noi sunt 128×128 cu ~112–121px înălțime vizibilă, **la fel ca seria precedentă** → `tree_scale` rămâne **1.85** (~215px pe ecran). N-a trebuit schimbat nimic la mărime.
4. **Hitbox reparat (miezul cererii):** detectorul de trunchi (`ground_shadow.gd`, `trunk_rect`) scana banda de jos **18%** din înălțimea vizibilă. La arta nouă, unii copaci (stejarul V2, tufele V5/V6) au frunziș care coboară în banda aia → detecta toată coroana drept „trunchi" și ieșea un hitbox **uriaș** (cutia stejarului acoperea toată jumătatea de jos). Am **micșorat banda la 8%** (`TRUNK_BAND` 0.18 → 0.08) — prinde doar baza reală care atinge solul. Lățimile de trunchi au trecut de la `10–75px` haotic la `10–37px` realist (trunchi gros la stejar, subțire la mesteacăn). Verificat cu screenshot-uri cu hitbox-ul desenat peste toți 6.
5. **Y-sort (player la nord) — verificat, neatins.** Lanțul `World→Props→container` toate `y_sort_enabled`, linia de sortare la 35.5% din trunchi, e independent de artă. Test în joc cu player + copac reali: player la nord de copac → complet acoperit de coroană; la sud → în față. `TRUNK_BAND` afectează DOAR hitbox-ul/umbra, nu sortarea.

**Neatins intenționat:** cactușii (`desert_structures.gd`) își fac hitbox-ul din lățimea canvasului (nu din banda de trunchi), deci reducerea benzii nu-i afectează — doar poziția umbrei se mișcă neglijabil. Verificat în cod.

**Capcană de reținut:** când Răzvan bagă/schimbă PNG-uri, ele vin fără `.import` → **întotdeauna** rulează `--headless --import` înainte de orice test, altfel rularea directă a jocului nu le poate încărca (vezi [[joc-bzn-run-verify]]).

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

**Cum s-a făcut:** `tool_contur.gd` (rămâne în repo, e sursa animației; se numea `tool_baton.gd` până pe 2026-07-26) — încarcă PNG-ul, îl rotește în **16 cadre × 22.5°** și scrie înapoi `frame0000…frame0015.png`. Rulare: `godot --headless --path <proj> res://tool_contur.tscn`.

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
