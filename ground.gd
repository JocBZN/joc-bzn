extends Sprite2D

# Fundal infinit: textura se repetă (texture_repeat), iar "pardoseala" urmărește
# player-ul sărind din cell_size în cell_size px. Pentru că textura e la fel peste tot,
# săritura nu se vede — pare o lume nesfârșită.
@export var cell_size: int = 64

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	global_position = player.global_position.snapped(Vector2(cell_size, cell_size))
