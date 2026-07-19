extends AnimatedSprite2D
# Arcul electric de Thunder God / Plugged In. Stă LIPIT ca o frânghie între cele două capete:
# în loc să fie întins o singură dată la spawn (și să rămână în urmă cât inamicii se mișcă), își
# reface poziția / unghiul / lungimea în fiecare cadru după nodurile de la capete.
# Dacă un capăt moare între timp, rămâne la ultima lui poziție (nu dispare brusc arcul).

var from_node: Node2D = null   # capătul de pornire (inamicul lovit); null = punct fix
var to_node: Node2D = null     # capătul de sosire (inamicul prins de curent)
var from_pos: Vector2          # ultima poziție cunoscută a capetelor (fallback după moarte)
var to_pos: Vector2
var _frame_h: float = 1.0      # înălțimea unui cadru, ca să scalez lungimea în pixeli

func setup(p_from: Vector2, p_to: Vector2, n_from: Node2D, n_to: Node2D, frame_h: float) -> void:
	from_pos = p_from
	to_pos = p_to
	from_node = n_from
	to_node = n_to
	_frame_h = maxf(1.0, frame_h)
	_stretch()

func _process(_delta: float) -> void:
	if from_node != null and is_instance_valid(from_node):
		from_pos = from_node.global_position
	if to_node != null and is_instance_valid(to_node):
		to_pos = to_node.global_position
	_stretch()

# Animația e desenată spre NORD, deci o rotesc cu dir.angle() + PI/2 (ca la gloanțe) și o întind pe
# verticală cât distanța dintre capete. Centrată la mijloc → capetele cad exact pe inamici.
func _stretch() -> void:
	var d := from_pos.distance_to(to_pos)
	if d < 1.0:
		return
	var dir := (to_pos - from_pos) / d
	rotation = dir.angle() + PI / 2.0
	scale = Vector2(1.0, d / _frame_h)   # x = grosimea liniei, y = întinsă pe distanță
	global_position = (from_pos + to_pos) * 0.5
