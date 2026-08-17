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
# ⚠️ La INTRARE fulgerul e mult mai scurt. Motivul se vede pe captură (2026-08-17): cinematica lui
# Celesto începe în aceeași clipă, iar 0,45s de alb peste ea înseamnă că bubuitura de îngheț, benzile
# și prima jumătate din materializarea lui se petrec în spatele unui geam lăptos — adică nu se văd.
# 0,18s e tot un fulger, dar unul care se dă la o parte la timp. La IEȘIRE rămâne cel lung: acolo nu
# mai are peste ce să stea.
const FLASH_CUT := 0.18
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
const WORLD_NODES := ["Props", "Rocks", "Bushes", "DesertStructures", "Statues", "Portals", "Chests", "EGTs", "Monuments", "AlbaNeagras", "Dubiosi"]
const ROOT_NODES := ["Paths"]   # frați ai lui `World` din main.tscn (potecile)
# Generatoare care merg PE DOS: stinse în lumea normală, aprinse doar cât ești aici. Deocamdată
# unul singur — statuile de schimb (`ender_statues.gd`). NU au ce căuta în lista de sus: acolo
# ar face exact invers decât trebuie. În `main.tscn` pornesc stinse (`process_mode = 4`).
const ENDER_ONLY_NODES := ["EnderStatues"]

var active := false

var _flash: ColorRect
var _banda_sus: ColorRect    # benzile cinematice, numai în cinematica lui Celesto
var _banda_jos: ColorRect
var _vinieta: TextureRect    # întunecarea marginilor, tot pentru ea
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
var _suspendat := false      # ești în Limbo, murit AICI — vezi `suspenda()`

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

	# Cadrul cinematicii de intrare. Făcut o dată, aici, și ținut ascuns tot restul jocului —
	# se aprinde numai în `_cutscene_celesto`. Vinieta ÎNAINTEA benzilor, ca benzile să rămână
	# deasupra ei (altfel marginile de sus și de jos ar fi ieșit cenușii, nu negre).
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
	# Nu intrăm peste Limbo, Nether sau Pușcărie: și ele opresc decorul și rescriu dificultatea.
	for g in ["limbo", "nether", "prison"]:
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
	_margine(true)            # de aici încolo lumea are un capăt, centrat pe fântână
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
	_flash_screen(FLASH_CUT)   # scurt: peste el începe imediat cinematica (vezi FLASH_CUT)

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
	# Ai murit în Limbo, iar Limbo ne ținea pe pauză → ne trezim întâi (vezi `suspenda`), ca
	# ieșirea de mai jos să găsească fântâna și boss-ul la locul lor, nu ascunse.
	if _suspendat:
		reia()
	if anunt and not _boss_invins:
		_announce("CELESTO STILL STANDS", "The well will not open until it falls")
		Audio.play("levelup", -6.0)
		return
	active = false
	_clear_enemies()
	_set_world_enabled(true)
	_set_ground_ender(false)
	_margine(false)
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
		_announce("BACK", "The wells have become gates")
		_inchide_fantana()

func _process(delta: float) -> void:
	if not active or _suspendat:
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

# ---------- PAUZĂ CÂT EȘTI ÎN LIMBO ----------
# Identic cu `nether.gd::suspenda()` — citește comentariul lung de acolo. Diferențele Ender-ului:
# ieșirea e chiar fântâna prin care ai intrat (nu un portal nou), boss-ul e al nostru (`_boss`),
# iar statuile de schimb (`ENDER_ONLY_NODES`) merg pe dos față de restul decorului, deci trebuie
# stinse de mână — dar FĂRĂ să le golim: altfel cele la care ai făcut deja schimb s-ar naște din
# nou la întoarcere, adică exact resetarea pe care Răzvan a cerut să n-o mai facem.
func suspenda() -> void:
	if not active or _suspendat:
		return
	_suspendat = true
	_set_ground_ender(false)
	_margine(false)                # Limbo n-are margine: e altă lume, cu podeaua lui
	_set_atmosphere("")
	_set_ender_only(false)
	Difficulty.xp_bonus = 1.0      # bonusul e al Ender-ului, nu al Limbo-ului
	_clock.visible = false
	_arrow.visible = false
	_dist.visible = false
	_arata_obiect(_fantana, false)
	_park_boss(true)
	_bara_boss(false)

func reia() -> void:
	if not _suspendat:
		return
	_suspendat = false
	_set_ground_ender(true)
	_margine(true)
	_set_atmosphere("ender")
	_set_ender_only(true)
	Difficulty.frozen = true
	Difficulty.mult_time_override = _diff_time()
	Difficulty.xp_bonus = XP_BONUS
	_clock.visible = true
	_update_clock()
	_arata_obiect(_fantana, true)
	_park_boss(false)
	_bara_boss(true)

# Statuile de schimb: stinse cât ești în Limbo, aprinse la loc când te întorci. `false` pe al
# treilea argument = NU le golim de copii, deci inelul de statui rămâne exact cum l-ai lăsat.
func _set_ender_only(on: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var world := _player.get_parent()
	if world == null:
		return
	for n in ENDER_ONLY_NODES:
		_toggle_generator(world.get_node_or_null(n), on, false)

# Ascunde/arată un obiect din lume. `PROCESS_MODE_DISABLED` îi scoate și corpul din spațiul de
# fizică (`CollisionObject2D.disable_mode` e „remove" implicit), deci nu te lovești de o fântână
# invizibilă cât ești în Limbo.
func _arata_obiect(n: Node2D, on: bool) -> void:
	if n == null or not is_instance_valid(n):
		return
	n.visible = on
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

# Celesto, cât ești în Limbo. Îl scoatem din grupul „enemy" fiindcă exact ăla e grupul pe care îl
# mătură `limbo.gd::_clear_enemies()` — fără asta, boss-ul adus la jumătate de viață ar dispărea,
# iar fântâna n-ar mai avea cum să se deschidă vreodată.
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

# Ai ieșit învingător → FÂNTÂNILE SE ÎNCHID PE RESTUL RUNDEI. Cea prin care ai ieșit intră în
# pământ cu cutremur (e deja mutată în `World` de la intrare, deci se vede scufundându-se),
# celelalte de pe hartă dispar odată cu generatorul, care nu mai naște nimic (`portals.gd`).
# Un Ender pe rundă, ca Nether-ul — de aici încolo nu mai ai unde intra.
#
# Se cheamă doar de pe drumul VOLUNTAR de ieșire, care există numai după ce boss-ul a căzut.
func _inchide_fantana() -> void:
	var portals := _generator("Portals")
	# ⚠️ SCHIMBAT pe 2026-08-17: până acum aici se chema `opreste()` și runda se termina cu Ender-ul.
	# Acum locurile astea trec la a TREIA vârstă și scot PORȚI DE PUȘCĂRIE (`prison.gd`) — exact așa
	# se ține regula „pușcăria nu e accesibilă până n-ai jucat celelalte dimensiuni". Închiderea
	# definitivă s-a mutat cu o dimensiune mai încolo, în `prison.gd::_inchide_poarta`.
	if portals != null and portals.has_method("treci_pe_prison"):
		portals.treci_pe_prison()
	elif portals != null and portals.has_method("opreste"):
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

func _flash_screen(durata: float = FLASH) -> void:
	_flash.visible = true
	_flash.modulate.a = 1.0
	# ⚠️ Merge ȘI pe pauză: la intrare, cinematica lui Celesto îngheață jocul în aceeași clipă, iar
	# un tween pauzabil ar fi lăsat ecranul ALB tot filmulețul.
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_flash, "modulate:a", 0.0, durata)
	t.tween_callback(func(): _flash.visible = false)

# ---------- CINEMATICA DE INTRARE ----------
# Cerută de Răzvan pe 2026-08-04 („vreau ca Celesto sa aiba un cutscene cand intrii in ender, nu
# sa se spawneze direct, si vreau sa intre in cadru bara de hp cu numele lui asa slow cinematic")
# și REFĂCUTĂ pe 2026-08-05: „cand intrii in ender se opreste totul si se da zoom in pe el cum se
# teleporteaza stanga dreapta de 2-3 ori si vreau ca bara de hp si numele sa fie sus".
#
# REFĂCUTĂ A TREIA OARĂ pe 2026-08-17, cerută de Răzvan („nu îmi place animația de la Celesto de
# la început … fă animația să fie topul topului din domeniul gaming-ului"), odată cu biblioteca de
# sunete `Soundpack/`. Ce era înainte: se materializa, clipea de 3 ori stânga-dreapta la interval
# egal și dispărea, tot cu ACELAȘI sunet de teleportare de cinci ori la rând. Ce lipsea, în ordinea
# în care se simte:
#   • un CADRU (banda de sus/jos + vinietă) — fără el e o secvență de joc, nu o cinematică;
#   • un RITM: trei salturi identice se citesc ca o buclă; unul care se STRÂNGE se citește ca o
#     apropiere;
#   • o URMĂ după teleportare — ochiul nu poate urmări ceva ce sare instantaneu (`celesto.gd::umbra`);
#   • LINIȘTEA dinaintea loviturii finale — cel mai ieftin efect din meserie și cel mai puternic;
#   • un MIX: 8 sunete cu roluri diferite în loc de unul singur, cu muzica coborâtă sub ele.
#
# Cum decurge acum, în cinci bătăi (secundele sunt de la începutul cinematicii):
#   0:00  ÎNGHEAȚĂ TIMPUL. Bubuitură joasă + bas, muzica coboară cu 16 dB, benzile intră, lumea se
#         întunecă pe margini, camera primește un pumn scurt (zguduitură de 14px) și pleacă spre
#         locul gol de deasupra ta, strângând zoom-ul DINCOLO de unde trebuie (2,18) — apoi se
#         așază înapoi pe 2,0. Fără depășirea aia, apropierea camerei e o mișcare de macara; cu ea,
#         e o smucitură de cameraman.
#   0:00  Pe dedesubt urcă un „riser" tăiat FIX cât trebuie ca să se termine în bătaia următoare.
#   0:90  E SOLID: sunetul de materializare + sclipirea lui albastră. Apare direct în DREAPTA
#         cadrului (cerut pe 2026-08-06), transparent → opac, dar și puțin mai MARE → mărimea lui
#         normală, ca și cum s-ar condensa din aer. Bara lui coboară de sus în paralel, de la 0:00.
#   1:50  Bara aterizează cu numele — un clic tonal exact pe cadrul în care se oprește.
#   1:80  SALTURILE, cu ritmul STRÂNGÂNDU-SE: 0,42 → 0,30 → 0,20 → 0,16 s. Patru, nu trei, și nu
#         înainte-înapoi la nesfârșit: dreapta → stânga → dreapta → aproape de mijloc → MIJLOC.
#         Fiecare salt lasă o umbră albastră în locul părăsit, are un foșnet de aer în boxa de unde
#         PLEACĂ și un pocnet în boxa unde AJUNGE (cu tonul urcând la fiecare salt), plus o
#         împingere scurtă de cameră în sens invers. Camera NU îl urmărește — vezi mai jos.
#   2:88  LINIȘTE. 0,4 secunde în care nu se aude și nu se mișcă nimic, decât camera care se
#         strânge pe el cu 6%. Aici se face toată tensiunea.
#   3:28  DISPARE într-un singur cadru (fără fade, cerut pe 2026-08-06), cu explozia lui, basul
#         sub ea, trei umbre care se destramă și o zguduitură de 26px. Benzile ies, vinieta se
#         stinge, camera iese, muzica urcă înapoi în 1,4s, jocul repornește, el te așteaptă departe
#         în inel și abia atunci curg inamicii.
#
# Refăcută pe 2026-08-06, cerut de Răzvan („sa inceapa in partea dreapta direct sa nu fie in mijloc
# si sa inceapa direct sa se teleporteze fara sa astepte… la final… nu vreau sa isi ia fade out,
# vreau doar sa dispara de pe ecran"). Înainte stătea 2,7 secunde nemișcat în mijloc înainte de
# primul salt, fiindcă bara cobora ABIA DUPĂ ce se materializa — de acolo venea așteptarea. Acum
# cele două curg suprapus, iar bara termină de coborât fix când începe să sară.
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
# Timpii sunt în secunde; schimbă-i liniștit, dar citește întâi desfășurarea de mai sus — sunt
# potriviți unul după altul, iar sunetele sunt tăiate pe ei (riser-ul, de exemplu, e făcut fix cât
# `CUT_MATERIAL`).
const CUT_APARE := 0.75       # cât durează materializarea lui (transparent → opac)
const CUT_MATERIAL := 0.90    # în ce secundă e SOLID: sunetul de materializare + sclipirea
const CUT_BARA := 1.4         # cât coboară bara („slow cinematic") — pornește la 0:00, aterizează la 1:40
const CUT_PANA_LA_SARITURI := 0.20  # cât mai stă după ce a aterizat bara, înainte de PRIMUL salt
# ⚠️ Cele două de mai sus sunt strânse dinadins ca primul salt să cadă la 1,6s — adică EXACT unde
# cădea și în versiunea veche (măsurat: 1,71s). Tot ce s-a adăugat (înghețul, benzile, riser-ul,
# condensarea, bara cu clic) intră în același timp, nu peste el: Răzvan a cerut o dată, explicit, să
# nu se aștepte la început, iar asta rămâne valabil oricât de frumos ar fi ce pui acolo.
# Unde sare, în pixeli față de mijlocul cadrului, și cât stă acolo. Cele două liste merg la pas.
# ⚠️ Ritmul care se STRÂNGE e tot spectacolul: patru pauze egale ar fi o buclă, astea patru sunt o
# apropiere. Iar pozițiile nu se plimbă la nesfârșit — se adună spre MIJLOC, deci ultimul salt îl
# aduce în față, gata să dispară.
const CUT_SARITURI_X := [-170.0, 170.0, -95.0, 0.0]
const CUT_SARITURI_T := [0.42, 0.30, 0.20, 0.16]
const CUT_SARE_LAT := 170.0   # de unde pornește: atâția pixeli în DREAPTA mijlocului
const CUT_LINISTE := 0.40     # liniștea dinaintea dispariției (nici sunet, nici mișcare)
const CUT_ZOOM := 2.0         # de câte ori strânge camera pe el
const CUT_ZOOM_PESTE := 2.18  # cât DEPĂȘEȘTE la intrare, înainte să se așeze pe `CUT_ZOOM`
const CUT_ZOOM_IN := 0.55     # cât durează apropierea (până la depășire)
const CUT_ZOOM_ASEZA := 0.35  # cât durează așezarea înapoi pe `CUT_ZOOM`
const CUT_ZOOM_STRANS := 2.12 # cât se mai strânge, lent, în liniștea de la final
const CUT_ZOOM_OUT := 0.6     # ...și depărtarea la loc
# --- cadrul cinematic (benzile + vinieta) ---
const CUT_BENZI := 0.35       # cât intră/ies benzile
const CUT_BENZI_H := 0.085    # cât de înalte sunt, din înălțimea ecranului
const CUT_VINIETA := 0.85     # cât de tare se întunecă MARGINILE (mijlocul rămâne curat)
# --- mixul cinematicii, într-un singur loc ---
# Fișierele sunt toate normalizate la vârf -1 dBFS (vezi `audio.gd`), deci echilibrul dintre ele e
# AICI. Cifrele nu sunt la nimereală: le-am ales față de un sunet obișnuit de joc („Enemy Hit",
# care se aude la 0 dB), ca lovitura cea mai tare din cinematică să fie cu ~4 dB peste el și cu
# ~12 dB sub cutremur (`Audio.QUAKE_DB`), care rămâne cel mai tare lucru din joc.
const CUT_DB_FREEZE := -3.0
const CUT_DB_SUB := -6.0      # basul de sub îngheț
const CUT_DB_RISER := -8.0    # patul de dedesubt: se simte, nu se ascultă
const CUT_DB_MATERIAL := -4.0
const CUT_DB_NUME := -6.0
const CUT_DB_SWISH := -9.0    # aerul din locul părăsit
const CUT_DB_ZAP := -4.0      # pocnetul de la aterizare
const CUT_DB_VANISH := 0.0    # cel mai tare din toată cinematica
const CUT_DB_SUB_FINAL := -2.0
const CUT_DUCK := -16.0       # cu cât coboară muzica sub cinematică
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
	# `centru` rămâne ținta CAMEREI (mijlocul cadrului), dar EL apare în DREAPTA ei — fix în capătul
	# în care ar fi sărit oricum primul. Așa primul salt e o mișcare adevărată, nu un „puf" pe loc.
	var centru := _player.global_position + Vector2(0, -CUT_DISTANTA)
	_boss.global_position = centru + Vector2(CUT_SARE_LAT, 0.0)
	# Se materializează deja întors spre mijlocul cadrului (din dreapta → spre vest), ca la fiecare
	# salt. Fără linia asta ar apărea uitându-se spre sud, adică fix spre tine.
	if _boss.has_method("ingheata_lateral"):
		_boss.ingheata_lateral(true)
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

	# Camera trece prin `_cut_cam`: de aici încolo poziția ei se scrie într-un singur loc
	# (`_cut_aplica`), fiindcă acum două lucruri se bat pe `offset` — încadrarea și zguduiturile.
	# Puse amândouă direct pe proprietate, ultimul tween creat l-ar fi anulat pe celălalt.
	_cut_cam = cam
	_cut_baza = offset_vechi
	_cut_shake = Vector2.ZERO

	# --- 0) LOVITURA DE TIMP: se oprește totul, intră cadrul, muzica se dă la o parte ---
	_cinema_intra(CUT_BENZI)
	Audio.duck_music(CUT_DUCK, 0.25)
	Audio.play_ex("celesto_freeze", CUT_DB_FREEZE)
	Audio.play_ex("celesto_sub", CUT_DB_SUB)
	# Riser-ul e tăiat FIX cât ține bătaia asta (0,9s), ca să se termine exact pe materializare.
	# Un riser care se termină „pe undeva pe acolo" e zgomot; unul care aterizează pe cadru e mixaj.
	Audio.play_ex("celesto_riser", CUT_DB_RISER)
	_cut_zguduie(14.0, 0.28)

	# --- 1) camera intră, el se materializează în dreapta, bara coboară peste toate ---
	# Bara pornește ODATĂ cu el, nu după. NU o așteptăm (`arata_cinematic` își are tween-ul ei, care
	# merge singur în paralel): CUT_BARA e cât coboară ea, nu cât stăm noi.
	var bara := get_tree().get_first_node_in_group("boss_bar")
	if bara != null and bara.has_method("arata_cinematic"):
		bara.arata_cinematic(_boss.nume, _boss.max_hp, CUT_BARA)
	# Zoom-ul are tween-ul LUI, separat: are două bătăi una după alta (depășește, apoi se așază), iar
	# tween-ul de mai jos e pus pe „toate odată". Două tween-uri sunt mai simple decât un `chain()`
	# într-unul paralel — și nu se calcă, fiindcă lucrează pe proprietăți diferite.
	if cam != null:
		var tz := _cut_tween()
		tz.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM_PESTE, CUT_ZOOM_IN) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tz.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM, CUT_ZOOM_ASEZA) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var t := _cut_tween()
	t.set_parallel(true)
	# Bătaia de bază, care ține tween-ul viu chiar dacă n-ar exista nici camera, nici sprite-ul.
	# ⚠️ Un `Tween` fără nicio comandă se anulează singur și NU-și mai trimite `finished` — adică
	# `await`-ul de mai jos ar aștepta la nesfârșit, cu jocul înghețat. Merită linia asta.
	t.tween_interval(CUT_MATERIAL)
	if cam != null:
		t.tween_method(_cut_pune_baza, offset_vechi, centru - _player.global_position, CUT_ZOOM_IN) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if anim != null:
		t.tween_property(anim, "modulate:a", 1.0, CUT_APARE)
		# ...și se CONDENSEAZĂ: pornește cu 15% mai mare și se strânge la mărimea lui. Doar
		# transparența ar fi însemnat „cineva dă încet volumul la o poză"; cu scăderea asta, arată ca
		# ceva care se adună din aer. Mărimea de bază se ia din scenă (3.2), nu se scrie aici.
		var scara := anim.scale
		anim.scale = scara * 1.15
		t.tween_property(anim, "scale", scara, CUT_APARE) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished

	# --- 2) E SOLID ---
	Audio.play_ex("celesto_materialize", CUT_DB_MATERIAL)
	Audio.play("celesto_teleport", -6.0, 0.0)   # sunetul lui dintotdeauna, acum doar un strat dedesubt
	if is_instance_valid(_boss) and _boss.has_method("puf"):
		_boss.puf()
	_cut_zguduie(6.0, 0.18)

	# Bara aterizează abia acum (a pornit la 0:00 și coboară CUT_BARA secunde): clicul tonal cade pe
	# cadrul în care se oprește, nu „pe undeva pe lângă". De-aia așteptăm diferența, nu o constantă.
	await _cut_asteapta(maxf(CUT_BARA - CUT_MATERIAL, 0.0))
	Audio.play_ex("celesto_name", CUT_DB_NUME)

	# --- 3) SALTURILE, cu ritmul strângându-se ---
	# Camera NU îl urmărește: stă pe `centru`, iar el clipește în stânga și în dreapta ei. Dacă l-ar
	# urma, saltul n-ar mai fi vizibil deloc — ar părea că lumea se mișcă, nu el.
	# ⚠️ Primul salt e spre STÂNGA (`CUT_SARITURI_X[0]` e negativ), fiindcă s-a materializat în
	# dreapta. Cu semnele invers, primul „salt" l-ar muta exact unde era deja: sunet și sclipire, dar
	# el nemișcat — exact impresia de așteptare pe care o scoatem de aici.
	await _cut_asteapta(CUT_PANA_LA_SARITURI)
	for i in CUT_SARITURI_X.size():
		var dx: float = CUT_SARITURI_X[i]
		if is_instance_valid(_boss):
			var de_unde: Vector2 = _boss.global_position
			# Foșnetul de aer rămâne în boxa de unde PLEACĂ, pocnetul se aude de unde AJUNGE. Asta
			# cere fișiere mono și `play_pan` (vezi `audio.gd`) — un stereo își are deja stânga și
			# dreapta scrise în el și n-ar urma boss-ul.
			Audio.play_pan("celesto_swish", de_unde, CUT_DB_SWISH)
			# Urma din locul părăsit: fără ea, ochiul nu are ce urmări între cele două capete.
			if _boss.has_method("umbra"):
				_boss.umbra(de_unde)
			_boss.global_position = centru + Vector2(dx, 0.0)
			# Freeze frame, din profil, uitându-se spre mijlocul cadrului: în dreapta → spre vest, în
			# stânga → spre est. Cerut de Răzvan pe 2026-08-06 („sa nu se uite in sud"). La ultimul
			# salt e chiar în mijloc (`dx == 0`) — îl lăsăm tot din profil, tot pentru regula aia.
			if _boss.has_method("ingheata_lateral"):
				_boss.ingheata_lateral(dx > 0.0)
			# Tonul urcă la fiecare salt (un semiton, apoi încă unul...): aceeași lovitură repetată de
			# patru ori se aude ca o buclă, una care urcă se aude ca o acumulare.
			Audio.play_pan("celesto_zap", _boss.global_position, CUT_DB_ZAP, 1.0 + 0.06 * float(i))
			if _boss.has_method("puf"):
				_boss.puf()
			# Camera primește o împingere scurtă în sensul OPUS saltului — reacția, nu urmărirea.
			# 6 pixeli, cât să se simtă că a fost lovită, nu cât să se vadă că se mișcă.
			_cut_imbrancire(Vector2(-signf(dx) * 6.0, 0.0))
		await _cut_asteapta(float(CUT_SARITURI_T[i]))

	# --- 4) LINIȘTEA ---
	# 0,4 secunde în care nu se aude NIMIC și nu se mișcă nimic, decât camera care se strânge foarte
	# puțin pe el. E cel mai ieftin efect din meserie și cel mai puternic: urechea, rămasă brusc fără
	# nimic după patru pocnete tot mai dese, așteaptă lovitura — și de-aia lovitura de la 3:28 pare
	# de două ori mai mare decât e.
	# ⚠️ Are și un rol tehnic: sclipirea albastră a ultimului salt (`puf`, 0,25s) apucă să se termine
	# aici. Fără pauza asta, tween-ul ei ar mai fi mișcat `modulate` DUPĂ ce noi punem alfa pe 0 la
	# dispariție — adică boss-ul ar fi reapărut pentru o clipă, fantomatic, exact în cadrul în care
	# trebuia să nu mai fie.
	if cam != null:
		var tl := _cut_tween()
		tl.tween_property(cam, "zoom", zoom_vechi * CUT_ZOOM_STRANS, CUT_LINISTE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _cut_asteapta(CUT_LINISTE)

	# --- 5) DISPARE, camera iese, jocul repornește ---
	# FĂRĂ fade, cerut de Răzvan pe 2026-08-06 („cand se aude teleportarea nu vreau sa isi ia fade
	# out, vreau doar sa dispara de pe ecran"). Are dreptate: ceva care se stinge lent se citește ca
	# „moare", nu ca „a plecat". Sunetul și dispariția cad în ACELAȘI cadru, exact ca la salturi —
	# doar că de data asta nu mai reapare.
	# ⚠️ `modulate:a`, nu `visible`: sclipirea albastră (`puf`) e un tween pe `modulate` al lui, iar
	# el rămâne în lume și după cinematică. Alpha e ce restaurăm mai jos.
	Audio.play_ex("celesto_vanish", CUT_DB_VANISH)
	Audio.play_ex("celesto_sub", CUT_DB_SUB_FINAL)
	# TREI umbre deodată, nu una: la salturi urma spune „a plecat de aici", aici spune „s-a
	# destrămat". Puse înainte de a-i stinge alfa — `umbra()` copiază cadrul de pe sprite, iar un
	# sprite deja invizibil ar fi dat trei pete goale.
	# ⚠️ ÎMPRĂȘTIATE, nu una peste alta: prima încercare le punea la ±14px și, suprapuse, arătau ca
	# o singură pată albastră — adică exact ca o umbră obișnuită, doar mai groasă. La 40-70px se
	# văd trei siluete care se desfac în direcții diferite.
	if is_instance_valid(_boss) and _boss.has_method("umbra"):
		for i in 3:
			var unghi := TAU * (float(i) / 3.0) + randf() * 0.5
			var raza := randf_range(40.0, 70.0)
			_boss.umbra(_boss.global_position + Vector2(cos(unghi), sin(unghi) * 0.55) * raza)
	if anim != null:
		anim.modulate.a = 0.0
	_cut_zguduie(26.0, 0.5)
	_cinema_iese(CUT_BENZI)
	Audio.unduck_music(1.4)   # lumea își revine încet — mai lent decât a fost dată la o parte
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

# ---------- camera cinematicii ----------
# ⚠️ TOT ce mișcă `cam.offset` în cinematică trece pe aici. Motivul: peste încadrare (camera care
# pleacă spre boss și se întoarce) se suprapun zguduiturile și îmbrâncelile de la fiecare salt.
# Două tween-uri pe ACEEAȘI proprietate se anulează unul pe altul — cel creat mai târziu câștigă și
# îl aruncă pe primul din drum. Aici sunt două variabile separate, adunate într-un singur loc, deci
# se pot întâmpla în același timp fără să se calce.
var _cut_cam: Camera2D = null
var _cut_baza := Vector2.ZERO    # încadrarea: unde „privește" camera
var _cut_shake := Vector2.ZERO   # ce se adaugă peste ea: zguduituri și împinsături

func _cut_aplica() -> void:
	if _cut_cam != null and is_instance_valid(_cut_cam):
		_cut_cam.offset = _cut_baza + _cut_shake

func _cut_pune_baza(v: Vector2) -> void:
	_cut_baza = v
	_cut_aplica()

# Zguduitură ADEVĂRATĂ (direcție nouă la fiecare cadru), care se stinge singură. `putere` e în
# pixeli, la început.
func _cut_pune_shake(putere: float) -> void:
	_cut_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * putere
	_cut_aplica()

func _cut_zguduie(putere: float, durata: float) -> void:
	var tw := _cut_tween()
	tw.tween_method(_cut_pune_shake, putere, 0.0, durata)
	tw.tween_callback(func(): _cut_shake = Vector2.ZERO; _cut_aplica())

# ÎMBRÂNCEALĂ: o singură împingere într-o direcție, care se întoarce lin. Nu e zguduitură — la
# fiecare salt camera e împinsă în sensul OPUS, ca și cum ar fi primit el impactul.
func _cut_pune_imbrancire(v: Vector2) -> void:
	_cut_shake = v
	_cut_aplica()

func _cut_imbrancire(v: Vector2) -> void:
	var tw := _cut_tween()
	tw.tween_method(_cut_pune_imbrancire, v, Vector2.ZERO, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ---------- cadrul cinematic (benzile + vinieta) ----------
# Benzile negre sus/jos și întunecarea MARGINILOR. Sunt pe stratul Ender-ului (4), deci acoperă
# lumea și HUD-ul (1), dar rămân SUB bara de boss (6) — exact cum trebuie: cadrul se strânge,
# numele boss-ului nu intră sub bandă.
# Vinieta e o pată radială, nu un geam gri peste tot: Celesto e o siluetă NEAGRĂ pe o nebuloasă
# aproape neagră, iar un întuneric uniform l-ar fi înghițit exact pe el. Așa se sting doar
# marginile, iar mijlocul — unde stă el — rămâne curat.
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
	# pixel". Cu el, degradeul de 256px întins pe tot ecranul ar fi ieșit în trepte vizibile.
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	r.visible = false
	add_child(r)
	return r

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

# Marginea lumii: Ender-ul se termină la `ground.gd::MARGINE_RAZA` de fântâna prin care ai intrat,
# iar dincolo podeaua se stinge în negru. Raza și oprirea player-ului stau amândouă în `ground.gd`
# — noi spunem doar UNDE e centrul. Spre deosebire de Nether, aici fântâna se știe din primul rând
# al lui `enter()`, deci marginea poate merge chiar lângă podea.
func _margine(on: bool) -> void:
	var ground := get_tree().get_first_node_in_group("ground")
	if ground == null or not ground.has_method("set_margine"):
		return
	var centru := portal_pos()
	if on and centru != Vector2.INF:
		ground.set_margine(centru)
	else:
		ground.opreste_margine()

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

# `goleste` = și ștergem ce a încărcat generatorul. Implicit da (asta vrei la intrarea/ieșirea
# din dimensiune). `false` doar la pauza de Limbo (`_set_ender_only`), unde generatorul trebuie
# doar stins pe moment, cu tot cu ce are deja în el.
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

func _mmss(secunde: float) -> String:
	var s := int(ceil(maxf(0.0, secunde)))   # ceil: la intrare scrie 6:00, nu 5:59
	return "%d:%02d" % [s / 60, s % 60]

func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
