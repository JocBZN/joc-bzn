extends CanvasLayer

# LIMBO — mecanica itemului „Undying Spirit" (upgrade_41).
#
# Când mori și ai itemul (o singură dată pe rundă), în loc de Game Over ești dus într-o
# lume goală, alb-negru: fără copaci, pietre, structuri, statui, cufere, portaluri sau poteci. Peste
# tine vine dintr-o dată un val mare de inamici. Trebuie să reziști LIMBO_TIME secunde, apoi ești
# trimis înapoi exact unde ai murit — ȘI ÎN DIMENSIUNEA în care ai murit (lumea normală, Nether
# sau Ender) — iar inamicii care erau pe tine în acel moment nu mai există.
#
# Cum e făcut: NU se încarcă altă scenă. Rămânem în aceeași lume, dar:
#   • generatoarele de decor (Props/Rocks/DesertStructures/Statues/Chests/EGTs/Monuments/Portals
#     + potecile) sunt oprite și golite;
#   • spawner-ul normal e oprit — inamicii îi scoatem noi, dar cu ritmul, viteza și damage-ul
#     lui, calculate din dificultatea de acum un minut (vezi `_diff_start` mai jos);
#   • dacă ai murit într-o dimensiune, ea nu se închide, ci se PUNE PE PAUZĂ
#     (`nether.gd::suspenda()` / `ender.gd::suspenda()`) și se reia la ieșire;
#   • un shader alb-negru acoperă ecranul.
# La ieșire se pune totul la loc. Așa nu pierdem starea rundei (upgrade-uri, XP, poziție).

const ENEMY := preload("res://enemy.tscn")   # rezerva, dacă spawner-ul lipsește (scene de test)
const BW_SHADER := preload("res://limbo_bw.gdshader")

# --- reglaje (schimbă-le liniștit) ---
const LIMBO_TIME := 60.0        # cât trebuie să reziști, în secunde
const DIFF_REWIND := 60.0       # dificultatea de acum câte secunde se folosește
const HP_ON_ENTER := 0.5        # cu cât din viața maximă te trezești (0.5 = jumătate)
const BURST := 40               # câți inamici apar DEODATĂ la intrare
const BURST_RADIUS := 520.0     # la ce distanță de tine apar (cerc în jurul tău)
const MAX_ENEMIES := 300        # plafon de siguranță, ca la `spawner.gd`
const FADE := 0.6               # cât durează trecerea în alb-negru și înapoi
const CLOCK_SIZE := 64                          # mai mare decât cronometrul rundei (44)
const CLOCK_COLOR := Color(1.0, 0.10, 0.10)     # roșu aprins

# Nodurile care fac decorul. Sunt oprite cât ești în Limbo → „lume fără structuri".
# ⚠️ Lista asta se ține în oglindă cu cea din `nether.gd`: un generator nou pus în `World`
# (main.tscn) trebuie trecut în AMÂNDOUĂ. Dacă lipsește dintr-una, rămâne aprins acolo și-i vezi
# obiectele într-o dimensiune în care n-au ce căuta. S-a întâmplat de trei ori: cu „EGTs"
# (aparatele de cazinou, 2026-07-30) întâi în `nether.gd`, apoi și aici — și cu „Portals",
# lipsă de aici până pe 2026-08-06, adică în Limbo îți răsăreau portaluri Nether și fântâni
# Ender („nu vreau sa apara portalul de ender in limbo").
const WORLD_NODES := ["Props", "Rocks", "Bushes", "DesertStructures", "Statues", "Chests", "EGTs", "Monuments", "Portals", "AlbaNeagras", "Dubiosi"]
# `Paths` (potecile) NU e în `World`, ci frate cu el, direct în `main.tscn` — de aia are
# nevoie de listă separată. Exact ca în `nether.gd`.
const ROOT_NODES := ["Paths"]

var active := false

var _overlay: ColorRect
var _clock: Label        # numărătoarea inversă, desenată peste filtrul alb-negru
var _mat: ShaderMaterial
var _time_left := 0.0
var _spawn_acc := 0.0        # „sfert de inamic" rămas de la cadrul trecut (vezi `_process`)
var _player: Node2D = null
var _return_pos := Vector2.ZERO
var _spawner: Node = null
# Dimensiunea în care ai murit (`nether.gd` sau `ender.gd`), pusă pe pauză cât ești aici și
# reluată la ieșire. `null` = ai murit în lumea normală.
var _dimensiune: Node = null

func _ready() -> void:
	add_to_group("limbo")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5   # peste lume și HUD, dar SUB ecranul de Game Over (care e pe 20)
	_mat = ShaderMaterial.new()
	_mat.shader = BW_SHADER
	_mat.set_shader_parameter("amount", 0.0)
	_overlay = ColorRect.new()
	_overlay.material = _mat
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	# Cronometrul de Limbo. Stă în ACEEAȘI CanvasLayer, adăugat DUPĂ overlay → se desenează
	# peste filtrul alb-negru și rămâne roșu. Dacă l-am lăsa în HUD (care e sub filtru),
	# ar ieși gri, oricât roșu i-am da. Cât ține Limbo, HUD-ul își ascunde cronometrul lui.
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

# ---------- INTRARE ----------
# Chemată din player.die() în locul ecranului de Game Over.
func enter(player: Node2D) -> void:
	if active or player == null:
		return
	active = true
	_player = player
	_return_pos = player.global_position
	_time_left = LIMBO_TIME
	_spawn_acc = 0.0

	# Dificultatea de acum un minut, ÎNGHEȚATĂ pe loc pentru tot Limbo-ul. Se citește ÎNAINTE de
	# orice altceva, fiindcă de aici încolo o rescriem noi.
	#
	# ⚠️ Pornim de la `Difficulty.mult_time()` (dificultatea pe care o SIMȚEAI acum), nu de la
	# `Difficulty.time` (ceasul rundei), cum era până pe 2026-08-06. În Nether și în Ender ceasul
	# rundei e înghețat din secunda în care ai intrat, deci `time - 60` te dădea cu minute bune
	# înapoi și te trezeai în Limbo cu inamici de început de rundă — exact reclamația lui Răzvan
	# („in limbo nu sunt inamicii destul de op").
	var diff_start := maxf(0.0, Difficulty.mult_time() - DIFF_REWIND)

	# nu mai ești mort: te ridici cu jumătate de viață
	player.dead = false
	player.hp = maxi(1, int(round(player.max_hp * HP_ON_ENTER)))

	# Ai murit într-o dimensiune? N-o închidem — o punem pe pauză și o reluăm la ieșire, ca să te
	# întorci „fix din locul unde ai murit" (cerut pe 2026-08-06). Se face ÎNAINTE de
	# `_clear_enemies()`: pauza scoate boss-ul dimensiunii din grupul „enemy", altfel l-am mătura
	# noi și portalul de întoarcere n-ar mai avea cum să se deschidă vreodată.
	_dimensiune = _dimensiunea_activa()
	if _dimensiune != null:
		_dimensiune.suspenda()

	# inamicii care te-au omorât rămân dincolo — adică dispar.
	# La întoarcere nu-i mai găsești, exact cum cere itemul.
	_clear_enemies()

	_set_world_enabled(false)
	_set_spawner_enabled(false)

	# inamicii de aici au dificultatea de acum un minut, iar cronometrul rundei stă
	Difficulty.mult_time_override = diff_start
	Difficulty.frozen = true

	_overlay.visible = true
	_clock.text = _mmss(_time_left)
	_clock.visible = true
	create_tween().tween_property(_mat, "shader_parameter/amount", 1.0, FADE)

	for i in BURST:
		_spawn_one()

	_announce("LIMBO", "Survive 1:00 and you go back")
	Audio.play("levelup", -2.0)

# ---------- IEȘIRE ----------
func _exit_limbo() -> void:
	if not active:
		return
	active = false
	_clear_enemies()          # ce era pe tine în Limbo nu vine cu tine
	# Decorul lumii normale se aprinde la loc DOAR dacă acolo te întorci. Dacă ai murit în Nether
	# sau în Ender, el trebuie să rămână stins — altfel ai ateriza într-o dimensiune plină de
	# copaci și cufere, iar `reia()` de mai jos n-ar avea cum să-i mai stingă.
	_set_world_enabled(_dimensiune == null)
	_set_spawner_enabled(true)
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0
	if _player != null and is_instance_valid(_player):
		_player.global_position = _return_pos   # exact unde ai murit
	# ...și înapoi în dimensiunea în care ai murit, de unde a rămas: ceasul ei, portalul, boss-ul
	# la viața pe care i-o lăsaseși. `reia()` își pune la loc și dificultatea, deci vine ULTIMA,
	# peste neutralizarea de mai sus.
	if _dimensiune != null and is_instance_valid(_dimensiune):
		_dimensiune.reia()
	_dimensiune = null
	_clock.visible = false
	var t := create_tween()
	t.tween_property(_mat, "shader_parameter/amount", 0.0, FADE)
	t.tween_callback(func(): _overlay.visible = false)
	_announce("YOU MADE IT", "The spirit sends you back")
	Audio.play("levelup", -2.0)

# Ai murit în Limbo: eliberăm starea globală, dar NU te mutăm și NU stingem alb-negrul —
# mori acolo, cu tot cu atmosferă.
#
# Dimensiunea (dacă erai suspendat într-una) NU se reia aici: `player.die()` a chemat deja
# `exit_nether(false)` / `exit_ender(false)`, iar ele se trezesc singure din pauză (vezi
# `_suspendat` acolo). Noi doar uităm de ea, ca să nu rămână o referință moartă.
func _abort() -> void:
	active = false
	_dimensiune = null
	_clock.visible = false   # nu lăsăm numărătoarea agățată peste ecranul de Game Over
	_set_world_enabled(true)
	_set_spawner_enabled(true)
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0

func _process(delta: float) -> void:
	if not active:
		return
	# Ai murit în Limbo → asta chiar e sfârșitul (Game Over-ul e deja pe ecran).
	# Nu te mai întoarcem, dar punem lumea și dificultatea la loc, ca să nu rămână
	# `frozen`/spawner oprit agățate peste ecranul de final.
	if _player == null or not is_instance_valid(_player) or _player.dead:
		_abort()
		return
	_time_left -= delta
	_clock.text = _mmss(_time_left)
	if _time_left <= 0.0:
		_exit_limbo()
		return
	# Inamicii curg în EXACT ritmul lumii de acum un minut. Până pe 2026-08-06 aici era un
	# firicel fix (unul la 1,4 secunde), care la minutul 8 de rundă însemna de zeci de ori mai
	# puțini decât afară — de-aia se simțea Limbo-ul mai ușor decât lumea din care veneai.
	# Rata o cere `spawner.gd::rata_curenta()`, ca formula să trăiască într-un singur loc; el e
	# oprit cât suntem aici, dar funcția merge oricând.
	#
	# Adunăm fracții de inamic în `_spawn_acc` în loc să numărăm pauze: la rate mari (Final
	# Swarm) un cadru poate datora și 3-4 inamici, iar cu pauze înlănțuite s-ar pierde restul.
	if get_tree().get_nodes_in_group("enemy").size() < MAX_ENEMIES:
		_spawn_acc += delta * _rata()
		while _spawn_acc >= 1.0:
			_spawn_acc -= 1.0
			_spawn_one()
	else:
		_spawn_acc = 0.0

# Câte secunde mai ai de rezistat (HUD-ul o afișează în loc de cronometrul rundei).
func time_left() -> float:
	return maxf(0.0, _time_left)

# ---------- ajutoare ----------

# În ce dimensiune ai murit? `null` = lumea normală. Nu poți fi în două deodată (`ender.gd` și
# `nether.gd` se refuză reciproc la intrare), deci primul găsit e cel bun.
func _dimensiunea_activa() -> Node:
	for g in ["nether", "ender", "prison"]:
		var d := get_tree().get_first_node_in_group(g)
		if d != null and d.get("active") == true and d.has_method("suspenda"):
			return d
	return null

# Câți inamici pe secundă, la dificultatea înghețată de la intrare. Vezi `spawner.gd`.
func _rata() -> float:
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner != null and _spawner.has_method("rata_curenta"):
		return _spawner.rata_curenta()
	return Difficulty.spawn_mult()

# Ce fel de inamic scoatem. Îl întrebăm tot pe spawner, ca să fie ACEIAȘI ca afară: dacă ai murit
# în Nether vin creaturile violete, dacă în Ender cele ale lui Celesto, iar în lumea normală
# polițiștii cu amestecul de Skinny/scăpați din Nether de la momentul ăla. (Dimensiunea rămâne
# `active` cât e suspendată, exact ca să meargă întrebarea asta.)
func _scena_inamic() -> PackedScene:
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner != null and _spawner.has_method("scena_inamic"):
		return _spawner.scena_inamic()
	return ENEMY

func _spawn_one() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var e := _scena_inamic().instantiate()
	var unghi := randf() * TAU
	_player.get_parent().add_child(e)
	e.global_position = _player.global_position \
		+ Vector2(cos(unghi), sin(unghi)) * BURST_RADIUS * randf_range(0.85, 1.25)

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()

# Oprește\repornește generatoarele de decor. Nu e destul să le ascunzi: hitbox-urile
# ar rămâne și te-ai lovi de copaci invizibili. Deci le și golim de ce au încărcat, iar
# `_loaded` (dicționarul lor de chunk-uri) trebuie golit odată cu ele — altfel, la
# repornire, ar crede că bucățile alea există deja și lumea ar rămâne goală pe veci.
func _set_world_enabled(on: bool) -> void:
	var world := get_tree().get_first_node_in_group("player")
	if world == null:
		return
	var parent := world.get_parent()
	if parent == null:
		return
	for n in WORLD_NODES:
		_toggle_generator(parent.get_node_or_null(n), on)
	# potecile stau LÂNGĂ `World`, nu în el (vezi ROOT_NODES)
	var root := parent.get_parent()
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

func _set_spawner_enabled(on: bool) -> void:
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner != null:
		_spawner.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

func _mmss(secunde: float) -> String:
	var s := int(ceil(maxf(0.0, secunde)))   # ceil: la intrare scrie 1:00, nu 0:59
	return "%d:%02d" % [s / 60, s % 60]

func _announce(text: String, sub: String = "") -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce(text, sub)
