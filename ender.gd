extends CanvasLayer

# ENDER — a treia dimensiune, sora mai adâncă a Nether-ului (`nether.gd`). Intri apăsând E pe o
# FÂNTÂNĂ Ender (`portal_ender.gd`) — apar toate după ce l-ai bătut pe Saratalin, pe locurile
# portalurilor Nether. Ieși apăsând E pe aceeași fântână, care rămâne acolo unde ai aterizat —
# dar NUMAI după ce cade **CELESTO** (`celesto.gd`). Cât trăiește el, fântâna e o groapă cu apă.
# (Până pe 2026-08-04 boss-ul de aici era „Undead Executioner Puppet"; arta lui a fost înlocuită.)
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
# Din 2026-08-04 Ender-ul ÎȘI ARE inamicii lui (`enemy_ender.tscn`, arta pusă de Răzvan): de două
# ori mai iuți decât creaturile Nether (380 față de 190) și cu damage dublu la contact
# (`damage_mult = 2.0`). Îi aduce și `spawner.gd`, care întreabă grupul „ender".

const ENEMY := preload("res://enemy_ender.tscn")
const BOSS := preload("res://celesto.tscn")

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
const WORLD_NODES := ["Props", "Rocks", "DesertStructures", "Statues", "Portals", "Chests", "EGTs", "Monuments"]
const ROOT_NODES := ["Paths"]   # frați ai lui `World` din main.tscn (potecile)
# Generatoare care merg PE DOS: stinse în lumea normală, aprinse doar cât ești aici. Deocamdată
# unul singur — statuile de schimb (`ender_statues.gd`). NU au ce căuta în lista de sus: acolo
# ar face exact invers decât trebuie. În `main.tscn` pornesc stinse (`process_mode = 4`).
const ENDER_ONLY_NODES := ["EnderStatues"]

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

# PUBLIC, și NU se stinge la ieșire: „l-ai bătut pe Celesto măcar o dată în runda asta".
# `_boss_invins` de mai sus se resetează la fiecare intrare (el ține ușa închisă); ăsta rămâne
# aprins pe tot restul rundei, fiindcă îl citește `spawner.gd`: după ce boss-ul cade, creaturile
# lui încep să curgă și în LUMEA NORMALĂ (cerut pe 2026-08-05). Sora lui e `nether.gd::escaped`.
var celesto_invins := false

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
	# O scoatem din generatorul de fântâni (`portals.gd`) și o mutăm direct în `World`: peste
	# două rânduri golim decorul, iar golirea șterge tot ce ține de generatoare — adică ne-ar
	# lua chiar ieșirea de sub picioare. `reparent` păstrează poziția din lume.
	# La întoarcerea victorioasă se scufundă ea și se oprește generatorul (`_inchide_fantana`),
	# deci nu rămâne nicio dublură pe locul ăsta.
	var world := player.get_parent()
	if world != null and _fantana.get_parent() != world:
		_fantana.reparent(world)
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

	# Sunet: Ender-ul n-are muzică proprie (n-avem fișiere), deci împrumută bucla Nether-ului.
	Audio.stop_forest_ambient()
	Audio.play("teleport", TELEPORT_DB, 0.0)
	Audio.play_nether_music()
	_clock.text = _mmss(ENDER_TIME)
	_clock.add_theme_color_override("font_color", CLOCK_COLOR)
	_clock.visible = true
	_flash_screen()

	# ⚠️ Anunțul „THE ENDER" NU se dă aici, ci la capătul cinematicii (`_cutscene_gata`). Bannerul
	# HUD-ului e un tween al unui nod pauzabil: pornit acum, ar îngheța la jumătatea „pop"-ului
	# și ar sta așa, pe jumătate transparent, peste tot filmulețul.
	_cutscene_celesto()   # boss-ul apare cu cinematică; inamicii și anunțul vin după ea

# ---------- IEȘIRE ----------
# `anunt = true`  → ieșire VOLUNTARĂ, apăsând E pe fântâna de întoarcere.
# `anunt = false` → ieșire FORȚATĂ: ai murit, sau player-ul nu mai există. Aia trece mereu,
#                   altfel ai rămâne blocat mort într-o dimensiune fără decor.
func exit_ender(anunt: bool = true) -> void:
	if not active:
		return
	if anunt and not _boss_invins:
		_announce("CELESTO STILL STANDS", "The well will not open until it falls")
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
	# Cât ține cinematica de intrare suntem pe `PROCESS_MODE_ALWAYS` (ca să meargă tween-urile),
	# deci ajungem aici DEȘI jocul e înghețat. Ieșim: cronometrul Ender-ului n-are ce să curgă
	# în secundele alea, altfel ai plăti filmulețul din cele 6 minute.
	if _cut_activ:
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

# Chemată de `celesto.gd` când boss-ul moare: de aici încolo fântâna te lasă să pleci.
func boss_invins() -> void:
	if not active or _boss_invins:
		return
	_boss_invins = true
	celesto_invins = true   # de aici încolo creaturile lui apar și în lumea normală
	_announce("CELESTO FALLS", "Press E at the well to go back")
	Audio.play("levelup", -2.0)

# Ai ieșit învingător → FÂNTÂNILE SE ÎNCHID PE RESTUL RUNDEI. Cea prin care ai ieșit intră în
# pământ cu cutremur (e deja mutată în `World` de la intrare, deci se vede scufundându-se),
# celelalte de pe hartă dispar odată cu generatorul, care nu mai naște nimic (`portals.gd`).
# Un Ender pe rundă, ca Nether-ul — de aici încolo nu mai ai unde intra.
#
# Se cheamă doar de pe drumul VOLUNTAR de ieșire, care există numai după ce boss-ul a căzut.
func _inchide_fantana() -> void:
	var portals := _generator("Portals")
	if portals != null and portals.has_method("opreste"):
		portals.opreste()
	if _fantana == null or not is_instance_valid(_fantana):
		return
	Audio.play("earthquake", Audio.QUAKE_DB, 0.0)
	_zguduie_camera()
	_fantana.intra_in_pamant()
	_fantana = null

# Nodul unui generator de decor din `World` (Props, Rocks, Portals...). Ca în `nether.gd`.
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

# ---------- dificultate ----------
# Identic cu Nether-ul: două drepte, luăm maximul (deci nu scade niciodată brusc).
func _diff_time() -> float:
	var t := _entry_diff_time + _elapsed
	if _elapsed >= ENDER_TIME:
		t = maxf(t, Difficulty.RUN_LENGTH + (_elapsed - ENDER_TIME))
	return t

# Unde e fântâna prin care ai intrat (și pe unde ieși). O cere `ender_statues.gd`, ca să-și
# așeze statuile într-un inel în jurul ei. Vector2.INF = încă nu se știe.
func portal_pos() -> Vector2:
	if _fantana != null and is_instance_valid(_fantana):
		return _fantana.global_position
	return Vector2.INF

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

# ---------- CINEMATICA DE INTRARE ----------
# Cerută de Răzvan pe 2026-08-04 („vreau ca Celesto sa aiba un cutscene cand intrii in ender, nu
# sa se spawneze direct, si vreau sa intre in cadru bara de hp cu numele lui asa slow cinematic")
# și REFĂCUTĂ pe 2026-08-05: „cand intrii in ender se opreste totul si se da zoom in pe el cum se
# teleporteaza stanga dreapta de 2-3 ori si vreau ca bara de hp si numele sa fie sus".
#
# Cum decurge, în cinci bătăi:
#   1. jocul ÎNGHEAȚĂ și camera intră pe locul gol de deasupra ta, strângând zoom-ul;
#   2. Celesto SE MATERIALIZEAZĂ acolo, transparent → opac;
#   3. bara lui coboară încet din marginea de sus, cu numele aprinzându-se odată cu ea;
#   4. se teleportează STÂNGA-DREAPTA de `CUT_SARITURI` ori, în cadrul strâns — camera stă pe
#      loc, el clipește dintr-o parte în alta, ca să se vadă că ăsta e trucul lui;
#   5. se stinge, camera iese, jocul repornește, el te așteaptă departe în inel și abia atunci
#      curg inamicii.
#
# ⚠️ Pauza e ADEVĂRATĂ (`get_tree().paused`), cu aceleași trei precauții ca la cinematica lui
# Saratalin (`saratalin.gd::_cinematica_faza2`, citește-o întâi — ăsta e același tipar):
#   • ne punem NOI pe `PROCESS_MODE_ALWAYS`, altfel tween-urile create aici ar sta și ele;
#   • `Fx` e autoload ALWAYS (numerele de damage) → îl trecem pe „pauzabil" cât ține treaba;
#   • `position_smoothing` al camerei se face în procesarea ei internă, care NU merge pe pauză —
#     lăsat pornit, camera ar rămâne blocată tot filmulețul.
# Și boss-ul primește ALWAYS: e adormit (`_physics_process` iese din prima), dar sclipirea lui
# albastră de teleportare e un tween al LUI, care altfel ar îngheța la mijloc, în albastru.
#
# `_cut_activ` ține `_process`-ul nostru mut: cronometrul Ender-ului NU trebuie să curgă în
# secundele astea, altfel ai pierde din cele 6 minute uitându-te la un filmuleț.
#
# Timpii sunt în secunde, unul după altul; schimbă-i liniștit.
const CUT_APARE := 1.1        # cât durează materializarea lui
const CUT_PANA_LA_BARA := 0.5 # pauză după ce s-a materializat, înainte să coboare bara
const CUT_BARA := 1.7         # cât coboară bara („slow cinematic")
const CUT_PANA_LA_SARITURI := 0.5   # cât se uită la tine înainte să înceapă să sară
const CUT_SARITURI := 3       # de câte ori se teleportează stânga-dreapta
const CUT_SARE_LAT := 170.0   # câți pixeli în lateral sare de fiecare dată
const CUT_SARE_PAUZA := 0.42  # cât stă într-un capăt înainte să sară în celălalt
const CUT_ZOOM := 2.0         # de câte ori strânge camera pe el
const CUT_ZOOM_IN := 0.7      # cât durează apropierea
const CUT_ZOOM_OUT := 0.6     # ...și depărtarea la loc
const CUT_STINGE := 0.35      # cât durează dispariția lui de la final
# ⚠️ Apare DEASUPRA ta pe ecran, nu „în direcția în care te uiți". Am încercat varianta a doua și
# se vede pe captură de ce nu merge: dacă te uiți în jos (cum stai implicit la aterizare), el
# cade fix peste banda de sus. Sus e curat și e oricum încadrarea clasică de „apare boss-ul".
const CUT_DISTANTA := 300.0   # la câți pixeli deasupra ta apare, cât ține cinematica

var _cut_activ := false      # cât e true, `_process` stă (cronometrul Ender-ului nu curge)

func _cutscene_celesto() -> void:
	if _player == null or _fantana == null:
		return
	var world := _player.get_parent()
	if world == null:
		return
	_boss = BOSS.instantiate()
	_boss.adoarme()          # ÎNAINTE de add_child: `_ready` nu mai cere bara și nu se mișcă
	world.add_child(_boss)
	_boss.process_mode = Node.PROCESS_MODE_ALWAYS   # ca sclipirile lui să meargă pe pauză
	var centru := _player.global_position + Vector2(0, -CUT_DISTANTA)
	_boss.global_position = centru
	var anim := _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim != null:
		anim.modulate.a = 0.0

	# --- 1) îngheț total ---
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

	# --- 2) camera intră pe locul lui, iar el se materializează acolo ---
	Audio.play("celesto_teleport", -2.0, 0.0)
	var t := _cut_tween()
	t.set_parallel(true)
	# Bătaia de bază, care ține tween-ul viu chiar dacă n-ar exista nici camera, nici sprite-ul.
	# ⚠️ Un `Tween` fără nicio comandă se anulează singur și NU-și mai trimite `finished` — adică
	# `await`-ul de mai jos ar aștepta la nesfârșit, cu jocul înghețat. Merită linia asta.
	t.tween_interval(CUT_APARE)
	if cam != null:
		t.tween_property(cam, "offset", centru - _player.global_position, CUT_ZOOM_IN) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM, CUT_ZOOM_IN) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if anim != null:
		t.tween_property(anim, "modulate:a", 1.0, CUT_APARE)
	await t.finished

	# --- 3) bara coboară din marginea de sus ---
	await _cut_asteapta(CUT_PANA_LA_BARA)
	if is_instance_valid(_boss):
		var bara := get_tree().get_first_node_in_group("boss_bar")
		if bara != null and bara.has_method("arata_cinematic"):
			bara.arata_cinematic(_boss.nume, _boss.max_hp, CUT_BARA)
	await _cut_asteapta(CUT_BARA + CUT_PANA_LA_SARITURI)

	# --- 4) stânga-dreapta, în cadrul strâns ---
	# Camera NU îl urmărește: stă pe `centru`, iar el clipește în stânga și în dreapta ei. Dacă
	# l-ar urma, saltul n-ar mai fi vizibil deloc — ar părea că lumea se mișcă, nu el.
	for i in CUT_SARITURI:
		var semn := 1.0 if i % 2 == 0 else -1.0
		if is_instance_valid(_boss):
			_boss.global_position = centru + Vector2(semn * CUT_SARE_LAT, 0.0)
			Audio.play("celesto_teleport", -2.0, 0.0)
			if _boss.has_method("puf"):
				_boss.puf()
		await _cut_asteapta(CUT_SARE_PAUZA)

	# --- 5) se stinge, camera iese, jocul repornește ---
	Audio.play("celesto_teleport", -2.0, 0.0)
	if anim != null:
		await _cut_tween().tween_property(anim, "modulate:a", 0.0, CUT_STINGE).finished
	if cam != null:
		var t2 := _cut_tween()
		t2.set_parallel(true)
		t2.tween_property(cam, "offset", offset_vechi, CUT_ZOOM_OUT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t2.tween_property(cam, "zoom", zoom_vechi, CUT_ZOOM_OUT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await t2.finished
		cam.position_smoothing_enabled = neted_vechi

	Fx.process_mode = fx_vechi
	if _player != null and is_instance_valid(_player) and _player.fire_timer != null:
		_player.fire_timer.start()
	get_tree().paused = false
	process_mode = mod_vechi
	_cut_activ = false
	if is_instance_valid(_boss) and anim != null:
		anim.modulate.a = 1.0
	_cutscene_gata()

# Tween care merge CU JOCUL PE PAUZĂ. E creat pe noi (suntem ALWAYS cât ține cinematica), iar
# `TWEEN_PAUSE_PROCESS` o spune pe față, ca să nu depindă de starea nodului dacă se schimbă.
func _cut_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

# Pauză care curge pe pauză. `create_timer` are `process_always = true` implicit, dar aici se
# vede intenția — dacă vreodată devine `false`, cinematica ar rămâne blocată pentru totdeauna,
# CU JOCUL ÎNGHEȚAT. Merită scris pe față.
func _cut_asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde, true).timeout

# Ultima bătaie: te așteaptă în inel. De aici încolo totul e ca înainte — busola arată spre el,
# inamicii curg, lupta e a ta.
func _cutscene_gata() -> void:
	if not active:
		return
	if _boss != null and is_instance_valid(_boss):
		_boss.process_mode = Node.PROCESS_MODE_INHERIT   # înapoi sub pauza normală a jocului
		_boss.global_position = _loc_boss()
		_boss.trezeste()
	_announce("THE ENDER", "Kill Celesto to leave")
	for i in BURST:
		_spawn_one()

# Unde îl așteaptă lupta: un INEL în jurul fântânii de întoarcere. Nu îți cade în brațe, dar nici
# nu-l cauți o zi — busola te duce la el. `sqrt` ca punctele să fie împrăștiate uniform pe
# SUPRAFAȚĂ: cu o distanță pur aleatoare s-ar înghesui spre marginea interioară.
func _loc_boss() -> Vector2:
	var unghi := randf() * TAU
	var d := sqrt(lerpf(BOSS_MIN_DIST * BOSS_MIN_DIST, BOSS_MAX_DIST * BOSS_MAX_DIST, randf()))
	return _fantana.global_position + Vector2(cos(unghi), sin(unghi)) * d

# ---------- ajutoare ----------

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
	# ...și cele care merg invers: aprinse exact cât celelalte sunt stinse.
	for n in ENDER_ONLY_NODES:
		_toggle_generator(world.get_node_or_null(n), not on)
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
