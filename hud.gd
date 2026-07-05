extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	health_bar.max_value = player.max_hp
	health_bar.value = player.hp
