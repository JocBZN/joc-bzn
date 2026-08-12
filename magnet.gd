extends Area2D

# MAGNETUL de XP, căzut de la un inamic mort (0.5% — vezi `enemy.gd::_drop_xp`, aceeași rată ca
# la cheia de cufăr). Îl ridici mergând peste el, exact ca gemele, și **trage TOT XP-ul de pe
# hartă** la tine: fiecare gemă rămasă pe jos, oriunde ar fi, pleacă spre player și se adună.
#
# Construit pe tiparul lui `key.gd` (obiect care stă pe jos, pulsează, plutește și e cules la
# atingere), nu pe al lui `xp.gd`: acolo există contopirea în bule, fiindcă în Final Swarm cad mii
# de geme. Aici cade unul la ~200 de morți, deci nu se strâng niciodată grămadă.
#
# Arta e `xp/magnet_contur.png` — poza lui Răzvan cu un contur NEGRU de 1px, pus de
# `tool_contur_foaie.gd`. Sursa `xp/magnet.png` rămâne neatinsă, deci unealta poate fi rulată
# oricând fără să se îngroașe conturul (dacă ar scrie peste sursă, a doua rulare ar contura
# conturul).

@export var magnet_range: float = 150.0   # de la ce distanță zboară spre player (ca la cheie:
                                          # puțin peste geme, ca un obiect rar să nu-ți scape)
@export var magnet_speed: float = 420.0

var _time := 0.0
var _base_scale: Vector2
var _luat := false
var _player: Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("magnet")
	body_entered.connect(_on_body_entered)
	_base_scale = sprite.scale
	_time = randf() * TAU   # ca două magneți căzuți odată să nu pulseze identic

func _physics_process(delta: float) -> void:
	if _luat:
		return
	# aceeași animație „vie" ca la XP și la cheie: pulsează ușor și plutește sus-jos
	_time += delta
	sprite.scale = _base_scale * (1.0 + 0.12 * sin(_time * 5.0))
	sprite.position.y = -5.0 * absf(sin(_time * 3.0))
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and global_position.distance_to(_player.global_position) < magnet_range:
		global_position += (_player.global_position - global_position).normalized() * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
	if _luat or not body.is_in_group("player"):
		return
	_luat = true
	remove_from_group("magnet")
	Audio.play("key_pickup", 0.0, 0.0)
	_trage_tot_xp_ul()
	var t := create_tween()
	t.tween_property(sprite, "scale", _base_scale * 1.7, 0.08)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)

# Toate gemele de pe hartă pleacă spre player. XP-ul NU se dă aici, dintr-o dată: fiecare gemă îl
# dă când ajunge la tine (vezi `xp.gd::atrage_la_player`), ca bara să se umple pe măsură ce curg
# — asta e tot spectacolul itemului. Nivelurile luate deodată nu sunt o problemă: ecranul de Level
# Up le pune la coadă (`_pending`).
#
# ⚠️ Se ia o COPIE a listei grupului: `atrage_la_player` scoate gema din grup pe loc, iar
# `get_nodes_in_group` întoarce un tablou nou de fiecare dată, deci parcurgerea rămâne întreagă.
func _trage_tot_xp_ul() -> void:
	for g in get_tree().get_nodes_in_group("xp"):
		if is_instance_valid(g) and g.has_method("atrage_la_player"):
			g.atrage_la_player()
