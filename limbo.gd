extends CanvasLayer

# LIMBO — mecanica itemului „Undying Spirit" (upgrade_41).
#
# Când mori și ai itemul (o singură dată pe rundă), în loc de Game Over ești dus într-o
# lume goală, alb-negru: fără copaci, pietre, structuri sau statui. Peste tine vine dintr-o
# dată un val mare de inamici. Trebuie să reziști LIMBO_TIME secunde, apoi ești trimis
# înapoi exact unde ai murit — iar inamicii care erau pe tine în acel moment nu mai există.
#
# Cum e făcut: NU se încarcă altă scenă. Rămânem în aceeași lume, dar:
#   • generatoarele de decor (Props/Rocks/DesertStructures/Statues) sunt oprite și golite;
#   • spawner-ul normal e oprit, ca să nu curgă inamici de dificultatea reală;
#   • `Difficulty` e înghețat, iar inamicii se calculează după dificultatea de acum un minut;
#   • un shader alb-negru acoperă ecranul.
# La ieșire se pune totul la loc. Așa nu pierdem starea rundei (upgrade-uri, XP, poziție).

const ENEMY := preload("res://enemy.tscn")
const BW_SHADER := preload("res://limbo_bw.gdshader")

# --- reglaje (schimbă-le liniștit) ---
const LIMBO_TIME := 60.0        # cât trebuie să reziști, în secunde
const DIFF_REWIND := 60.0       # dificultatea de acum câte secunde se folosește
const HP_ON_ENTER := 0.5        # cu cât din viața maximă te trezești (0.5 = jumătate)
const BURST := 40               # câți inamici apar DEODATĂ la intrare
const BURST_RADIUS := 520.0     # la ce distanță de tine apar (cerc în jurul tău)
const TRICKLE := 1.4            # la câte secunde mai apare unul (ca să nu rămână gol)
const FADE := 0.6               # cât durează trecerea în alb-negru și înapoi
const CLOCK_SIZE := 64                          # mai mare decât cronometrul rundei (44)
const CLOCK_COLOR := Color(1.0, 0.10, 0.10)     # roșu aprins

# Nodurile care fac decorul. Sunt oprite cât ești în Limbo → „lume fără structuri".
const WORLD_NODES := ["Props", "Rocks", "DesertStructures", "Statues"]

var active := false

var _overlay: ColorRect
var _clock: Label        # numărătoarea inversă, desenată peste filtrul alb-negru
var _mat: ShaderMaterial
var _time_left := 0.0
var _trickle_t := 0.0
var _player: Node2D = null
var _return_pos := Vector2.ZERO
var _spawner: Node = null

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
	_trickle_t = 0.0

	# nu mai ești mort: te ridici cu jumătate de viață
	player.dead = false
	player.hp = maxi(1, int(round(player.max_hp * HP_ON_ENTER)))

	# inamicii care te-au omorât rămân în lumea normală — adică dispar.
	# La întoarcere nu-i mai găsești, exact cum cere itemul.
	_clear_enemies()

	_set_world_enabled(false)
	_set_spawner_enabled(false)

	# inamicii de aici au dificultatea de acum un minut, iar cronometrul rundei stă
	Difficulty.mult_time_override = maxf(0.0, Difficulty.time - DIFF_REWIND)
	Difficulty.frozen = true

	_overlay.visible = true
	_clock.text = _mmss(_time_left)
	_clock.visible = true
	create_tween().tween_property(_mat, "shader_parameter/amount", 1.0, FADE)

	for i in BURST:
		_spawn_one()

	_announce("LIMBO", "Survive 1:00 and you go back")
	Audio.play("levelup")

# ---------- IEȘIRE ----------
func _exit_limbo() -> void:
	if not active:
		return
	active = false
	_clear_enemies()          # ce era pe tine în Limbo nu vine cu tine
	_set_world_enabled(true)
	_set_spawner_enabled(true)
	Difficulty.frozen = false
	Difficulty.mult_time_override = -1.0
	if _player != null and is_instance_valid(_player):
		_player.global_position = _return_pos   # exact unde ai murit
	_clock.visible = false
	var t := create_tween()
	t.tween_property(_mat, "shader_parameter/amount", 0.0, FADE)
	t.tween_callback(func(): _overlay.visible = false)
	_announce("YOU MADE IT", "The spirit sends you back")
	Audio.play("levelup")

# Ai murit în Limbo: eliberăm starea globală, dar NU te mutăm și NU stingem alb-negrul —
# mori acolo, cu tot cu atmosferă.
func _abort() -> void:
	active = false
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
	# un firicel de inamici, ca să nu rămână gol după ce cureți valul
	_trickle_t += delta
	while _trickle_t >= TRICKLE:
		_trickle_t -= TRICKLE
		_spawn_one()

# Câte secunde mai ai de rezistat (HUD-ul o afișează în loc de cronometrul rundei).
func time_left() -> float:
	return maxf(0.0, _time_left)

# ---------- ajutoare ----------
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
		var node := parent.get_node_or_null(n)
		if node == null:
			continue
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
