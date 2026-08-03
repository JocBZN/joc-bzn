extends CanvasLayer

# ENDER — a treia dimensiune, sora mai adâncă a Nether-ului (`nether.gd`). Intri apăsând E pe
# FÂNTÂNA Ender (`portal_ender.gd`), care apare o singură dată pe rundă, în lumea normală, fix
# unde s-a scufundat portalul Nether-ului după ce l-ai bătut pe Saratalin. Ieși apăsând E pe
# copia ei care rămâne acolo unde ai aterizat — dar NUMAI după ce cade Undead Executioner
# Puppet (`executioner.gd`). Cât trăiește el, fântâna e doar o groapă cu apă.
#
# Făcut EXACT ca Nether-ul și ca Limbo: NU se încarcă altă scenă. Rămâi în aceeași lume, la
# aceleași coordonate, dar:
#   • podeaua devine nebuloasă (`harta/Portal Ender/misc_nebula.png`, vezi `ground.gd`);
#   • generatoarele de decor sunt oprite și golite → o câmpie de stele, goală;
#   • cronometrul rundei ÎNGHEAȚĂ și pornește unul propriu, de ENDER_TIME;
#   • inamicii lasă XP_BONUS × XP.
# Așa nu pierzi nimic din rundă (upgrade-uri, XP, nivel, poziție) și te întorci exact unde erai.
#
# La 0:00 începe ENDER SWARM: dificultatea sare pe exponențială (ca Final Swarm-ul rundei),
# cronometrul se face roșu și numără în sus.
#
# ⚠️ Ender-ul NU are inamici proprii — nu există artă pentru ei. Curg creaturile violete ale
# Nether-ului (`enemy_nether.tscn`), aduse de `spawner.gd`, care întreabă și grupul „ender".

const ENEMY := preload("res://enemy_nether.tscn")
const BOSS := preload("res://executioner.tscn")

# --- reglaje (schimbă-le liniștit) ---
const ENDER_TIME := 360.0       # 6:00 — cât ține faza „normală" înainte de Ender Swarm
const XP_BONUS := 3.0           # de câte ori mai mult XP lasă inamicii de aici (Nether-ul dă 2)
const BURST := 20               # câți inamici apar DEODATĂ la intrare
const BURST_RADIUS := 640.0     # la ce distanță de tine apar (cerc în jurul tău)
const FLASH := 0.45             # cât ține fulgerul alb de teleportare
const CLOCK_SIZE := 64
const CLOCK_COLOR := Color(0.45, 0.78, 1.0)       # albastru rece, ca nebuloasa
const CLOCK_WARN := Color(1.0, 0.82, 0.20)        # galben — ultimul minut
const CLOCK_SWARM := Color(1.0, 0.10, 0.10)       # roșu — Ender Swarm
const COMPASS_MARGIN := 96.0
const TELEPORT_DB := -4.0
# Unde îl punem pe boss: într-un INEL în jurul fântânii de întoarcere. Nu îți cade în brațe la
# aterizare, dar nici nu-l cauți o zi — busola te duce la el.
const BOSS_MIN_DIST := 700.0
const BOSS_MAX_DIST := 1100.0
# Cutremurul de la închiderea fântânii (aceleași cifre ca la Nether, să se simtă la fel)
const SHAKE_STRENGTH := 24.0
const SHAKE_TIME := 0.9

# Identic cu lista din `nether.gd`. ⚠️ Când adaugi un generator nou în `World` (main.tscn),
# treci-l ȘI aici, ȘI în `nether.gd` — altfel rămâne aprins și-i vezi obiectele plutind
# într-o dimensiune în care n-au ce căuta.
const WORLD_NODES := ["Props", "Rocks", "DesertStructures", "Statues", "Portals", "Chests", "EGTs"]
const ROOT_NODES := ["Paths"]   # frați ai lui `World` din main.tscn (potecile)

var active := false

var _flash: ColorRect
var _clock: Label
var _arrow: Label            # săgeata care arată încotro e obiectivul
var _dist: Label             # distanța până la el (px de lume)
var _player: Node2D = null
# Fântâna prin care ai intrat. NU facem o a doua pentru întoarcere (ca Nether-ul, care își pune
# un portal nou): dimensiunile împart aceleași coordonate, deci fântâna din lume e deja exact
# acolo unde aterizezi. Două noduri suprapuse ar însemna două „Press E" pe același loc, iar
# `interact_ui.gd` ar putea alege exact pe cel greșit. Deci o împrumutăm: cât ești dincolo, îi
# aprindem `retur`, iar la ieșire i-l stingem la loc.
var _fantana: Node2D = null
var _boss: Node2D = null
var _elapsed := 0.0          # de câte secunde ești în Ender
var _entry_diff_time := 0.0  # în ce secundă a rundei ai intrat
var _swarm_announced := false
var _boss_invins := false    # cât e `false`, fântâna de întoarcere nu te lasă să pleci

func _ready() -> void:
	add_to_group("ender")
	layer = 4   # ca Nether-ul: peste lume, sub textul de interacțiune

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

	# Busola. Fără ea te pierzi: Ender-ul e o câmpie infinită, identică peste tot.
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
# Chemată din `portal_ender.gd` (`invoca()`) când apeși E pe fântână. Primim NODUL fântânii,
# nu doar poziția lui: cât ești dincolo, el devine ieșirea (vezi `_fantana`).
func enter(player: Node2D, fantana: Node2D) -> void:
	if active or player == null or player.dead or fantana == null:
		return
	# Nu intrăm peste Limbo sau peste Nether: și ele opresc decorul și rescriu dificultatea.
	for g in ["limbo", "nether"]:
		var alta := get_tree().get_first_node_in_group(g)
		if alta != null and alta.active:
			return
	active = true
	_player = player
	_fantana = fantana
	_fantana.retur = true     # de aici încolo, E pe ea înseamnă „ieși"
	_fantana_cosmica(true)    # și își schimbă și pielea: halou violet, piatră mai stinsă
	_elapsed = 0.0
	_entry_diff_time = Difficulty.time
	_swarm_announced = false
	_boss_invins = false

	_clear_enemies()          # inamicii lumii normale nu vin cu tine
	_set_world_enabled(false)
	_set_ground_ender(true)
	_set_atmosphere("ender")

	# cronometrul rundei stă pe loc; tăria inamicilor o dictăm noi, din `_diff_time()`
	Difficulty.frozen = true
	Difficulty.mult_time_override = _diff_time()
	Difficulty.xp_bonus = XP_BONUS

	_spawn_boss()

	# Sunet: Ender-ul n-are muzică proprie (n-avem fișiere), deci împrumută bucla Nether-ului.
	Audio.stop_forest_ambient()
	Audio.play("teleport", TELEPORT_DB, 0.0)
	Audio.play_nether_music()
	_clock.text = _mmss(ENDER_TIME)
	_clock.add_theme_color_override("font_color", CLOCK_COLOR)
	_clock.visible = true
	_flash_screen()

	for i in BURST:
		_spawn_one()

	_announce("THE ENDER", "Kill the Executioner to leave")

# ---------- IEȘIRE ----------
# `anunt = true`  → ieșire VOLUNTARĂ, apăsând E pe fântâna de întoarcere.
# `anunt = false` → ieșire FORȚATĂ: ai murit, sau player-ul nu mai există. Aia trece mereu,
#                   altfel ai rămâne blocat mort într-o dimensiune fără decor.
func exit_ender(anunt: bool = true) -> void:
	if not active:
		return
	if anunt and not _boss_invins:
		_announce("THE PUPPET STILL DANCES", "The well will not open until it falls")
		Audio.play("levelup", -6.0)
		return
	active = false
	_clear_enemies()
	_set_world_enabled(true)
	_set_ground_ender(false)
	_set_atmosphere("")
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0
	Difficulty.xp_bonus = 1.0
	_free_boss()
	# fântâna redevine intrare — dacă ai murit, oricum se termină runda, dar n-o lăsăm
	# într-o stare în care „E" ar însemna ieșire dintr-o dimensiune în care nu mai ești
	if _fantana != null and is_instance_valid(_fantana):
		_fantana.retur = false
		_fantana_cosmica(false)
	_clock.visible = false
	_arrow.visible = false
	_dist.visible = false
	Audio.play_forest_ambient()
	Audio.restore_world_music()
	if anunt:
		Audio.play("teleport", TELEPORT_DB, 0.0)
		_flash_screen()
		_announce("BACK", "The well is closing")
		_inchide_fantana()

func _process(delta: float) -> void:
	if not active:
		return
	# Ai murit în Ender → ieșim curat, fără anunț. `player.die()` ne scoate el înainte;
	# asta e plasa de siguranță.
	if _player == null or not is_instance_valid(_player) or _player.dead:
		exit_ender(false)
		return
	_elapsed += delta
	Difficulty.mult_time_override = _diff_time()
	_update_clock()
	_update_compass()
	if not _swarm_announced and _elapsed >= ENDER_TIME:
		_swarm_announced = true
		_announce("ENDER SWARM", "The well still works. For now.")
		Audio.play("levelup", -2.0)

# Chemată de `executioner.gd` când boss-ul moare: de aici încolo fântâna te lasă să pleci.
func boss_invins() -> void:
	if not active or _boss_invins:
		return
	_boss_invins = true
	_announce("THE STRINGS ARE CUT", "Press E at the well to go back")
	Audio.play("levelup", -2.0)

# Ai ieșit învingător → fântâna din lume se scufundă. Un Ender pe rundă, ca Nether-ul.
# Se cheamă doar de pe drumul VOLUNTAR de ieșire, care există numai după ce boss-ul a căzut.
func _inchide_fantana() -> void:
	if _fantana == null or not is_instance_valid(_fantana):
		return
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)
	_zguduie_camera()
	_fantana.intra_in_pamant()
	_fantana = null

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

# ---------- dificultate ----------
# Identic cu Nether-ul: două drepte, luăm maximul (deci nu scade niciodată brusc).
func _diff_time() -> float:
	var t := _entry_diff_time + _elapsed
	if _elapsed >= ENDER_TIME:
		t = maxf(t, Difficulty.RUN_LENGTH + (_elapsed - ENDER_TIME))
	return t

# Câte secunde mai ai până la Ender Swarm (0 după ce a început).
func time_left() -> float:
	return maxf(0.0, ENDER_TIME - _elapsed)

# ---------- ecran ----------
func _update_clock() -> void:
	if _elapsed >= ENDER_TIME:
		_clock.text = "+" + _mmss(_elapsed - ENDER_TIME)
		_clock.add_theme_color_override("font_color", CLOCK_SWARM)
		return
	var ramas := ENDER_TIME - _elapsed
	_clock.text = _mmss(ramas)
	_clock.add_theme_color_override("font_color", CLOCK_WARN if ramas <= 60.0 else CLOCK_COLOR)

# Spre ce arată busola: boss-ul cât trăiește, fântâna după ce cade. N-are rost să te trimită
# la o fântână care oricum nu se deschide.
func _tinta_busola() -> Node2D:
	if not _boss_invins and _boss != null and is_instance_valid(_boss):
		return _boss
	return _fantana

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
# Boss-ul te așteaptă în inelul din jurul fântânii. `sqrt` ca punctele să fie împrăștiate
# uniform pe SUPRAFAȚĂ: cu o distanță pur aleatoare s-ar înghesui spre marginea interioară.
func _spawn_boss() -> void:
	if _player == null or _fantana == null:
		return
	var world := _player.get_parent()
	if world == null:
		return
	var unghi := randf() * TAU
	var d := sqrt(lerpf(BOSS_MIN_DIST * BOSS_MIN_DIST, BOSS_MAX_DIST * BOSS_MAX_DIST, randf()))
	_boss = BOSS.instantiate()
	world.add_child(_boss)
	_boss.global_position = _fantana.global_position + Vector2(cos(unghi), sin(unghi)) * d

# Boss-ul se șterge singur când moare, deci aici poate fi deja liber.
func _free_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		_boss.queue_free()
	_boss = null

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

# Cere podelei să treacă pe nebuloasă (și înapoi). Nodul `Ground` e în grupul „ground".
func _set_ground_ender(on: bool) -> void:
	var ground := get_tree().get_first_node_in_group("ground")
	if ground != null and ground.has_method("set_ender"):
		ground.set_ender(on)

# Culoarea lumii + stelele de pe ecran. Ca la Nether: tot ce ține de „cum arată dincolo" stă
# într-un singur loc, în `atmosphere.gd` — aici doar spunem în ce dimensiune suntem.
# Fântâna e o singură bucată de artă în două lumi: pe iarbă are nevoie de umbră, pe nebuloasă
# de lumină. `has_method` fiindcă `_fantana` e tipizat ca `Node2D` — la fel ca `_set_atmosphere`.
func _fantana_cosmica(on: bool) -> void:
	if _fantana != null and is_instance_valid(_fantana) and _fantana.has_method("set_cosmic"):
		_fantana.set_cosmic(on)

func _set_atmosphere(kind: String) -> void:
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm != null and atm.has_method("set_dimension"):
		atm.set_dimension(kind)

# Oprește/repornește generatoarele de decor. Nu e destul să le ascunzi: hitbox-urile ar rămâne
# și te-ai lovi de copaci invizibili. Deci le și golim, iar `_loaded` (dicționarul lor de
# chunk-uri) trebuie golit odată cu ele — altfel, la repornire, ar crede că bucățile alea
# există deja și lumea ar rămâne goală pe veci. (Identic cu `nether.gd` și `limbo.gd`.)
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
	var s := int(ceil(maxf(0.0, secunde)))   # ceil: la intrare scrie 6:00, nu 5:59
	return "%d:%02d" % [s / 60, s % 60]

func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
