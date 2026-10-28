extends CanvasLayer

# ARENA — a cincea și ultima dimensiune: lupta cu TOȚI TREI boșii deodată.
# Cerută de Răzvan pe 2026-10-28: „vreau să adăugăm un boss și să mutăm win screen-ul [...] să fie
# toți 3 bossi din joc (Saratalin, Celesto și Sir John) și au toți câte 2 milioane HP. Vreau să faci
# o animație cu toți 3 super top când intri în portal și se spawnează fiecare în părți diferite
# (gen unu la nord, unu la sud și unu la west sau east). Primești doar un nivel când omori unul
# dintre ei. Podeaua vreau să fie ca la Sir John doar că colorată altfel."
# Întrebat: portalul răsare PE HARTĂ, ca celelalte uși (nu în castel), și înăuntru sunt DOAR cei trei
# boși — fără inamici, fără ceas, fără swarm.
#
# Făcută ca celelalte dimensiuni (citește `prison.gd` întâi, de acolo vine scheletul): nu se încarcă
# altă scenă, rămâi la aceleași coordonate, decorul se stinge, podeaua se schimbă, dificultatea
# îngheață, portalul prin care ai intrat devine ieșirea.
#
# LANȚUL, de la cap la coadă:
#   portal Nether → (Saratalin) → fântână Ender → (Celesto) → poartă de castel → (Sir John)
#   → PORTAL DE ARENĂ (`arena_portals.gd`, aprins de `prison.gd::boss_invins`) → (toți trei) → YOU WIN!
#
# 🔑 ECRANUL „YOU WIN!" S-A MUTAT AICI. Până pe 2026-10-28 îl deschidea `final_boss.gd` la moartea lui
# Sir John în castel; acum îl deschide `boss_mort()` când cade ULTIMUL din cei trei. Tot de aici se
# bifează și challenge-ul rundei (`victory.gd` o face când apare ecranul).
#
# CEI TREI sunt chiar boșii din dimensiunile lor (`saratalin.tscn`, `celesto.tscn`, `final_boss.tscn`)
# cu toate atacurile și fazele lor, doar că primesc `arena = self` ÎNAINTE de `add_child`. Asta le
# schimbă patru lucruri, scrise în fiecare script lângă variabila `arena`:
#   • viața e `BOSS_HP` (2 000 000), nu a lor;
#   • fiecare are bara LUI (`bara_arena`, trei bare una lângă alta — vezi `slot` în `boss_bar.gd`);
#   • la moarte dau `NIVELURI_PREMIU` (1) și ne anunță pe NOI, nu dimensiunea lor;
#   • Saratalin nu-și mai joacă filmulețul de la jumătate (ar fi oprit lupta cu ceilalți doi în cadru).

const SARATALIN := preload("res://saratalin.tscn")
const CELESTO := preload("res://celesto.tscn")
const SIR_JOHN := preload("res://final_boss.tscn")
const BARA := preload("res://boss_bar.gd")
const VICTORIE := preload("res://victory.gd")

# --- reglaje ---
const BOSS_HP := 2000000
const NIVELURI_PREMIU := 1      # câte niveluri dă FIECARE boss de aici (în dimensiunile lor: 3 / 4 / 5)
# Cât de departe de tine apar, pe cele patru puncte cardinale. Destul cât să ai unde respira la
# început, destul de aproape cât să-i prinzi pe toți trei în cadru la zoom-ul obișnuit.
const BOSS_DIST := 640.0
# Arena e un DISC, nu o lume întreagă: groapa începe mai aproape decât în Nether/Ender (3000). Cu trei
# boși care te urmăresc, la 3000 te-ai fi plimbat în cerc cât vrei; aici trebuie să te bați.
const ARENA_RAZA := 2300.0
const FLASH_CUT := 0.18
const FLASH := 0.45
const COMPASS_MARGIN := 96.0
const COMPASS_COLOR := Color(1.0, 0.55, 0.45)
const TELEPORT_DB := -4.0
const SHAKE_STRENGTH := 24.0
const SHAKE_TIME := 0.9

# ⚠️ Aceeași listă ca în `nether.gd` / `ender.gd` / `limbo.gd` / `prison.gd`. Un generator nou pus în
# `World` (main.tscn) trebuie trecut în TOATE CINCI.
const WORLD_NODES := ["Props", "Rocks", "Bushes", "DesertStructures", "Statues", "Portals", "PrisonGates", "ArenaPortals", "Chests", "EGTs", "Monuments", "AlbaNeagras", "Dubiosi"]
const ROOT_NODES := ["Paths"]

var active := false

var _player: Node2D = null
var _portal: Node2D = null      # portalul prin care ai intrat; tot el e ieșirea
var _bosi: Array = []           # cei vii, în ordinea în care au intrat în cadru
var _bare: Array = []           # cele trei bare (CanvasLayer-e, copii ai noștri)
var _castigat := false          # au căzut toți trei
var _suspendat := false
var _flash: ColorRect
var _arrow: Label
var _dist: Label
var _banda_sus: ColorRect
var _banda_jos: ColorRect
var _vinieta: TextureRect
var _titlu: Label
var _subtitlu: Label

func _ready() -> void:
	add_to_group("arena")
	layer = 4

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
	_titlu = _fa_titlu(54, 0.66)
	_subtitlu = _fa_titlu(22, 0.66 + 0.11)

	_arrow = Label.new()
	_arrow.text = "▲"
	_arrow.custom_minimum_size = Vector2(56, 56)
	_arrow.size = Vector2(56, 56)
	_arrow.pivot_offset = Vector2(28, 28)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arrow.add_theme_font_size_override("font_size", 40)
	_arrow.add_theme_color_override("font_color", COMPASS_COLOR)
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
	_dist.add_theme_color_override("font_color", COMPASS_COLOR)
	_dist.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_dist.add_theme_constant_override("outline_size", 6)
	_dist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dist.visible = false
	add_child(_dist)

# ---------- INTRARE ----------
# Chemată din `portal_arena.gd` când apeși E. Primim NODUL portalului: cât ești dincolo, el e ieșirea.
func enter(player: Node2D, portal: Node2D) -> void:
	if active or player == null or player.dead or portal == null:
		return
	for g in ["limbo", "nether", "ender", "prison"]:
		var alta := get_tree().get_first_node_in_group(g)
		if alta != null and alta.active:
			return
	active = true
	_player = player
	_portal = portal
	_castigat = false
	# Îl scoatem din generator și-l mutăm în `World`, altfel golirea decorului de mai jos ne-ar lua
	# chiar ieșirea de sub picioare (aceeași mișcare ca în `prison.gd::enter`).
	var world := player.get_parent()
	if world != null and _portal.get_parent() != world:
		_portal.reparent(world)
	_portal.retur = true

	_clear_enemies()
	_set_world_enabled(false)
	_set_ground_arena(true)
	_margine(true)
	_set_atmosphere("arena")

	Difficulty.frozen = true
	Difficulty.mult_time_override = Difficulty.time
	Difficulty.xp_bonus = 1.0

	Audio.stop_forest_ambient()
	# Tăcere peste cinematică: ea are sunetele ei, iar tema de boss intră abia la capătul ei.
	Audio.stop_music_tinand_minte()
	Audio.play("teleport", TELEPORT_DB, 0.0)
	_flash_screen(FLASH_CUT)
	_cutscene()

# ---------- IEȘIRE ----------
# `anunt = true`  → voluntară, E pe portal (doar după ce au căzut toți trei).
# `anunt = false` → forțată: ai murit. Trece mereu.
func exit_arena(anunt: bool = true) -> void:
	if not active:
		return
	if _suspendat:
		reia()
	if anunt and not _castigat:
		_anunta("THE PORTAL IS SEALED", "They still stand")
		Audio.play("levelup", -6.0)
		return
	active = false
	_clear_enemies()
	_free_bosi()
	_set_world_enabled(true)
	_set_ground_arena(false)
	_margine(false)
	_set_atmosphere("")
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0
	Difficulty.xp_bonus = 1.0
	if _portal != null and is_instance_valid(_portal):
		_portal.retur = false
	_arrow.visible = false
	_dist.visible = false
	Audio.play_forest_ambient()
	Audio.restore_world_music()
	if anunt:
		Audio.play("teleport", TELEPORT_DB, 0.0)
		_flash_screen()
		_anunta("BACK", "The run is yours")
		_inchide_portalul()

func _process(_delta: float) -> void:
	if not active or _suspendat or _cut_activ:
		return
	if _player == null or not is_instance_valid(_player) or _player.dead:
		exit_arena(false)
		return
	_update_compass()

# Chemată de fiecare boss din `_die()`, când are `arena` setat.
func boss_mort(b: Node) -> void:
	_bosi.erase(b)
	if not active:
		return
	if not _bosi.is_empty():
		_anunta(str(b.get("nume")), "Two remain" if _bosi.size() == 2 else "One remains")
		Audio.play("levelup", -4.0)
		return
	_castigat = true
	_anunta("THE RECKONING IS OVER", "Press E at the portal to go back")
	Audio.play("levelup", -2.0)
	_victorie()

# Ecranul YOU WIN! (`victory.gd`) — mutat aici din `final_boss.gd`. Se agață de SCENA de joc: boșii
# se șterg la capătul animației de moarte, iar ecranul trebuie să le supraviețuiască. Așteaptă singur
# animația și Level Up-ul de la premiu (vezi capul lui `victory.gd`).
func _victorie() -> void:
	if get_tree().get_first_node_in_group("victory_screen") != null:
		return
	var v := CanvasLayer.new()
	v.set_script(VICTORIE)
	get_tree().current_scene.add_child(v)
	v.porneste()

# ---------- PAUZĂ CÂT EȘTI ÎN LIMBO ----------
# Ca `prison.gd::suspenda()`: boșii se scot din grupul „enemy" (pe ăla îl mătură Limbo) și se ascund,
# altfel trei boși aduși la jumătate ar dispărea și portalul n-ar mai avea cum să se deschidă.
func suspenda() -> void:
	if not active or _suspendat:
		return
	_suspendat = true
	_set_ground_arena(false)
	_margine(false)
	_set_atmosphere("")
	_arrow.visible = false
	_dist.visible = false
	_arata_obiect(_portal, false)
	for b in _bosi:
		if is_instance_valid(b):
			b.remove_from_group("enemy")
			_arata_obiect(b, false)
	for bara in _bare:
		if is_instance_valid(bara):
			bara.visible = false

func reia() -> void:
	if not _suspendat:
		return
	_suspendat = false
	_set_ground_arena(true)
	_margine(true)
	_set_atmosphere("arena")
	Difficulty.frozen = true
	Difficulty.xp_bonus = 1.0
	_arata_obiect(_portal, true)
	# barele doar ale celor încă vii: a unui boss căzut a rămas goală și n-are ce căuta pe ecran
	for b in _bosi:
		if is_instance_valid(b):
			b.add_to_group("enemy")
			_arata_obiect(b, true)
			if is_instance_valid(b.bara_arena):
				b.bara_arena.visible = true

# Netipizat dinadins — vezi `prison.gd::_arata_obiect`.
func _arata_obiect(n, on: bool) -> void:
	if n == null or not is_instance_valid(n):
		return
	n.visible = on
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

func portal_pos() -> Vector2:
	if _portal != null and is_instance_valid(_portal):
		return _portal.global_position
	return Vector2.INF

func in_cinematic() -> bool:
	return _cut_activ

# Ieșire victorioasă → gata cu portalurile arenei în runda asta. Cel prin care ai ieșit intră în pământ.
func _inchide_portalul() -> void:
	var gen := _generator("ArenaPortals")
	if gen != null and gen.has_method("opreste"):
		gen.opreste()
	if _portal == null or not is_instance_valid(_portal):
		return
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)
	_zguduie_camera()
	if _portal.has_method("intra_in_pamant"):
		_portal.intra_in_pamant()
	_portal = null

func _free_bosi() -> void:
	for b in _bosi:
		if is_instance_valid(b):
			b.queue_free()
	_bosi.clear()
	for bara in _bare:
		if is_instance_valid(bara):
			bara.queue_free()
	_bare.clear()

# ---------- CINEMATICA DE INTRARE ----------
# „Vreau să faci o animație cu toți 3 super top când intri în portal și se spawnează fiecare în
# părți diferite (gen unu la nord, unu la sud și unu la west sau east)."
#
# Scheletul e cel de la Sir John (`prison.gd::_cutscene_sir_john`): îngheț ADEVĂRAT, benzi + vinietă,
# camera cu un singur scriitor (`_cut_baza` + `_cut_shake`), tween-uri care merg pe pauză. Înăuntru,
# fiecare boss intră cu SEMNĂTURA LUI, cea pe care o știi din dimensiunea lui:
#
#   0:00  ÎNGHEȚ. Bubuitura lui Sir John + basul lui Celesto, benzile intră, ecranul se întunecă pe
#         margini. Locurile sunt trase la sorți: NORD, SUD și VEST sau EST (unul din două).
#   apoi, pentru FIECARE din cei trei, pe rând (nord → lateral → sud):
#     • camera zboară la locul lui și strânge zoom-ul;
#     • SARATALIN cade din cer, mov-aprins, și izbește pământul (cutremur);
#     • CELESTO clipește de două ori prin aer, lăsând umbre albastre, și se materializează;
#     • SIR JOHN face trei pași grei spre tine și-și înfige sabia în pământ (unda lui, fără damage);
#     • îi coboară BARA, în coloana lui, cu clicul ei, iar jos apare numele mare + de unde vine.
#   la final: camera se întoarce la tine, „THE RECKONING" pocnește pe ecran cu cea mai mare
#         zguduitură din toată secvența, benzile ies, pornește tema de boss și se dă drumul la luptă.
#
# ⚠️ Aceleași trei precauții de pauză ca la Sir John: noi pe ALWAYS, `Fx` pe pauzabil, netezirea
# camerei oprită. Boșii primesc ALWAYS cât ține filmulețul (altfel tween-urile/umbrele lor ar sta),
# dar sunt ADORMIȚI — `_physics_process` al lor iese din prima linie, deci nu atacă în cinematică.
const CUT_ZOOM := 1.45          # cât se apropie camera de fiecare boss
const CUT_ZOOM_FINAL := 0.86    # la final se DESCHIDE peste zoom-ul obișnuit, ca să-i prinzi pe toți
const CUT_ZBOR := 0.50          # cât zboară camera de la un loc la altul
const CUT_TINE := 0.55          # cât rămâne pe un boss după ce i-a coborât bara
const CUT_BARA := 0.60
const CUT_BENZI := 0.35
const CUT_BENZI_H := 0.085
const CUT_VINIETA := 0.80
const CUT_DUCK := -16.0
# Saratalin
const CUT_CADERE := 0.55
const CUT_CADERE_DE_SUS := 560.0
const CULOARE_MOV := Color(3.2, 0.8, 4.0)     # aceeași cu pulsul lui din `saratalin.gd`
# Celesto
const CULOARE_ALBASTRU := Color(1.6, 2.2, 4.0)
const CUT_CLIPIRE := 0.16
# Sir John
const CUT_PASI := 3
const CUT_PAS_PX := 28.0
const CUT_PAS_T := 0.30
const CUT_UNDA_RAZA := 300.0

const DE_UNDE := {
	"saratalin": "From the Below",
	"celesto": "From the Ender",
	"sir_john": "From the Castle",
}

var _cut_activ := false

func _cutscene() -> void:
	if _player == null:
		_cutscene_gata()
		return
	var world := _player.get_parent()
	if world == null:
		_cutscene_gata()
		return

	# --- locurile: nord, sud și vest SAU est, împărțite la întâmplare între cei trei ---
	var lateral := Vector2.LEFT if randf() < 0.5 else Vector2.RIGHT
	var locuri := [Vector2.UP, lateral, Vector2.DOWN]
	var cine := ["saratalin", "celesto", "sir_john"]
	cine.shuffle()

	_bosi.clear()
	var intrari := []   # [{boss, fel, loc}] în ordinea în care intră în cadru
	for i in 3:
		var fel: String = cine[i]
		var dir: Vector2 = locuri[i]
		var loc: Vector2 = _in_arena(_player.global_position + dir * BOSS_DIST)
		var b = _naste(fel, world)
		b.global_position = loc
		b.visible = false
		_bosi.append(b)
		intrari.append({"boss": b, "fel": fel, "loc": loc})

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

	_cinema_intra(CUT_BENZI)
	Audio.play_ex("sirjohn_freeze", -3.0)
	Audio.play_ex("celesto_sub", -6.0)
	Audio.play_ex("celesto_riser", -9.0)
	_cut_zguduie(14.0, 0.28)
	await _cut_asteapta(0.35)

	# --- cei trei, pe rând ---
	for intrare in intrari:
		var b = intrare["boss"]
		var loc: Vector2 = intrare["loc"]
		if not is_instance_valid(b):
			continue
		# camera la locul lui
		if cam != null:
			var t := _cut_tween()
			t.set_parallel(true)
			t.tween_method(_cut_pune_baza, _cut_baza, loc - _player.global_position, CUT_ZBOR) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM, CUT_ZBOR) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			await t.finished
		else:
			await _cut_asteapta(CUT_ZBOR)
		var fel: String = intrare["fel"]
		if fel == "saratalin":
			await _intra_saratalin(b, loc)
		elif fel == "celesto":
			await _intra_celesto(b, loc)
		else:
			await _intra_sir_john(b, loc)
		if not is_instance_valid(b):
			continue
		var bara = b.bara_arena
		if bara != null and is_instance_valid(bara):
			bara.arata_cinematic(str(b.nume), int(b.max_hp), CUT_BARA)
		Audio.play_ex("sirjohn_name" if fel == "sir_john" else "celesto_name", -5.0)
		_arata_titlu(str(b.nume), DE_UNDE.get(fel, ""), 46)
		await _cut_asteapta(CUT_TINE + CUT_BARA * 0.5)
		_ascunde_titlu(0.18)

	# --- finalul: camera înapoi la tine, larg, și titlul cel mare ---
	if cam != null:
		var t2 := _cut_tween()
		t2.set_parallel(true)
		t2.tween_method(_cut_pune_baza, _cut_baza, offset_vechi, 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t2.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM_FINAL, 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await t2.finished
	for b in _bosi:
		if is_instance_valid(b) and b.has_method("ingheata_spre"):
			b.ingheata_spre(b.directie_spre(_player.global_position), 0)
	Audio.play_ex("sirjohn_slam", 0.0)
	Audio.play_ex("sirjohn_sub", -2.0)
	Audio.play("earthquake", Audio.QUAKE_DB - 6.0, 0.0)
	_cut_zguduie(30.0, 0.6)
	_flash_screen(0.25)
	_arata_titlu("THE RECKONING", "Three crowns. One survivor.", 64)
	await _cut_asteapta(1.5)
	_ascunde_titlu(0.4)
	_cinema_iese(CUT_BENZI)
	if cam != null:
		var t3 := _cut_tween()
		t3.tween_property(cam, "zoom", zoom_vechi, 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await t3.finished
		cam.position_smoothing_enabled = neted_vechi
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

# Ultima bătaie: boșii se trezesc, tema de boss pornește, lupta e a ta.
func _cutscene_gata() -> void:
	if not active:
		return
	for b in _bosi:
		if is_instance_valid(b):
			b.process_mode = Node.PROCESS_MODE_INHERIT   # înapoi sub pauza normală a jocului
			b.visible = true
			b.trezeste()
			var bara = b.bara_arena
			if bara != null and is_instance_valid(bara) and not bara.visible:
				bara.arata(str(b.nume), int(b.max_hp))   # dacă filmulețul n-a apucat s-o coboare
	Audio.unduck_music(0.1)
	Audio.play_saratalin_music()

# Un boss nou, ADORMIT, cu bara lui. Netipizat: vezi capcana din `final_boss.gd::_scoate_inel`.
func _naste(fel: String, world: Node):
	var b
	var slot := 2
	if fel == "saratalin":
		b = SARATALIN.instantiate()
		slot = 0
	elif fel == "celesto":
		b = CELESTO.instantiate()
		slot = 1
	else:
		b = SIR_JOHN.instantiate()
	var bara = BARA.new()
	bara.slot = slot
	bara.sloturi = 3
	add_child(bara)
	_bare.append(bara)
	b.arena = self
	b.bara_arena = bara
	b.adoarme()          # ÎNAINTE de add_child: `_ready` nu-și cere bara și nu se mișcă
	world.add_child(b)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.ingheata_spre(b.directie_spre(_player.global_position), 0)
	return b

# --- intrările, fiecare cu semnătura lui ---

# SARATALIN cade din cer, ca atunci când îl chemi din portalul de invocare (`coboara_din_tavan`),
# doar că mai iute și aprins în mov — și aterizarea e un cutremur.
func _intra_saratalin(b, loc: Vector2) -> void:
	b.global_position = loc - Vector2(0, CUT_CADERE_DE_SUS)
	b.visible = true
	b.anim.modulate = CULOARE_MOV
	Audio.play_ex("saratalin_flash", -4.0)
	var t := _cut_tween()
	t.tween_property(b, "global_position", loc, CUT_CADERE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	if not is_instance_valid(b):
		return
	Audio.play("earthquake", Audio.QUAKE_DB - 8.0, 0.0)
	Audio.play_ex("sirjohn_sub", -4.0)
	_cut_zguduie(22.0, 0.45)
	var t2 := _cut_tween()
	t2.tween_property(b.anim, "modulate", Color(1, 1, 1), 0.45)
	await _cut_asteapta(0.25)

# CELESTO nu vine, APARE: două clipiri prin aer (cu umbrele lui albastre, ca la teleportările din
# luptă), apoi se materializează pe loc dintr-o lumină albastră.
func _intra_celesto(b, loc: Vector2) -> void:
	var laturi := [Vector2(-110, -40), Vector2(95, 25)]
	for off in laturi:
		b.global_position = loc + off
		b.visible = true
		b.anim.modulate = CULOARE_ALBASTRU
		Audio.play_pan("celesto_zap", b.global_position, -6.0)
		_cut_zguduie(5.0, 0.12)
		await _cut_asteapta(CUT_CLIPIRE)
		if not is_instance_valid(b):
			return
		b.umbra(b.global_position)
		Audio.play_pan("celesto_swish", b.global_position, -8.0)
	b.global_position = loc
	b.ingheata_spre(b.directie_spre(_player.global_position), 0)
	b.anim.modulate = Color(CULOARE_ALBASTRU.r, CULOARE_ALBASTRU.g, CULOARE_ALBASTRU.b, 0.0)
	Audio.play_ex("celesto_materialize", -4.0)
	var t := _cut_tween()
	t.tween_property(b.anim, "modulate", CULOARE_ALBASTRU, 0.22)
	t.tween_property(b.anim, "modulate", Color(1, 1, 1), 0.35)
	_cut_zguduie(10.0, 0.25)
	await t.finished

# SIR JOHN pășește: trei pași grei spre tine, fiecare cu bocancul lui și o zguduitură tot mai mare,
# apoi sabia în pământ — chiar unda lui de atac, dar fără damage (`unda_de_spectacol`).
func _intra_sir_john(b, loc: Vector2) -> void:
	var spre_tine: Vector2 = (_player.global_position - loc).normalized()
	if spre_tine.length() < 0.001:
		spre_tine = Vector2.DOWN
	b.global_position = loc - spre_tine * (CUT_PAS_PX * float(CUT_PASI))
	b.visible = true
	var dir_nume: String = b.directie_spre(_player.global_position)
	for i in CUT_PASI:
		b.global_position += spre_tine * CUT_PAS_PX
		b.ingheata_spre(dir_nume, (i + 1) * 2)
		Audio.play_pan("sirjohn_step", b.global_position, -10.0 + 3.0 * float(i), 1.0 - 0.03 * float(i))
		_cut_zguduie(5.0 + 3.0 * float(i), 0.16)
		await _cut_asteapta(CUT_PAS_T)
		if not is_instance_valid(b):
			return
	b.ingheata_spre(dir_nume, 0)
	Audio.play_ex("sirjohn_slam", -2.0)
	b.unda_de_spectacol(CUT_UNDA_RAZA)
	_cut_zguduie(20.0, 0.4)
	await _cut_asteapta(0.2)

# --- titlul mare de jos ---
# „Pocnește" în ecran: pornește mai mare și transparent și se strânge la mărimea lui în 0,25 s.
func _arata_titlu(text: String, sub: String, marime: int) -> void:
	_titlu.text = text
	_titlu.add_theme_font_size_override("font_size", marime)
	_subtitlu.text = sub
	for l in [_titlu, _subtitlu]:
		l.visible = true
		l.modulate.a = 0.0
		l.scale = Vector2(1.35, 1.35)
		l.pivot_offset = l.size * 0.5
	var t := _cut_tween()
	t.set_parallel(true)
	t.tween_property(_titlu, "modulate:a", 1.0, 0.18)
	t.tween_property(_titlu, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_subtitlu, "modulate:a", 1.0, 0.30).set_delay(0.12)
	t.tween_property(_subtitlu, "scale", Vector2.ONE, 0.30).set_delay(0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _ascunde_titlu(durata: float) -> void:
	var t := _cut_tween()
	t.set_parallel(true)
	t.tween_property(_titlu, "modulate:a", 0.0, durata)
	t.tween_property(_subtitlu, "modulate:a", 0.0, durata)

func _fa_titlu(marime: int, y_rel: float) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y_rel
	l.anchor_bottom = y_rel
	l.offset_top = -40
	l.offset_bottom = 40
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", marime)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62))
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.03))
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	add_child(l)
	return l

# Tween / pauză care merg CU JOCUL PE PAUZĂ (suntem ALWAYS cât ține cinematica).
func _cut_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

func _cut_asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde, true).timeout

# ---------- camera cinematicii ----------
# Identic cu `prison.gd`: încadrarea și zguduiturile sunt două variabile separate, adunate într-un
# singur loc — două tween-uri pe `cam.offset` s-ar anula unul pe altul.
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

# ---------- cadrul cinematic (benzile + vinieta) — copiat din `prison.gd` ----------
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
	Audio.duck_music(CUT_DUCK, 0.25)

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
	b.anchor_top = 0.0 if sus else 1.0
	b.anchor_bottom = 0.0 if sus else 1.0
	b.offset_top = 0.0
	b.offset_bottom = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.visible = false
	add_child(b)
	return b

func _fa_vinieta() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 1.0))
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
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # degradeu lin, nu în trepte (vezi `prison.gd`)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	r.visible = false
	add_child(r)
	return r

# ---------- busola ----------
# Spre cel mai apropiat boss viu; după ce cad toți, spre portal.
func _tinta_busola() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for b in _bosi:
		if not is_instance_valid(b):
			continue
		var d := _player.global_position.distance_squared_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	if best != null:
		return best
	return _portal if _portal != null and is_instance_valid(_portal) else null

func _update_compass() -> void:
	var tinta := _tinta_busola()
	if tinta == null or _player == null:
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
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_flash, "modulate:a", 0.0, durata)
	t.tween_callback(func(): _flash.visible = false)

# ---------- ajutoare ----------
# Un loc care sigur cade în arenă, nu în groapă (dacă ai intrat lângă margine — n-ai cum, portalul e
# chiar centrul, dar n-o lăsăm pe seama norocului).
func _in_arena(p: Vector2) -> Vector2:
	var centru := portal_pos()
	if centru == Vector2.INF:
		return p
	var raza := ARENA_RAZA - 900.0
	var d := p - centru
	if d.length() <= raza:
		return p
	return centru + d.normalized() * raza

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e in _bosi:
			e.queue_free()

func _set_ground_arena(on: bool) -> void:
	var ground := get_tree().get_first_node_in_group("ground")
	if ground != null and ground.has_method("set_arena"):
		ground.set_arena(on)

func _margine(on: bool) -> void:
	var ground := get_tree().get_first_node_in_group("ground")
	if ground == null or not ground.has_method("set_margine"):
		return
	var centru := portal_pos()
	if on and centru != Vector2.INF:
		ground.set_margine(centru, ARENA_RAZA)
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

func _anunta(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
