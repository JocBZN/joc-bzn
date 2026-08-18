extends CanvasLayer

# PUȘCĂRIA — a patra dimensiune. Făcută exact ca Nether-ul și Ender-ul (`nether.gd`, `ender.gd`):
# NU se încarcă altă scenă, rămâi în aceeași lume la aceleași coordonate, dar podeaua devine
# pavaj de temniță, decorul se stinge, ceasul rundei îngheață și pornește unul propriu, iar
# inamicii lasă `XP_BONUS` × XP.
#
# ⚠️ CUM AJUNGI AICI — SCHIMBAT pe 2026-08-18 (cerut de Răzvan: „nu vreau ca portalele să se
# spawneze după ce termini Ender, vreau să fie de la început random pe hartă cu 1% șansă per
# chunk"). Porțile au acum generator PROPRIU, `prison_gates.gd`, aprins din minutul zero al
# rundei; nu mai sunt a treia vârstă a locurilor din `portals.gd`.
# Deci pușcăria NU mai e închisă până termini celelalte dimensiuni: poți intra oricând dai peste
# o poartă. Ce o ține grea rămâne ce e ÎNĂUNTRU — inamicii îngroșați (`ENEMY_POWER` & co.) și
# WARDEN-ul cu 260 000 de viață, nescalată. Dacă intri devreme, intri nepregătit.
#
# ⚠️ TOT UNA PE RUNDĂ: la ieșirea victorioasă se oprește generatorul PORȚILOR
# (`prison_gates.opreste()`), nu cel de portaluri. Lanțul Nether → Ender merge mai departe,
# neatins, cu opririle lui.
#
# Boss-ul NU te așteaptă la intrare (ca în Ender), ci îl scoți TU dintr-o STATUIE
# (`prison_statue.gd`), ca Saratalin în Nether. Până n-o găsești, pușcăria e doar o temniță
# plină de inamici; după, e o luptă cu bară pe ecran, iar poarta nu se deschide până nu cade el.

const STATUIE := preload("res://prison_statue.tscn")

# --- reglaje ---
const PRISON_TIME := 300.0      # 5:00 — mai scurt decât Ender-ul (6:00): e ultima, deci mai apăsată
const XP_BONUS := 4.0           # Nether 2, Ender 3, aici 4
# ⚠️ 8, nu 26 (2026-08-17, după ce Răzvan a jucat-o): la 26 mureai în prima secundă și nici nu
# apucai să pleci de lângă poartă. Nether-ul scoate 25, dar acolo inamicii au 50 HP și damage 1.0;
# aici sunt cei mai duri din joc, îngroșați. Valul e un „bun venit", nu execuția.
const BURST := 8                # câți inamici apar DEODATĂ la intrare
const BURST_RADIUS := 640.0
const FLASH := 0.45
const CLOCK_SIZE := 64
const CLOCK_COLOR := Color(0.78, 0.80, 0.62)     # verzui-piatră, ca mucegaiul de pe pereți
const CLOCK_WARN := Color(1.0, 0.82, 0.20)
const CLOCK_SWARM := Color(1.0, 0.10, 0.10)
const COMPASS_MARGIN := 96.0
const TELEPORT_DB := -4.0
# Unde punem statuia: un INEL în jurul porții. ⚠️ APROPIATĂ pe 2026-08-17 (era 750–1250): Răzvan
# n-o găsea, fiindcă murea pe drum. La 380–620 o vezi aproape imediat ce aterizezi, iar busola te
# duce la ea oricum. Boss-ul e miezul dimensiunii — n-are rost s-o faci o vânătoare.
const STATUIE_MIN_DIST := 380.0
const STATUIE_MAX_DIST := 620.0
const SHAKE_STRENGTH := 24.0
const SHAKE_TIME := 0.9

# ⚠️ Aceeași listă ca în `nether.gd` / `ender.gd` / `limbo.gd`. Un generator nou pus în `World`
# (main.tscn) trebuie trecut în TOATE. Dacă lipsește dintr-una, rămâne aprins acolo și-i vezi
# obiectele într-o dimensiune în care n-au ce căuta (s-a întâmplat de trei ori).
const WORLD_NODES := ["Props", "Rocks", "Bushes", "DesertStructures", "Statues", "Portals", "PrisonGates", "Chests", "EGTs", "Monuments", "AlbaNeagras", "Dubiosi"]
const ROOT_NODES := ["Paths"]

var active := false

# Cât de îngroșați sunt inamicii de aici. Cerut de Răzvan: „folosește enemy-ii care există deja,
# doar fă-i mai OP deocamdată". Îl citește `spawner.gd` și îl pune pe `enemy.gd::power_mult`
# ÎNAINTE de `add_child` (acolo se coace viața), plus un plus de viteză.
#
# ⚠️ CIFRELE ASTEA AU FOST TĂIATE pe 2026-08-17, după ce Răzvan a jucat-o: „se buguiește,
# monstrul nu apare și mă bagă random în Limbo". Nu era un bug — MUREA în prima secundă și nu mai
# apuca să găsească statuia. Erau 3.0 / 1.25 / 1.6.
#
# 🔑 Ce l-a omorât e DAMAGE-UL, nu viața. Damage-ul de contact se plătește PER INAMIC LIPIT DE
# TINE, la fiecare 0,5 s (`player._take_contact_damage`), și se înmulțește deja de două ori:
# o dată cu `damage_mult` al felului (creatura Ender are 2.0, pompierul 2.0, SWAT 1.3) și o dată
# cu `Difficulty.enemy_damage_mult()`, care la minutul la care ajungi în pușcărie e ~×2,5. Un al
# treilea multiplicator de la mine peste ele înmulțea, nu aduna: 5 × 2,5 × 2,0 × 1,6 = 40 de damage
# per creatură, la fiecare jumătate de secundă. Cu cinci pe tine, 400/s dintr-o viață de ~150.
#
# Deci „mai OP" înseamnă acum: mai GRAȘI (îi tai mai greu) și puțin mai iuți — dar damage-ul îl
# lăsăm în pace, fiindcă el e cel care se înmulțește cu numărul lor.
# ⚠️ 1.25, nu 3.0 cum era la prima scriere. Viața în plus e cea care te omoară INDIRECT: la
# minutul 8 inamicii au deja ×16,3 din dificultate, iar dacă nu-i mai poți curăța se adună pe
# tine, iar damage-ul de contact se plătește per inamic. Îngroșarea adevărată a pușcăriei nu e
# multiplicatorul ăsta, ci FAPTUL CĂ VIN TOATE FELURILE DEODATĂ: în lumea normală te bat mai ales
# polițiști, aici îți vin SWAT, pompieri și creaturi de Ender în același val.
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
var _statuie: Node2D = null
var _boss: Node2D = null
var _elapsed := 0.0
var _entry_diff_time := 0.0
var _swarm_announced := false
var _boss_invins := false
var _suspendat := false

# PUBLIC și NU se stinge la ieșire: „ai bătut Warden-ul măcar o dată în runda asta". Sora lui
# `nether.gd::escaped` și `ender.gd::celesto_invins`. Deocamdată nu-l citește nimeni — e cârligul
# pentru „inamicii pușcăriei apar și în lumea normală", dacă se cere vreodată.
var warden_invins := false

func _ready() -> void:
	add_to_group("prison")
	layer = 4

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	_flash.visible = false
	add_child(_flash)

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
	Audio.play_nether_music()     # n-avem muzică proprie; împrumutăm bucla Nether-ului
	_clock.text = _mmss(PRISON_TIME)
	_clock.add_theme_color_override("font_color", CLOCK_COLOR)
	_clock.visible = true
	_flash_screen()

	_pune_statuia()
	_anunta("THE PRISON", "Find the statue. Wake what sleeps in it.")
	for i in BURST:
		_spawn_one()

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
			_anunta("THE GATE IS SEALED", "Something in here still sleeps")
		else:
			_anunta("THE WARDEN STILL STANDS", "The gate will not open until it falls")
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
	_free_statuie()
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

func _process(delta: float) -> void:
	if not active or _suspendat:
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
		_anunta("PRISON SWARM", "The gate still works. For now.")
		Audio.play("levelup", -2.0)

# Chemată de `prison_statue.gd` când scoate boss-ul: de aici încolo busola arată spre el, iar
# pauza de Limbo știe pe cine să parcheze.
func boss_invocat(boss: Node2D) -> void:
	_boss = boss

# Chemată de `final_boss.gd` când moare: de aici încolo poarta te lasă să pleci.
func boss_invins() -> void:
	if not active or _boss_invins:
		return
	_boss_invins = true
	warden_invins = true
	_anunta("THE WARDEN FALLS", "Press E at the gate to go back")
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
	_arata_obiect(_statuie, false)
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
	_arata_obiect(_statuie, true)
	_park_boss(false)
	_bara_boss(true)

# ⚠️ Parametrul e NETIPIZAT dinadins. Statuia se șterge singură după ce scoate boss-ul, deci
# `_statuie` rămâne o referință MOARTĂ — iar dacă parametrul e `Node2D`, Godot crapă la APEL
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

# ---------- statuia ----------
# O punem într-un inel în jurul porții. `sqrt` ca punctele să fie împrăștiate uniform pe
# SUPRAFAȚĂ: cu o distanță pur aleatoare s-ar înghesui spre marginea interioară (ca la Ender).
func _pune_statuia() -> void:
	if _player == null or _poarta == null:
		return
	var world := _player.get_parent()
	if world == null:
		return
	var unghi := randf() * TAU
	var d := sqrt(lerpf(STATUIE_MIN_DIST * STATUIE_MIN_DIST, STATUIE_MAX_DIST * STATUIE_MAX_DIST, randf()))
	_statuie = STATUIE.instantiate()
	world.add_child(_statuie)
	_statuie.global_position = _poarta.global_position + Vector2(cos(unghi), sin(unghi)) * d

func _free_statuie() -> void:
	if _statuie != null and is_instance_valid(_statuie):
		_statuie.queue_free()
	_statuie = null

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

# Spre ce arată busola, în ordinea în care ai nevoie de ele: statuia cât n-ai trezit boss-ul,
# boss-ul cât trăiește, poarta după ce cade.
func _tinta_busola() -> Node2D:
	if _statuie != null and is_instance_valid(_statuie):
		return _statuie
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

func _flash_screen() -> void:
	_flash.visible = true
	_flash.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_flash, "modulate:a", 0.0, FLASH)
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
