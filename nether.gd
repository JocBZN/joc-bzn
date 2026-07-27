extends CanvasLayer

# NETHER — a doua dimensiune. Intri apăsând E pe un Portal (`portal.gd`), ieși apăsând E
# pe portalul de întoarcere care apare fix acolo unde ai aterizat.
#
# Cum e făcut: EXACT ca la Limbo (`limbo.gd`) — NU se încarcă altă scenă. Rămâi în aceeași
# lume, la aceleași coordonate, dar:
#   • podeaua devine cărămidă roșie (`harta/nether/Brick32.png`, vezi `ground.gd`);
#   • generatoarele de decor (copaci, pietre, structuri, statui, portaluri, poteci) sunt
#     oprite și golite → o câmpie de cărămidă, goală;
#   • cronometrul rundei ÎNGHEAȚĂ și pornește un cronometru propriu, de NETHER_TIME;
#   • inamicii de aici lasă XP_BONUS × XP.
# Așa nu pierzi nimic din rundă (upgrade-uri, XP, nivel, poziție) și te întorci exact unde erai.
#
# La 0:00 începe NETHER SWARM: dificultatea sare pe exponențială (ca Final Swarm-ul rundei),
# cronometrul devine roșu și numără în sus. Ieșirea rămâne portalul — oricând, dar de la un
# punct e sinucidere să mai stai.

const PORTAL := preload("res://portal.tscn")
const ENEMY := preload("res://enemy.tscn")
const SUMMON := preload("res://summoning_portal.tscn")   # structura care îl cheamă pe Saratalin

# --- reglaje (schimbă-le liniștit) ---
const NETHER_TIME := 420.0      # 7:00 — cât ține faza „normală" înainte de Nether Swarm
const XP_BONUS := 2.0           # de câte ori mai mult XP lasă inamicii de aici
const BURST := 25               # câți inamici apar DEODATĂ la intrare
const BURST_RADIUS := 620.0     # la ce distanță de tine apar (cerc în jurul tău)
const FLASH := 0.45             # cât ține fulgerul alb de teleportare
const CLOCK_SIZE := 64                            # ca al Limbo-ului (cronometrul rundei e 44)
const CLOCK_COLOR := Color(1.0, 0.50, 0.16)       # portocaliu de foc
const CLOCK_WARN := Color(1.0, 0.82, 0.20)        # galben — ultimul minut
const CLOCK_SWARM := Color(1.0, 0.10, 0.10)       # roșu — Nether Swarm
const COMPASS_MARGIN := 96.0    # cât de departe de marginea ecranului stă săgeata spre portal
const TELEPORT_DB := -4.0       # cât de tare e whoosh-ul de teleportare (E pe portal)
# Unde punem structura de invocare a lui Saratalin: într-un INEL în jurul portalului de
# intrare — direcție la întâmplare, distanță între MIN și MAX. Deci n-o găsești în același
# loc de fiecare dată, dar nici nu-ți cade în brațe lângă portal.
const SUMMON_MIN_DIST := 600.0
const SUMMON_MAX_DIST := 1000.0
# Cutremurul de la închiderea portalurilor (aceleași cifre ca la statuie, să se simtă la fel)
const SHAKE_STRENGTH := 24.0
const SHAKE_TIME := 0.9

# Nodurile care fac decorul. Sunt oprite cât ești în Nether → „lume fără nimic".
# `Portals` e în listă ca să dispară portalurile lumii normale; al nostru de întoarcere
# stă direct în `World`, deci nu-l atinge golirea.
const WORLD_NODES := ["Props", "Rocks", "DesertStructures", "Statues", "Portals"]
const ROOT_NODES := ["Paths"]   # frați ai lui `World` din main.tscn (potecile)

var active := false

var _flash: ColorRect
var _clock: Label
var _arrow: Label            # săgeata care arată încotro e portalul de întoarcere
var _dist: Label             # distanța până la el (px de lume)
var _player: Node2D = null
var _return_portal: Node2D = null
var _summon_portal: Node2D = null   # structura lui Saratalin (dispare când o folosești)
var _elapsed := 0.0          # de câte secunde ești în Nether
var _entry_diff_time := 0.0  # în ce secundă a rundei ai intrat (de acolo pleacă dificultatea)
var _swarm_announced := false
var _boss_invins := false    # cât e `false`, portalul de întoarcere nu te lasă să pleci

func _ready() -> void:
	add_to_group("nether")
	layer = 4   # peste lume, sub textul de interacțiune (5) și sub Level Up / Game Over

	# fulgerul de teleportare: acoperă tot ecranul o clipă, ca să nu vezi lumea schimbându-se brusc
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	_flash.visible = false
	add_child(_flash)

	# cronometrul propriu al Nether-ului (cel al rundei e ascuns de HUD cât ești aici)
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

	# Busola spre portalul de întoarcere. Fără ea te pierzi: Nether-ul e o câmpie infinită,
	# identică peste tot, iar singura ieșire e un singur portal.
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
# Chemată din `portal.gd` (`invoca()`) când apeși E pe un portal din lumea normală.
# `portal_pos` = unde stătea portalul prin care ai intrat; acolo îl punem și pe cel de
# întoarcere. E important să NU-l punem peste player: portalul are zid, iar fizica l-ar
# împinge afară din el. Locul portalului din lume e sigur prin definiție — tocmai stăteai
# lângă el, deci nu e nimeni în zid.
func enter(player: Node2D, portal_pos: Vector2 = Vector2.INF) -> void:
	if active or player == null or player.dead:
		return
	# Nu intrăm peste Limbo: și el oprește decorul și rescrie dificultatea, s-ar bate cap în cap.
	var limbo := get_tree().get_first_node_in_group("limbo")
	if limbo != null and limbo.active:
		return
	active = true
	_player = player
	_elapsed = 0.0
	_entry_diff_time = Difficulty.time
	_swarm_announced = false
	_boss_invins = false

	_clear_enemies()          # inamicii lumii normale nu vin cu tine
	_set_world_enabled(false)
	_set_ground_nether(true)

	# cronometrul rundei stă pe loc; tăria inamicilor o dictăm noi, din `_diff_time()`
	Difficulty.frozen = true
	Difficulty.mult_time_override = _diff_time()
	Difficulty.xp_bonus = XP_BONUS

	# portalul de întoarcere, fix pe locul celui prin care ai intrat. Stă direct în `World`
	# (nu în `Portals`), ca golirea generatorului să nu-l șteargă.
	_spawn_return_portal(portal_pos)

	# Sunet: ambientul de pădure se oprește (nu mai ești în pădure), muzica lumii e pusă
	# deoparte și pornește sky-lines în buclă. `TELEPORT_DB` = whoosh-ul de trecere.
	Audio.stop_forest_ambient()
	Audio.play("teleport", TELEPORT_DB, 0.0)
	Audio.play_nether_music()
	_clock.text = _mmss(NETHER_TIME)
	_clock.add_theme_color_override("font_color", CLOCK_COLOR)
	_clock.visible = true
	_flash_screen()

	for i in BURST:
		_spawn_one()

	_announce("THE NETHER", "Kill Saratalin to leave")

# ---------- IEȘIRE ----------
# `anunt = true`  → ieșire VOLUNTARĂ, apăsând E pe portalul de întoarcere.
# `anunt = false` → ieșire FORȚATĂ: ai murit, sau player-ul nu mai există (plasa de
#                   siguranță din `_process`). Aia trece mereu, orice s-ar întâmpla —
#                   altfel ai rămâne blocat mort într-o dimensiune fără decor.
func exit_nether(anunt: bool = true) -> void:
	if not active:
		return
	# Nu pleci până nu cade Saratalin. Structura care îl cheamă e undeva în inelul din jurul
	# portalului; busola te duce la ea (vezi `_tinta_busola`).
	if anunt and not _boss_invins:
		_announce("SARATALIN LIVES", "The portal will not open until he falls")
		Audio.play("levelup", -6.0)
		return
	active = false
	_clear_enemies()          # ce era pe tine în Nether nu vine cu tine
	_set_world_enabled(true)
	_set_ground_nether(false)
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0
	Difficulty.xp_bonus = 1.0
	_free_return_portal()
	_clock.visible = false
	_arrow.visible = false
	_dist.visible = false
	# sunetul lumii înapoi: ambientul de pădure și melodia de dinainte, din secunda unde a rămas
	Audio.play_forest_ambient()
	Audio.restore_world_music()
	if anunt:
		Audio.play("teleport", TELEPORT_DB, 0.0)   # doar când ieși pe portal; dacă ai murit, nu
		_flash_screen()
		_announce("BACK", "The portals are closing")
		_inchide_portalurile()

func _process(delta: float) -> void:
	if not active:
		return
	# Ai murit în Nether (sau player-ul nu mai există) → ieșim curat, fără anunț.
	# În mod normal `player.die()` ne scoate el înainte; asta e plasa de siguranță.
	if _player == null or not is_instance_valid(_player) or _player.dead:
		exit_nether(false)
		return
	_elapsed += delta
	Difficulty.mult_time_override = _diff_time()
	_update_clock()
	_update_compass()
	if not _swarm_announced and _elapsed >= NETHER_TIME:
		_swarm_announced = true
		_announce("NETHER SWARM", "The portal still works. For now.")
		Audio.play("levelup", -2.0)

# L-ai bătut pe Saratalin și te-ai întors în lume → PORTALURILE SE ÎNCHID PE RESTUL RUNDEI.
# Cel prin care tocmai ai ieșit intră în pământ cu cutremur (ca statuia după invocare),
# restul dispar pe loc, iar generatorul nu mai naște altele. Un Nether pe rundă.
#
# Se cheamă doar de pe drumul VOLUNTAR de ieșire, care există numai după ce boss-ul a căzut.
func _inchide_portalurile() -> void:
	# generatorul tocmai a fost repornit (`_set_world_enabled(true)`); îi lăsăm două cadre
	# ca să pună portalurile la loc, altfel n-avem ce scufunda
	await get_tree().process_frame
	await get_tree().process_frame
	if _player == null or not is_instance_valid(_player):
		return
	var world := _player.get_parent()

	# Cel mai apropiat portal = exact ăla prin care ai ieșit (stăteai lângă el când ai apăsat E).
	var al_nostru: Node2D = null
	var d_min := INF
	for p in get_tree().get_nodes_in_group("interactable"):
		if not p.has_method("intra_in_pamant"):
			continue   # statuile sunt în același grup, dar ele nu se închid
		var d: float = _player.global_position.distance_to(p.global_position)
		if d < d_min:
			d_min = d
			al_nostru = p
	# îl scoatem din generator ÎNAINTE de `opreste()`, altfel ar fi șters odată cu ceilalți
	# și n-ai mai vedea scufundarea
	if al_nostru != null and world != null:
		al_nostru.reparent(world)

	var portals := _generator("Portals")
	if portals != null and portals.has_method("opreste"):
		portals.opreste()

	if al_nostru != null:
		Audio.play("earthquake", Audio.QUAKE_DB, 0.0)
		_zguduie_camera()
		al_nostru.intra_in_pamant()

# Nodul unui generator de decor din `World` (Props, Rocks, Portals...).
func _generator(nume: String) -> Node:
	if _player == null or not is_instance_valid(_player):
		return null
	var world := _player.get_parent()
	return world.get_node_or_null(nume) if world != null else null

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

# Chemată de `saratalin.gd` când boss-ul moare: de aici încolo portalul te lasă să pleci.
func boss_invins() -> void:
	if not active or _boss_invins:
		return
	_boss_invins = true
	_announce("THE WAY IS OPEN", "Press E at the portal to go back")
	Audio.play("levelup", -2.0)

# ---------- dificultate ----------
# Timpul din care se calculează cât de tari sunt inamicii cât ești aici.
# Două drepte, luăm maximul (deci nu scade niciodată brusc):
#   • `intrare + cât stai` — pleci de la dificultatea rundei și continuă să urce normal;
#   • după 0:00, cel puțin `RUN_LENGTH + cât a trecut de la 0:00` — adică Final Swarm,
#     unde viața inamicilor se dublează la fiecare 45s (vezi `difficulty.gd`).
func _diff_time() -> float:
	var t := _entry_diff_time + _elapsed
	if _elapsed >= NETHER_TIME:
		t = maxf(t, Difficulty.RUN_LENGTH + (_elapsed - NETHER_TIME))
	return t

# Câte secunde mai ai până la Nether Swarm (0 după ce a început).
func time_left() -> float:
	return maxf(0.0, NETHER_TIME - _elapsed)

# ---------- ecran ----------
func _update_clock() -> void:
	if _elapsed >= NETHER_TIME:
		_clock.text = "+" + _mmss(_elapsed - NETHER_TIME)
		_clock.add_theme_color_override("font_color", CLOCK_SWARM)
		return
	var ramas := NETHER_TIME - _elapsed
	_clock.text = _mmss(ramas)
	_clock.add_theme_color_override("font_color", CLOCK_WARN if ramas <= 60.0 else CLOCK_COLOR)

# Spre ce arată busola: OBIECTIVUL tău de acum. De când ieșirea cere să-l bați pe Saratalin,
# n-are sens să te trimită la un portal care oricum nu se deschide.
#   1. structura de invocare, cât timp n-ai chemat boss-ul (e la 600–1000px, trebuie găsită);
#   2. Saratalin însuși, cât timp trăiește;
#   3. portalul de întoarcere, după ce l-ai bătut.
func _tinta_busola() -> Node2D:
	if not _boss_invins:
		if _summon_portal != null and is_instance_valid(_summon_portal):
			return _summon_portal
		var boss := get_tree().get_first_node_in_group("saratalin") as Node2D
		if boss != null:
			return boss
	return _return_portal

# Săgeata spre țintă, lipită de marginea ecranului cât timp ținta nu se vede.
# Poziția ei din lume → pixeli de ecran (ca în `interact_ui.gd`).
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
	# cât trebuie să mergem din centru pe direcția `dir` ca să atingem chenarul (ecran − margine)
	var half := centru - Vector2(m, m)
	var t := INF
	if absf(dir.x) > 0.0001:
		t = minf(t, half.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		t = minf(t, half.y / absf(dir.y))
	var poz := centru + dir * t
	_arrow.position = poz - Vector2(28, 28)
	_arrow.rotation = dir.angle() + PI * 0.5   # „▲" arată în sus la rotație 0
	_dist.position = poz - Vector2(80, -34)
	_dist.text = "%d" % int(_player.global_position.distance_to(tinta.global_position))

func _flash_screen() -> void:
	_flash.visible = true
	_flash.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_flash, "modulate:a", 0.0, FLASH)
	t.tween_callback(func(): _flash.visible = false)

# ---------- ajutoare ----------
func _spawn_return_portal(portal_pos: Vector2) -> void:
	if _player == null:
		return
	var world := _player.get_parent()
	if world == null:
		return
	# fără poziție dată (ex. chemat din cod, nu de la un portal) îl punem puțin în fața ta,
	# nu peste tine — altfel zidul lui te-ar împinge
	var poz := portal_pos
	if is_inf(poz.x) or is_inf(poz.y):
		poz = _player.global_position + Vector2(0, -220)
	_return_portal = PORTAL.instantiate()
	_return_portal.retur = true          # apăsând E pe el IEȘI, nu intri iar
	world.add_child(_return_portal)
	_return_portal.global_position = poz
	# structura care îl cheamă pe Saratalin — una nouă la fiecare intrare în Nether, pusă
	# undeva în inelul din jurul portalului. `sqrt` ca punctele să fie împrăștiate uniform
	# pe SUPRAFAȚĂ: cu o distanță pur aleatoare s-ar înghesui spre marginea interioară.
	var unghi := randf() * TAU
	var d := sqrt(lerpf(SUMMON_MIN_DIST * SUMMON_MIN_DIST, SUMMON_MAX_DIST * SUMMON_MAX_DIST, randf()))
	_summon_portal = SUMMON.instantiate()
	world.add_child(_summon_portal)
	_summon_portal.global_position = poz + Vector2(cos(unghi), sin(unghi)) * d

func _free_return_portal() -> void:
	if _return_portal != null and is_instance_valid(_return_portal):
		_return_portal.queue_free()
	_return_portal = null
	# structura se șterge singură când o folosești, deci aici poate fi deja liberă
	if _summon_portal != null and is_instance_valid(_summon_portal):
		_summon_portal.queue_free()
	_summon_portal = null

func _spawn_one() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var e := ENEMY.instantiate()
	var unghi := randf() * TAU
	_player.get_parent().add_child(e)
	e.global_position = _player.global_position \
		+ Vector2(cos(unghi), sin(unghi)) * BURST_RADIUS * randf_range(0.85, 1.25)

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

# Cere podelei să treacă pe cărămidă (și înapoi). Nodul `Ground` se anunță în grupul „ground".
func _set_ground_nether(on: bool) -> void:
	var ground := get_tree().get_first_node_in_group("ground")
	if ground != null and ground.has_method("set_nether"):
		ground.set_nether(on)

# Oprește/repornește generatoarele de decor. Nu e destul să le ascunzi: hitbox-urile ar
# rămâne și te-ai lovi de copaci invizibili. Deci le și golim de ce au încărcat, iar `_loaded`
# (dicționarul lor de chunk-uri) trebuie golit odată cu ele — altfel, la repornire, ar crede
# că bucățile alea există deja și lumea ar rămâne goală pe veci. (Identic cu `limbo.gd`.)
func _set_world_enabled(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var world := player.get_parent()
	if world == null:
		return
	for n in WORLD_NODES:
		_toggle_generator(world.get_node_or_null(n), on)
	# potecile stau lângă `World`, nu în el
	var root := world.get_parent()
	if root != null:
		for n in ROOT_NODES:
			_toggle_generator(root.get_node_or_null(n), on)

func _toggle_generator(node: Node, on: bool) -> void:
	if node == null:
		return
	node.visible = on
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if not on:
		for c in node.get_children():
			c.queue_free()
		if node.get("_loaded") != null:
			node.set("_loaded", {})

func _mmss(secunde: float) -> String:
	var s := int(ceil(maxf(0.0, secunde)))   # ceil: la intrare scrie 7:00, nu 6:59
	return "%d:%02d" % [s / 60, s % 60]

func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
