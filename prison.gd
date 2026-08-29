extends CanvasLayer

# CASTELUL — a patra dimensiune (până pe 2026-08-22 se numea PUȘCĂRIA, iar boss-ul ei era THE
# WARDEN; Răzvan a redenumit `harta/prison` în `harta/castle` și a adus înăuntru un cavaler).
# Făcut exact ca Nether-ul și Ender-ul (`nether.gd`, `ender.gd`): NU se încarcă altă scenă, rămâi
# în aceeași lume la aceleași coordonate, dar podeaua devine pământ de curte de castel, decorul se
# stinge, ceasul rundei îngheață și pornește unul propriu, iar inamicii lasă `XP_BONUS` × XP.
#
# ⚠️ NUMELE DIN COD au rămas „prison": fișierele (`prison.gd`, `prison_gates.gd`), grupul
# („prison"), funcțiile (`set_prison`) și nodul din `main.tscn`. Doar ARTA și TEXTELE de pe ecran
# s-au mutat la castel. Redenumirea a opt fișiere, a UID-urilor lor și a nodurilor din scene ar fi
# fost o schimbare mare, cu risc, pe care nimeni n-a cerut-o — iar `harta/castle/prison tileset.png`
# poartă și el amândouă numele, de la Răzvan.
#
# ⚠️ CUM AJUNGI AICI — SCHIMBAT pe 2026-08-18 (cerut de Răzvan: „nu vreau ca portalele să se
# spawneze după ce termini Ender, vreau să fie de la început random pe hartă cu 1% șansă per
# chunk"). Porțile au acum generator PROPRIU, `prison_gates.gd`, aprins din minutul zero al
# rundei; nu mai sunt a treia vârstă a locurilor din `portals.gd`.
# Deci castelul NU e închis până termini celelalte dimensiuni: poți intra oricând dai peste
# o poartă. Ce o ține grea rămâne ce e ÎNĂUNTRU — inamicii îngroșați (`ENEMY_POWER` & co.) și
# SIR JOHN cu 260 000 de viață, nescalată. Dacă intri devreme, intri nepregătit.
#
# ⚠️ TOT UNA PE RUNDĂ: la ieșirea victorioasă se oprește generatorul PORȚILOR
# (`prison_gates.opreste()`), nu cel de portaluri. Lanțul Nether → Ender merge mai departe,
# neatins, cu opririle lui.
#
# ⚠️ BOSS-UL TE AȘTEAPTĂ ACOLO — schimbat pe 2026-08-22, cerut de Răzvan („vreau să îi faci un
# intro ca la Celesto fără statuie de spawn — am șters-o"). Până atunci îl scoteai TU dintr-o
# statuie, ca pe Saratalin în Nether; statuia (`prison_statue.gd` + `.tscn`) nu mai există, iar
# SIR JOHN intră cu cinematică din clipa în care treci poarta, exact ca Celesto în Ender.
# Cât trăiește, poarta nu se deschide.

const BOSS := preload("res://final_boss.tscn")

# --- reglaje ---
const PRISON_TIME := 300.0      # 5:00 — mai scurt decât Ender-ul (6:00): e ultima, deci mai apăsată
const XP_BONUS := 4.0           # Nether 2, Ender 3, aici 4
# ⚠️ 8, nu 26 (2026-08-17, după ce Răzvan a jucat-o): la 26 mureai în prima secundă și nici nu
# apucai să pleci de lângă poartă. Nether-ul scoate 25, dar acolo inamicii au 50 HP și damage 1.0;
# aici sunt cei mai duri din joc, îngroșați. Valul e un „bun venit", nu execuția.
const BURST := 8                # câți inamici apar DEODATĂ la intrare
const BURST_RADIUS := 640.0
const FLASH := 0.45
# ⚠️ La INTRARE fulgerul e mult mai scurt, din exact motivul măsurat la Celesto pe 2026-08-17:
# cinematica începe în aceeași clipă, iar 0,45s de alb peste ea înseamnă că înghețul, benzile și
# primii pași ai cavalerului se petrec în spatele unui geam lăptos. La IEȘIRE rămâne cel lung.
const FLASH_CUT := 0.18
const CLOCK_SIZE := 64
const CLOCK_COLOR := Color(0.78, 0.80, 0.62)     # verzui-piatră, ca mucegaiul de pe pereți
const CLOCK_WARN := Color(1.0, 0.82, 0.20)
const CLOCK_SWARM := Color(1.0, 0.10, 0.10)
const COMPASS_MARGIN := 96.0
const TELEPORT_DB := -4.0
# Unde te așteaptă SIR JOHN: un INEL în jurul porții, ca Celesto în jurul fântânii. Nu-ți cade în
# brațe la aterizare, dar nici nu-l cauți o zi — busola te duce la el din prima secundă.
# ⚠️ Mai aproape decât inelul lui Celesto (700–1100), fiindcă aici e și punctul spre care zboară
# CAMERA în cinematică: la 1100 px, călătoria camerei ar fi durat mai mult decât filmulețul.
const BOSS_MIN_DIST := 620.0
const BOSS_MAX_DIST := 900.0
const SHAKE_STRENGTH := 24.0
const SHAKE_TIME := 0.9

# ⚠️ Aceeași listă ca în `nether.gd` / `ender.gd` / `limbo.gd`. Un generator nou pus în `World`
# (main.tscn) trebuie trecut în TOATE. Dacă lipsește dintr-una, rămâne aprins acolo și-i vezi
# obiectele într-o dimensiune în care n-au ce căuta (s-a întâmplat de trei ori).
const WORLD_NODES := ["Props", "Rocks", "Bushes", "DesertStructures", "Statues", "Portals", "PrisonGates", "Chests", "EGTs", "Monuments", "AlbaNeagras", "Dubiosi"]
const ROOT_NODES := ["Paths"]

var active := false

# Cât de îngroșat e inamicul de aici. Îl citește `spawner.gd` și îl pune pe `enemy.gd::power_mult`
# ÎNAINTE de `add_child` (acolo se coace viața), plus un plus de viteză.
#
# ⚠️ De pe 2026-08-29 castelul are UN SINGUR fel de inamic, CAVALERUL (`enemy_cavaler.tscn`) —
# lista veche cu toate felurile din joc a dispărut din `spawner.gd`. Multiplicatorii de mai jos
# se aplică peste cifrele LUI, nu peste o medie de șase feluri.
#
# ⚠️ CIFRELE ASTEA AU FOST TĂIATE pe 2026-08-17, după ce Răzvan a jucat-o: „se buguiește,
# monstrul nu apare și mă bagă random în Limbo". Nu era un bug — MUREA în prima secundă și nu mai
# apuca să găsească statuia. Erau 3.0 / 1.25 / 1.6.
#
# 🔑 Ce l-a omorât e DAMAGE-UL, nu viața. Damage-ul de contact se plătește PER INAMIC LIPIT DE
# TINE, la fiecare 0,5 s (`player._take_contact_damage`), și se înmulțește deja de două ori:
# o dată cu `damage_mult` al felului (cavalerul are 1.4) și o dată cu
# `Difficulty.enemy_damage_mult()`, care la minutul la care ajungi în castel e ~×2,5. Un al
# treilea multiplicator de la mine peste ele înmulțea, nu aduna: 5 × 2,5 × 2,0 × 1,6 = 40 de damage
# per creatură, la fiecare jumătate de secundă. Cu cinci pe tine, 400/s dintr-o viață de ~150.
#
# Deci „mai OP" înseamnă acum: mai GRAȘI (îi tai mai greu) și puțin mai iuți — dar damage-ul îl
# lăsăm în pace, fiindcă el e cel care se înmulțește cu numărul lor.
# ⚠️ 1.25, nu 3.0 cum era la prima scriere. Viața în plus e cea care te omoară INDIRECT: la
# minutul 8 inamicii au deja ×16,3 din dificultate, iar dacă nu-i mai poți curăța se adună pe
# tine, iar damage-ul de contact se plătește per inamic.
#
# ⚠️ Îngroșarea adevărată a castelului n-a fost niciodată multiplicatorul ăsta. Până pe 2026-08-29
# era FAPTUL CĂ VENEAU TOATE FELURILE DEODATĂ; acum e CAVALERUL însuși — 160 HP de bază (mai mult
# decât SWAT-ul, 150) și damage 1.4, adică aproape media amestecului vechi (1,43). Dacă vreodată
# castelul iese prea moale, cifra care trebuie mișcată e a LUI, în `enemy_cavaler.tscn`, nu asta.
const ENEMY_POWER := 1.25       # de câte ori mai multă viață
const ENEMY_SPEED := 1.10       # de câte ori mai iuți
const ENEMY_DAMAGE := 1.0       # NU-l urca fără să măsori întâi cât încasezi pe secundă

# 🔑 CÂT DE DEASĂ E PLOAIA. Ăsta e butonul care chiar a salvat dimensiunea, și merită explicat.
# Ca să ajungi în pușcărie trebuie să treci prin Nether ȘI Ender, adică ajungi târziu în rundă —
# măsurat la 8:00: `Difficulty.spawn_mult()` e **6,48**, iar viața inamicilor ×16,3. Cu atâția pe
# secundă și cu ei îngroșați pe deasupra, nu-i mai poți curăța, se adună pe tine, iar damage-ul de
# contact se plătește PER INAMIC — 109 damage/secundă măsurat, adică 1,4 secunde de viață.
#
# Deci problema nu era „cât de tare lovește unul", ci CÂȚI ajung pe tine. Aici e o luptă cu boss,
# nu o hoardă: gloata trebuie să fie fundal, nu execuție. Îl citește `spawner.gd::rata_curenta()`.
const SPAWN_MULT := 0.35

var _flash: ColorRect
var _clock: Label
var _arrow: Label
var _dist: Label
var _player: Node2D = null
var _poarta: Node2D = null      # poarta prin care ai intrat; tot ea e ieșirea
var _banda_sus: ColorRect
var _banda_jos: ColorRect
var _vinieta: TextureRect
var _boss: Node2D = null
var _elapsed := 0.0
var _entry_diff_time := 0.0
var _swarm_announced := false
var _boss_invins := false
var _suspendat := false

# PUBLIC și NU se stinge la ieșire: „l-ai bătut pe Sir John măcar o dată în runda asta". Sora lui
# `nether.gd::escaped` și `ender.gd::celesto_invins`. Deocamdată nu-l citește nimeni — e cârligul
# pentru „inamicii castelului apar și în lumea normală", dacă se cere vreodată.
var sir_john_invins := false

func _ready() -> void:
	add_to_group("prison")
	layer = 4

	# Cadrul cinematicii de intrare. Făcut o dată, aici, și ținut ascuns tot restul jocului — se
	# aprinde numai în `_cutscene_sir_john`. Vinieta ÎNAINTEA benzilor, ca benzile să rămână deasupra
	# ei (altfel marginile de sus și de jos ar fi ieșit cenușii, nu negre).
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	_flash.visible = false
	add_child(_flash)

	_vinieta = _fa_vinieta()
	_banda_sus = _fa_banda(true)
	_banda_jos = _fa_banda(false)

	_clock = Label.new()
	_clock.anchor_left = 0.0
	_clock.anchor_right = 1.0
	_clock.offset_top = 8
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", CLOCK_SIZE)
	_clock.add_theme_color_override("font_color", CLOCK_COLOR)
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_clock.add_theme_constant_override("outline_size", 9)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.visible = false
	add_child(_clock)

	_arrow = Label.new()
	_arrow.text = "▲"
	_arrow.custom_minimum_size = Vector2(56, 56)
	_arrow.size = Vector2(56, 56)
	_arrow.pivot_offset = Vector2(28, 28)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arrow.add_theme_font_size_override("font_size", 40)
	_arrow.add_theme_color_override("font_color", CLOCK_COLOR)
	_arrow.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_arrow.add_theme_constant_override("outline_size", 7)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	add_child(_arrow)

	_dist = Label.new()
	_dist.custom_minimum_size = Vector2(160, 0)
	_dist.size = Vector2(160, 0)
	_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dist.add_theme_font_size_override("font_size", 22)
	_dist.add_theme_color_override("font_color", CLOCK_COLOR)
	_dist.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_dist.add_theme_constant_override("outline_size", 6)
	_dist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dist.visible = false
	add_child(_dist)

# ---------- INTRARE ----------
# Chemată din `portal_ender.gd` când apeși E pe o poartă de pușcărie. Primim NODUL porții:
# cât ești dincolo, el devine ieșirea (exact ca fântâna în Ender).
func enter(player: Node2D, poarta: Node2D) -> void:
	if active or player == null or player.dead or poarta == null:
		return
	for g in ["limbo", "nether", "ender"]:
		var alta := get_tree().get_first_node_in_group(g)
		if alta != null and alta.active:
			return
	active = true
	_player = player
	_poarta = poarta
	# O scoatem din generator și o mutăm în `World`: peste două rânduri golim decorul, iar
	# golirea ar șterge tot ce ține de generatoare — adică ne-ar lua chiar ieșirea de sub picioare.
	var world := player.get_parent()
	if world != null and _poarta.get_parent() != world:
		_poarta.reparent(world)
	_poarta.retur = true
	_elapsed = 0.0
	_entry_diff_time = Difficulty.time
	_swarm_announced = false
	_boss_invins = false
	_boss = null

	_clear_enemies()
	_set_world_enabled(false)
	_set_ground_prison(true)
	_margine(true)
	_set_atmosphere("prison")

	Difficulty.frozen = true
	Difficulty.mult_time_override = _diff_time()
	Difficulty.xp_bonus = XP_BONUS

	Audio.stop_forest_ambient()
	Audio.play("teleport", TELEPORT_DB, 0.0)
	Audio.play_prison_music()     # n-avem muzică proprie; împrumutăm bucla Nether-ului (`sky-lines`)
	_clock.text = _mmss(PRISON_TIME)
	_clock.add_theme_color_override("font_color", CLOCK_COLOR)
	_clock.visible = true
	_flash_screen(FLASH_CUT)   # scurt: peste el începe imediat cinematica (vezi FLASH_CUT)

	# ⚠️ Anunțul „THE CASTLE" și primul val de inamici NU se dau aici, ci la capătul cinematicii
	# (`_cutscene_gata`). Un banner peste filmuleț și opt inamici care se nasc cât jocul e înghețat
	# ar fi însemnat că, în clipa în care se dă drumul, ești deja înconjurat fără să fi văzut nimic.
	_cutscene_sir_john()

# ---------- IEȘIRE ----------
# `anunt = true`  → ieșire VOLUNTARĂ, apăsând E pe poartă.
# `anunt = false` → forțată: ai murit. Aia trece mereu, altfel ai rămâne blocat mort într-o
#                   dimensiune fără decor.
func exit_prison(anunt: bool = true) -> void:
	if not active:
		return
	if _suspendat:
		reia()
	if anunt and not _boss_invins:
		if _boss == null or not is_instance_valid(_boss):
			_anunta("THE GATE IS SEALED", "The knight is still on his feet")
		else:
			_anunta("SIR JOHN STILL STANDS", "The gate will not open until he falls")
		Audio.play("levelup", -6.0)
		return
	active = false
	_clear_enemies()
	_set_world_enabled(true)
	_set_ground_prison(false)
	_margine(false)
	_set_atmosphere("")
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0
	Difficulty.xp_bonus = 1.0
	_free_boss()

	if _poarta != null and is_instance_valid(_poarta):
		_poarta.retur = false
	_clock.visible = false
	_arrow.visible = false
	_dist.visible = false
	Audio.play_forest_ambient()
	Audio.restore_world_music()
	if anunt:
		Audio.play("teleport", TELEPORT_DB, 0.0)
		_flash_screen()
		_anunta("BACK", "Nothing is left to open")
		_inchide_poarta()

# ⚠️ `_cut_activ`: cât ține cinematica de intrare, ceasul castelului NU curge. Altfel ai pierde
# din cele 5 minute uitându-te la un filmuleț (aceeași regulă ca la Ender).
func _process(delta: float) -> void:
	if not active or _suspendat or _cut_activ:
		return
	if _player == null or not is_instance_valid(_player) or _player.dead:
		exit_prison(false)
		return
	_elapsed += delta
	Difficulty.mult_time_override = _diff_time()
	_update_clock()
	_update_compass()
	if not _swarm_announced and _elapsed >= PRISON_TIME:
		_swarm_announced = true
		_anunta("CASTLE SWARM", "The gate still works. For now.")
		Audio.play("levelup", -2.0)

# Chemată de `final_boss.gd` când moare: de aici încolo poarta te lasă să pleci.
func boss_invins() -> void:
	if not active or _boss_invins:
		return
	_boss_invins = true
	sir_john_invins = true
	_anunta("SIR JOHN FALLS", "Press E at the gate to go back")
	Audio.play("levelup", -2.0)

# ---------- PAUZĂ CÂT EȘTI ÎN LIMBO ----------
# Identic cu `ender.gd::suspenda()` — citește comentariul lung de acolo.
func suspenda() -> void:
	if not active or _suspendat:
		return
	_suspendat = true
	_set_ground_prison(false)
	_margine(false)
	_set_atmosphere("")
	Difficulty.xp_bonus = 1.0
	_clock.visible = false
	_arrow.visible = false
	_dist.visible = false
	_arata_obiect(_poarta, false)

	_park_boss(true)
	_bara_boss(false)

func reia() -> void:
	if not _suspendat:
		return
	_suspendat = false
	_set_ground_prison(true)
	_margine(true)
	_set_atmosphere("prison")
	Difficulty.frozen = true
	Difficulty.mult_time_override = _diff_time()
	Difficulty.xp_bonus = XP_BONUS
	_clock.visible = true
	_update_clock()
	_arata_obiect(_poarta, true)

	_park_boss(false)
	_bara_boss(true)

# ⚠️ Parametrul e NETIPIZAT dinadins.
# O referință poate rămâne MOARTĂ (statuia făcea asta) — iar dacă parametrul e `Node2D`, Godot crapă la APEL
# („The Object-derived class of argument 1 (previously freed)…"), înainte să apuce `_ready`-ul
# funcției să verifice `is_instance_valid`. Prins rulând: crăpa la întoarcerea din Limbo.
func _arata_obiect(n, on: bool) -> void:
	if n == null or not is_instance_valid(n):
		return
	n.visible = on
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

# Boss-ul, cât ești în Limbo. Îl scoatem din grupul „enemy" fiindcă exact ăla e grupul pe care îl
# mătură `limbo.gd::_clear_enemies()` — fără asta, un Warden adus la jumătate de viață ar dispărea
# și poarta n-ar mai avea cum să se deschidă vreodată.
func _park_boss(parcat: bool) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if parcat:
		_boss.remove_from_group("enemy")
	else:
		_boss.add_to_group("enemy")
	_arata_obiect(_boss, not parcat)

func _bara_boss(on: bool) -> void:
	var bara := get_tree().get_first_node_in_group("boss_bar")
	if bara == null:
		return
	if not on or _boss == null or not is_instance_valid(_boss):
		if bara.has_method("ascunde"):
			bara.ascunde()
		return
	if bara.has_method("arata"):
		bara.arata(_boss.nume, _boss.max_hp)
		bara.set_hp(_boss.hp)

# Ai ieșit învingător → GATA CU PORȚILE în runda asta. Cea prin care ai ieșit intră în pământ cu
# cutremur, celelalte de pe hartă dispar odată cu generatorul lor.
# ⚠️ Se oprește `PrisonGates`, NU `Portals` (schimbat pe 2026-08-18, odată cu generatorul propriu):
# portalurile Nether / fântânile Ender sunt o poveste separată acum și se opresc singure, la
# ieșirea din Ender. Dacă oprim greșitul, rămâi cu porți de pușcărie și fără portaluri.
func _inchide_poarta() -> void:
	var porti := _generator("PrisonGates")
	if porti != null and porti.has_method("opreste"):
		porti.opreste()
	if _poarta == null or not is_instance_valid(_poarta):
		return
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)
	_zguduie_camera()
	if _poarta.has_method("intra_in_pamant"):
		_poarta.intra_in_pamant()
	_poarta = null

# ---------- CINEMATICA DE INTRARE ----------
# Cerută de Răzvan pe 2026-08-22: „vreau să îi faci un intro ca la Celesto fără statuie de spawn".
#
# E construită pe ACELAȘI schelet ca `ender.gd::_cutscene_celesto` — îngheț adevărat, benzi +
# vinietă, muzica dată la o parte, camera cu UN SINGUR scriitor, tween-uri care merg pe pauză. Ce
# se întâmplă ÎNĂUNTRUL cadrului e însă altceva, și dinadins: Celesto e o fantomă care se
# teleportează, Sir John e un om în armură. Un cavaler care clipește stânga-dreapta n-ar fi „ca la
# Celesto", ar fi Celesto cu altă poză.
#
# Cele patru bătăi (secundele sunt de la începutul cinematicii):
#   0:00  ÎNGHEAȚĂ TIMPUL. Bubuitură joasă + bas, muzica coboară 16 dB, benzile intră, marginile se
#         întunecă, camera primește un pumn scurt și pleacă spre locul în care te așteaptă EL,
#         strângând zoom-ul dincolo de unde trebuie (1,86) și așezându-se apoi pe 1,70. Pe dedesubt
#         urcă un riser. Bara lui coboară de sus în paralel, de la 0:00.
#   0:30  PAȘII. Cinci, spre tine, fiecare mutându-l cu `CUT_PAS_PX` și schimbându-i cadrul de mers
#         cu mâna — nu lăsăm animația să curgă, fiindcă un mers lin peste o lume înghețată arată ca
#         o înregistrare pusă greșit pe pauză. Fiecare pas are un bocanc în boxa în care calcă și o
#         zguduitură de cameră.
#         ⚠️ RITMUL E CONSTANT, nu se strânge ca la Celesto. Acolo, patru teleportări tot mai dese
#         se citesc ca o acumulare; aici, un om în platoșă care ACCELEREAZĂ se citește ca un om
#         care fuge. Ce crește e GREUTATEA: bocancii urcă -12 → -3 dB și zguduitura 4 → 11 px, deci
#         pasul următor e mereu mai aproape, fără ca el să se grăbească. Inevitabil, nu grăbit.
#   1:40  Bara aterizează cu numele — un CLIC METALIC exact pe cadrul în care se oprește. Sunetul e
#         ales pentru el: la Celesto era un ton, aici e tablă pe tablă.
#   2:00  Ultimul pas cade, se întoarce cu fața la tine și urmează 0,40 s de LINIȘTE, cu camera
#         strângându-se încă 5%. Cel mai ieftin efect din meserie și cel mai puternic.
#   2:40  LOVITURA DE SABIE: înfige sabia în pământ, pleacă din el UNDA (chiar arta atacului lui,
#         `atac_inel`, dar fără damage), bubuit + bas, 26 px de zguduitură. Benzile ies, camera se
#         întoarce la tine, muzica urcă în 1,4 s, jocul repornește — și el rămâne acolo, la
#         `_loc_boss()`, unde tocmai l-ai văzut oprindu-se. NU dispare: un cavaler care te provoacă
#         și apoi se evaporă și-ar strica singur intrarea.
#
# ⚠️ CAMERA MERGE LA EL, NU EL LA TINE. Asta rezolvă singura problemă adevărată a ideii: în Ender,
# Celesto se materializează lângă tine și la final se teleportează departe, în inelul lui. Un om
# care merge nu poate face asta. Deci filmăm de la bun început LOCUL în care va rămâne (620–900 px
# de poartă), iar la sfârșit camera se întoarce la tine. Nimeni nu se teleportează, iar lupta
# începe la o distanță la care mai apuci să respiri.
#
# ⚠️ Pauza e ADEVĂRATĂ (`get_tree().paused`), cu aceleași trei precauții ca la Celesto:
#   • ne punem NOI pe `PROCESS_MODE_ALWAYS`, altfel tween-urile create aici ar sta și ele;
#   • `Fx` e autoload ALWAYS (numerele de damage) → îl trecem pe „pauzabil" cât ține treaba;
#   • `position_smoothing` al camerei se face în procesarea ei internă, care NU merge pe pauză.
# Și boss-ul primește ALWAYS, ca unda lui de la final să nu rămână înghețată la mărimea de start.
#
# `_cut_activ` ține `_process`-ul nostru mut: ceasul castelului NU trebuie să curgă cât te uiți.
const CUT_PASI := 5           # câți pași face spre tine
const CUT_PAS_PX := 26.0      # cât înaintează la fiecare
const CUT_PAS_T := 0.34       # cât durează unul (CONSTANT — vezi mai sus)
const CUT_PAS_CADRE := 2      # cu câte cadre de mers avansează la fiecare pas
const CUT_PANA_LA_PASI := 0.30
const CUT_BARA := 1.40        # cât coboară bara; pornește la 0:00
const CUT_LINISTE := 0.40     # liniștea dinaintea loviturii
const CUT_DUPA_PASI := 0.10   # o clipă între ultimul pas și liniște, cât se întoarce spre tine
# ⚠️ 1.70, nu 2.0 ca la Celesto: Sir John e desenat la `scale = 2.9`, adică ~177 px pe ecran. La
# zoom 2 ar fi ocupat mai mult de jumătate din înălțimea cadrului și n-ar mai fi avut pe unde să
# meargă cei cinci pași. La 1,70 rămâne uriaș, dar are cadru în jurul lui.
const CUT_ZOOM := 1.70
const CUT_ZOOM_PESTE := 1.86  # cât DEPĂȘEȘTE la intrare (smucitură de cameraman, nu macara)
const CUT_ZOOM_IN := 0.55
const CUT_ZOOM_ASEZA := 0.35
const CUT_ZOOM_STRANS := 1.79 # cât se mai strânge, lent, în liniștea de la final
const CUT_ZOOM_OUT := 0.60
# --- cadrul cinematic ---
const CUT_BENZI := 0.35
const CUT_BENZI_H := 0.085
const CUT_VINIETA := 0.80
# --- mixul, într-un singur loc ---
# Fișierele sunt normalizate la vârf -1 dBFS (vezi `audio.gd`), deci echilibrul e AICI. Aceeași
# scară ca la cinematica lui Celesto: lovitura cea mai tare stă cu ~4 dB peste un sunet obișnuit de
# joc și cu ~12 dB sub cutremur (`Audio.QUAKE_DB`), care rămâne cel mai tare lucru din joc.
const CUT_DB_FREEZE := -3.0
const CUT_DB_SUB := -6.0
const CUT_DB_RISER := -8.0
const CUT_DB_NUME := -5.0
const CUT_DB_PAS := [-12.0, -10.0, -8.0, -5.5, -3.0]   # bocancii, tot mai aproape
const CUT_PAS_SHAKE := [4.0, 5.5, 7.0, 9.0, 11.0]      # ...și camera, tot mai lovită
const CUT_DB_SLAM := 0.0      # cel mai tare din toată cinematica
const CUT_DB_SUB_FINAL := -2.0
const CUT_DUCK := -16.0
const CUT_UNDA_RAZA := 330.0  # cât de mare e unda de la final (doar desen, fără damage)

var _cut_activ := false

func _cutscene_sir_john() -> void:
	# Dacă nu se poate face filmulețul, sărim la capătul lui — altfel ai rămâne într-un castel fără
	# boss, fără anunț și fără inamici.
	if _player == null or _poarta == null:
		_cutscene_gata()
		return
	var world := _player.get_parent()
	if world == null:
		_cutscene_gata()
		return
	_boss = BOSS.instantiate()
	_boss.adoarme()          # ÎNAINTE de add_child: `_ready` nu mai cere bara și nu se mișcă
	world.add_child(_boss)
	_boss.process_mode = Node.PROCESS_MODE_ALWAYS

	# `centru` e ȘI ținta camerei, ȘI locul în care rămâne el după cinematică. Pornește cu cinci
	# pași mai departe de tine, pe aceeași linie, și vine încoace.
	var centru := _loc_boss()
	var spre_tine := (_player.global_position - centru).normalized()
	if spre_tine.length() < 0.001:
		spre_tine = Vector2.DOWN
	_boss.global_position = centru - spre_tine * (CUT_PAS_PX * float(CUT_PASI))
	if _boss.has_method("ingheata_spre"):
		_boss.ingheata_spre(_boss.directie_spre(_player.global_position), 0)

	# --- îngheț total ---
	_cut_activ = true
	var mod_vechi := process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var fx_vechi := Fx.process_mode
	Fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	if _player.fire_timer != null:
		_player.fire_timer.stop()
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	var zoom_vechi := Vector2.ONE
	var offset_vechi := Vector2.ZERO
	var neted_vechi := false
	if cam != null:
		zoom_vechi = cam.zoom
		offset_vechi = cam.offset
		neted_vechi = cam.position_smoothing_enabled
		cam.position_smoothing_enabled = false
	_cut_cam = cam
	_cut_baza = offset_vechi
	_cut_shake = Vector2.ZERO

	# --- 0) LOVITURA DE TIMP ---
	_cinema_intra(CUT_BENZI)
	Audio.duck_music(CUT_DUCK, 0.25)
	Audio.play_ex("sirjohn_freeze", CUT_DB_FREEZE)
	Audio.play_ex("sirjohn_sub", CUT_DB_SUB)
	# Riser-ul e tăiat cât ține apropierea camerei plus primii pași: se termină pe clicul barei.
	Audio.play_ex("sirjohn_riser", CUT_DB_RISER)
	_cut_zguduie(14.0, 0.28)

	var bara := get_tree().get_first_node_in_group("boss_bar")
	if bara != null and bara.has_method("arata_cinematic"):
		bara.arata_cinematic(_boss.nume, _boss.max_hp, CUT_BARA)
	# Zoom-ul are tween-ul LUI: două bătăi una după alta (depășește, apoi se așază). Nu se calcă cu
	# cel de jos, fiindcă lucrează pe proprietăți diferite.
	if cam != null:
		var tz := _cut_tween()
		tz.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM_PESTE, CUT_ZOOM_IN) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tz.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM, CUT_ZOOM_ASEZA) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var t := _cut_tween()
	t.set_parallel(true)
	# ⚠️ Bătaia de bază, care ține tween-ul viu chiar dacă n-ar exista camera: un `Tween` fără nicio
	# comandă se anulează singur și nu-și mai trimite `finished` — adică `await`-ul de mai jos ar
	# aștepta la nesfârșit, cu jocul înghețat.
	t.tween_interval(CUT_PANA_LA_PASI)
	if cam != null:
		t.tween_method(_cut_pune_baza, offset_vechi, centru - _player.global_position, CUT_ZOOM_IN) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished

	# --- 1) PAȘII ---
	# Bara coboară în paralel (a pornit la 0:00) și aterizează în timpul lor: clicul metalic cade pe
	# cadrul ei, nu „pe undeva pe acolo", de aia îi cronometrăm secunda separat.
	var bara_ramas := maxf(CUT_BARA - CUT_PANA_LA_PASI, 0.0)
	var scurs := 0.0
	var clic_dat := false
	for i in CUT_PASI:
		if is_instance_valid(_boss):
			_boss.global_position += spre_tine * CUT_PAS_PX
			if _boss.has_method("ingheata_spre"):
				# cadrul următor din mers, pus cu mâna: bocancul cade exact pe sunet
				_boss.ingheata_spre(_boss.directie_spre(_player.global_position), (i + 1) * CUT_PAS_CADRE)
			# Bocancul se aude din PARTEA în care calcă (`play_pan` cere fișier mono) și coboară un
			# sfert de ton la fiecare pas: mai jos = mai greu = mai aproape.
			Audio.play_pan("sirjohn_step", _boss.global_position, float(CUT_DB_PAS[i]), 1.0 - 0.03 * float(i))
			_cut_zguduie(float(CUT_PAS_SHAKE[i]), 0.16)
		await _cut_asteapta(CUT_PAS_T)
		scurs += CUT_PAS_T
		if not clic_dat and scurs >= bara_ramas:
			clic_dat = true
			Audio.play_ex("sirjohn_name", CUT_DB_NUME)
	if not clic_dat:
		Audio.play_ex("sirjohn_name", CUT_DB_NUME)

	# --- 2) SE ÎNTOARCE CU FAȚA LA TINE, apoi LINIȘTE ---
	if is_instance_valid(_boss) and _boss.has_method("ingheata_spre"):
		_boss.ingheata_spre(_boss.directie_spre(_player.global_position), 0)
	await _cut_asteapta(CUT_DUPA_PASI)
	if cam != null:
		var tl := _cut_tween()
		tl.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM_STRANS, CUT_LINISTE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _cut_asteapta(CUT_LINISTE)

	# --- 3) LOVITURA DE SABIE ---
	Audio.play_ex("sirjohn_slam", CUT_DB_SLAM)
	Audio.play_ex("sirjohn_sub", CUT_DB_SUB_FINAL)
	if is_instance_valid(_boss) and _boss.has_method("unda_de_spectacol"):
		_boss.unda_de_spectacol(CUT_UNDA_RAZA)
	_cut_zguduie(26.0, 0.5)
	_cinema_iese(CUT_BENZI)
	Audio.unduck_music(1.4)   # lumea își revine mai lent decât a fost dată la o parte
	if cam != null:
		var t2 := _cut_tween()
		t2.set_parallel(true)
		t2.tween_method(_cut_pune_baza, _cut_baza, offset_vechi, CUT_ZOOM_OUT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t2.tween_property(cam, "zoom", zoom_vechi, CUT_ZOOM_OUT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await t2.finished
		cam.position_smoothing_enabled = neted_vechi
	# Camera înapoi exact unde era: zguduitura are tween-ul ei, care ar putea fi încă în aer.
	_cut_shake = Vector2.ZERO
	_cut_baza = offset_vechi
	_cut_aplica()
	_cut_cam = null

	Fx.process_mode = fx_vechi
	if _player != null and is_instance_valid(_player) and _player.fire_timer != null:
		_player.fire_timer.start()
	get_tree().paused = false
	process_mode = mod_vechi
	_cut_activ = false
	_cutscene_gata()

# Ultima bătaie: de aici încolo totul e ca înainte — busola arată spre el, inamicii curg, lupta e a
# ta. `trezeste()` îi dă bara și îl pornește.
func _cutscene_gata() -> void:
	if not active:
		return
	if _boss != null and is_instance_valid(_boss):
		_boss.process_mode = Node.PROCESS_MODE_INHERIT   # înapoi sub pauza normală a jocului
		_boss.trezeste()
	_anunta("THE CASTLE", "Sir John will not let you leave")
	for i in BURST:
		_spawn_one()

# Tween care merge CU JOCUL PE PAUZĂ (suntem ALWAYS cât ține cinematica).
func _cut_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

# Pauză care curge pe pauză. `create_timer` are `process_always = true` implicit, dar aici se vede
# intenția — dacă vreodată devine `false`, cinematica ar rămâne blocată CU JOCUL ÎNGHEȚAT.
func _cut_asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde, true).timeout

# ---------- camera cinematicii ----------
# ⚠️ TOT ce mișcă `cam.offset` în cinematică trece pe aici. Peste încadrare (camera care pleacă spre
# el și se întoarce) se suprapun zguduiturile de la fiecare pas, iar două tween-uri pe ACEEAȘI
# proprietate se anulează unul pe altul — câștigă cel creat ultimul. Două variabile separate,
# adunate într-un singur loc, se pot întâmpla în același timp fără să se calce.
var _cut_cam: Camera2D = null
var _cut_baza := Vector2.ZERO
var _cut_shake := Vector2.ZERO

func _cut_aplica() -> void:
	if _cut_cam != null and is_instance_valid(_cut_cam):
		_cut_cam.offset = _cut_baza + _cut_shake

func _cut_pune_baza(v: Vector2) -> void:
	_cut_baza = v
	_cut_aplica()

func _cut_pune_shake(putere: float) -> void:
	_cut_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * putere
	_cut_aplica()

func _cut_zguduie(putere: float, durata: float) -> void:
	var tw := _cut_tween()
	tw.tween_method(_cut_pune_shake, putere, 0.0, durata)
	tw.tween_callback(func(): _cut_shake = Vector2.ZERO; _cut_aplica())

# ---------- cadrul cinematic (benzile + vinieta) ----------
# Sunt pe stratul castelului (4), deci acoperă lumea și HUD-ul (1), dar rămân SUB bara de boss (6)
# — cadrul se strânge, numele boss-ului nu intră sub bandă.
func _cinema_intra(durata: float) -> void:
	var h := get_viewport().get_visible_rect().size.y * CUT_BENZI_H
	_banda_sus.offset_bottom = 0.0
	_banda_jos.offset_top = 0.0
	_vinieta.modulate.a = 0.0
	_banda_sus.visible = true
	_banda_jos.visible = true
	_vinieta.visible = true
	var t := _cut_tween()
	t.set_parallel(true)
	t.tween_property(_banda_sus, "offset_bottom", h, durata) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_banda_jos, "offset_top", -h, durata) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_vinieta, "modulate:a", CUT_VINIETA, durata)

func _cinema_iese(durata: float) -> void:
	var t := _cut_tween()
	t.set_parallel(true)
	t.tween_property(_banda_sus, "offset_bottom", 0.0, durata) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_banda_jos, "offset_top", 0.0, durata) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_vinieta, "modulate:a", 0.0, durata)
	t.chain().tween_callback(_cinema_ascunde)

func _cinema_ascunde() -> void:
	_banda_sus.visible = false
	_banda_jos.visible = false
	_vinieta.visible = false

func _fa_banda(sus: bool) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color(0, 0, 0)
	b.anchor_left = 0.0
	b.anchor_right = 1.0
	# Lipită de marginea ei, cu înălțime 0: crește din offset-ul dinspre interior.
	b.anchor_top = 0.0 if sus else 1.0
	b.anchor_bottom = 0.0 if sus else 1.0
	b.offset_top = 0.0
	b.offset_bottom = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.visible = false
	add_child(b)
	return b

# Vinietă, nu geam gri peste tot: aici pământul e verde-închis, iar armura lui e cenușie și roșie —
# un întuneric uniform i-ar fi stins exact silueta. Așa se sting doar marginile.
func _fa_vinieta() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))   # mijloc: curat
	grad.set_color(1, Color(0, 0, 0, 1.0))   # margini: negru
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	# ⚠️ Filtrare LINIARĂ, pusă pe față: jocul e pixel-art, deci filtrul implicit e „cel mai apropiat
	# pixel", iar degradeul de 256px întins pe tot ecranul ar fi ieșit în trepte vizibile.
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	r.visible = false
	add_child(r)
	return r

# ---------- unde te așteaptă ----------
# Un INEL în jurul porții. `sqrt` ca punctele să fie împrăștiate uniform pe SUPRAFAȚĂ: cu o
# distanță pur aleatoare s-ar înghesui spre marginea interioară (ca la Ender).
func _loc_boss() -> Vector2:
	if _poarta == null or not is_instance_valid(_poarta):
		return _player.global_position if _player != null else Vector2.ZERO
	var unghi := randf() * TAU
	var d := sqrt(lerpf(BOSS_MIN_DIST * BOSS_MIN_DIST, BOSS_MAX_DIST * BOSS_MAX_DIST, randf()))
	return _poarta.global_position + Vector2(cos(unghi), sin(unghi)) * d

func _free_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		_boss.queue_free()
	_boss = null

# ---------- dificultate ----------
func _diff_time() -> float:
	var t := _entry_diff_time + _elapsed
	if _elapsed >= PRISON_TIME:
		t = maxf(t, Difficulty.RUN_LENGTH + (_elapsed - PRISON_TIME))
	return t

func portal_pos() -> Vector2:
	if _poarta != null and is_instance_valid(_poarta):
		return _poarta.global_position
	return Vector2.INF

func time_left() -> float:
	return maxf(0.0, PRISON_TIME - _elapsed)

# ---------- ecran ----------
func _update_clock() -> void:
	if _elapsed >= PRISON_TIME:
		_clock.text = "+" + _mmss(_elapsed - PRISON_TIME)
		_clock.add_theme_color_override("font_color", CLOCK_SWARM)
		return
	var ramas := PRISON_TIME - _elapsed
	_clock.text = _mmss(ramas)
	_clock.add_theme_color_override("font_color", CLOCK_WARN if ramas <= 60.0 else CLOCK_COLOR)

# Spre ce arată busola, în ordinea în care ai nevoie de ele: boss-ul cât trăiește, poarta după ce
# cade. (Până pe 2026-08-22 arăta întâi spre statuie — nu mai există.)
func _tinta_busola() -> Node2D:
	if not _boss_invins and _boss != null and is_instance_valid(_boss):
		return _boss
	return _poarta

func _update_compass() -> void:
	var tinta := _tinta_busola()
	if tinta == null or not is_instance_valid(tinta) or _player == null:
		_arrow.visible = false
		_dist.visible = false
		return
	var vp := get_viewport().get_visible_rect().size
	var screen: Vector2 = get_viewport().get_canvas_transform() * tinta.global_position
	var m := COMPASS_MARGIN
	var pe_ecran := screen.x > m and screen.x < vp.x - m and screen.y > m and screen.y < vp.y - m
	_arrow.visible = not pe_ecran
	_dist.visible = not pe_ecran
	if pe_ecran:
		return
	var centru := vp * 0.5
	var dir := screen - centru
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var half := centru - Vector2(m, m)
	var t := INF
	if absf(dir.x) > 0.0001:
		t = minf(t, half.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		t = minf(t, half.y / absf(dir.y))
	var poz := centru + dir * t
	_arrow.position = poz - Vector2(28, 28)
	_arrow.rotation = dir.angle() + PI * 0.5
	_dist.position = poz - Vector2(80, -34)
	_dist.text = "%d" % int(_player.global_position.distance_to(tinta.global_position))

func _flash_screen(durata: float = FLASH) -> void:
	_flash.visible = true
	_flash.modulate.a = 1.0
	# ⚠️ Merge ȘI pe pauză: la intrare, cinematica îngheață jocul în aceeași clipă, iar un tween
	# pauzabil ar fi lăsat ecranul ALB tot filmulețul.
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_flash, "modulate:a", 0.0, durata)
	t.tween_callback(func(): _flash.visible = false)

# ---------- ajutoare ----------
func _spawn_one() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var sp := get_tree().get_first_node_in_group("spawner")
	if sp == null or not sp.has_method("naste_inamic_aici"):
		return
	var unghi := randf() * TAU
	sp.naste_inamic_aici(_player.global_position
		+ Vector2(cos(unghi), sin(unghi)) * BURST_RADIUS * randf_range(0.85, 1.25))

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

func _set_ground_prison(on: bool) -> void:
	var ground := get_tree().get_first_node_in_group("ground")
	if ground != null and ground.has_method("set_prison"):
		ground.set_prison(on)

func _margine(on: bool) -> void:
	var ground := get_tree().get_first_node_in_group("ground")
	if ground == null or not ground.has_method("set_margine"):
		return
	var centru := portal_pos()
	if on and centru != Vector2.INF:
		ground.set_margine(centru)
	else:
		ground.opreste_margine()

func _set_atmosphere(kind: String) -> void:
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm != null and atm.has_method("set_dimension"):
		atm.set_dimension(kind)

func _generator(nume: String) -> Node:
	if _player == null or not is_instance_valid(_player):
		return null
	var world := _player.get_parent()
	return world.get_node_or_null(nume) if world != null else null

func _set_world_enabled(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var world := player.get_parent()
	if world == null:
		return
	for n in WORLD_NODES:
		_toggle_generator(world.get_node_or_null(n), on)
	var root := world.get_parent()
	if root != null:
		for n in ROOT_NODES:
			_toggle_generator(root.get_node_or_null(n), on)

func _toggle_generator(node: Node, on: bool, goleste: bool = true) -> void:
	if node == null:
		return
	node.visible = on
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if not on and goleste:
		for c in node.get_children():
			c.queue_free()
		if node.get("_loaded") != null:
			node.set("_loaded", {})

func _zguduie_camera() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	tw.tween_method(_shake.bind(cam), 1.0, 0.0, SHAKE_TIME)
	tw.tween_callback(_shake_stop.bind(cam))

func _shake(amount: float, cam: Camera2D) -> void:
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_STRENGTH * amount

func _shake_stop(cam: Camera2D) -> void:
	cam.offset = Vector2.ZERO

func _mmss(secunde: float) -> String:
	var s := int(ceil(maxf(0.0, secunde)))
	return "%d:%02d" % [s / 60, s % 60]

func _anunta(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
