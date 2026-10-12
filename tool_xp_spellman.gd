extends Node

func _sim(caracter: String, iteme: Array) -> String:
	GameSettings.character = caracter
	GameSettings.reset_run()
	var p: Node = load("res://player.tscn").instantiate()
	add_child(p)
	var lvl := CanvasLayer.new()
	lvl.set_script(load("res://levelup.gd"))
	add_child(lvl)
	await get_tree().process_frame
	for id in iteme:
		lvl._apply(id, p)
	var s := "%s %s: start %d ->" % [caracter, str(iteme), p.xp_to_next]
	for i in 15:
		p._level_up(false)
		s += " %d" % p.xp_to_next
	p.queue_free()
	lvl.queue_free()
	return s

func _ready() -> void:
	var u = GameSettings.unlocked.duplicate()
	for c in [["spellman", ["tome_knowledge"]], ["spellman", ["tome_knowledge", "tome_knowledge"]], ["spellman", ["tome_knowledge", "grinder"]], ["spellman", ["tome_knowledge", "grinder", "grinder"]], ["grasu", ["tome_knowledge", "tome_knowledge"]]]:
		print(await _sim(c[0], c[1]))
	GameSettings.unlocked = u
	get_tree().quit()
