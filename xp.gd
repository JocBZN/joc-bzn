extends Area2D

# Glob de XP care stă pe jos. Are viață: pulsează + plutește, e atras spre player
# când se apropie (magnet), și face un mic "pop" când e adunat.

@export var value: int = 1
@export var magnet_range: float = 130.0   # de la ce distanță începe să fie atras spre player
@export var magnet_speed: float = 420.0   # cât de repede zboară spre player

# Câte geme pot exista ODATĂ în lume. Vezi `_respecta_plafonul()` — fără plafon, în
# Final Swarm se adună mii și jocul intră în melasă (măsurat: 5000 de geme = 4 FPS).
const MAX_GEME := 200
const SCALE_MAX := 1.8    # cât de mare poate ajunge o gemă care a înghițit alte geme

var _time := 0.0
var _base_scale: Vector2
var _collected := false
var _player: Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("xp")
	body_entered.connect(_on_body_entered)
	_base_scale = sprite.scale
	_time = randf() * TAU   # faze diferite, ca să nu pulseze toate la fel
	_respecta_plafonul()

# Lumea nu poate ține oricâte geme. În Final Swarm mor ~30 de inamici pe secundă și
# nu ai cum să aduni tot: gemele rămase în urmă se strâng la nesfârșit, fiecare cu
# Area2D + animație proprie, și framerate-ul moare (asta era „laghitul de după 10:00").
#
# Soluția NU aruncă XP: când s-ar depăși plafonul, gema cea mai DEPĂRTATĂ de tine se
# varsă în asta (valoarea ei se adună aici) și dispare. Rămâi cu la fel de mult XP pe
# hartă, doar strâns în mai puține globuri — și alea de lângă tine, cele pe care chiar
# le poți aduna. O gemă care a înghițit altele se vede și puțin mai mare.
func _respecta_plafonul() -> void:
	var geme := get_tree().get_nodes_in_group("xp")
	var de_scos := geme.size() - MAX_GEME
	if de_scos <= 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var reper := player.global_position if player != null else global_position
	# cele mai depărtate de player, primele
	geme.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return reper.distance_squared_to(a.global_position) > reper.distance_squared_to(b.global_position))
	var inghitite := 0
	for g in geme:
		if de_scos <= 0:
			break
		if g == self or not is_instance_valid(g):
			continue
		value += g.value
		g.remove_from_group("xp")   # scoasă din evidență imediat, chiar dacă e ștearsă la final de cadru
		g.queue_free()
		de_scos -= 1
		inghitite += 1
	if inghitite > 0:
		_base_scale *= minf(SCALE_MAX, 1.0 + 0.06 * inghitite)

func _physics_process(delta: float) -> void:
	if _collected:
		return
	# animație idle: pulsează ușor + plutește sus-jos
	_time += delta
	sprite.scale = _base_scale * (1.0 + 0.12 * sin(_time * 5.0))
	sprite.position.y = -5.0 * absf(sin(_time * 3.0))
	# magnet: dacă player-ul e aproape, zboară spre el
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		if global_position.distance_to(_player.global_position) < magnet_range:
			var dir := (_player.global_position - global_position).normalized()
			global_position += dir * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collected = true
		remove_from_group("xp")   # nu mai intră la socoteala plafonului cât se stinge
		Audio.play("xp", -6.0)  # blip la adunat XP
		body.gain_xp(value)
		_pop()

func _pop() -> void:
	# efect la colectare: crește rapid și se stinge, apoi dispare
	var t := create_tween()
	t.tween_property(sprite, "scale", _base_scale * 1.7, 0.08)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)
