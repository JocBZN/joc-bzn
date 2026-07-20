extends Node2D
const MAIN := preload("res://main.tscn")
func _ready() -> void:
	add_child(MAIN.instantiate())
	await get_tree().create_timer(0.4).timeout
	var lv: Node = get_tree().get_first_node_in_group("levelup_menu")
	var pe_rar := {}
	for u in lv.UPGRADES:
		var r: String = str(u.get("rar", "common"))
		if not pe_rar.has(r):
			pe_rar[r] = []
		pe_rar[r].append(u)
	print("TOTAL=%d" % lv.UPGRADES.size())
	for r in ["legendary", "epic", "rare", "uncommon", "common"]:
		var lista: Array = pe_rar.get(r, [])
		print("--- %s: %d" % [r, lista.size()])
		for u in lista:
			print("   %s|%s|%s|%s" % [str(u["id"]), str(u["nume"]), str(u["icon"]), str(u["desc"])])
	get_tree().quit()
