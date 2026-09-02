extends Node

# Porneste jocul pe DRUMUL REAL — `loading.tscn` (deci cu `PreloadAll` facut) -> meniu -> START —
# si lasa pe `root` un observator care supravietuieste schimbarilor de scena. Tot ce se verifica
# si de ce e nevoie de drumul intreg sta scris in `tool_intro_real_obs.gd`.
#
# ⚠️ Ruleaza FERESTRUIT, ca sa iasa pozele:
#   godot --path <proj> res://tool_intro_real.tscn

func _ready() -> void:
	# ⚠️ `call_deferred`: in `_ready` arborele e ocupat cu adaugatul copiilor, deci nici
	# `root.add_child()`, nici `change_scene_to_file()` nu se pot face de aici.
	_porneste.call_deferred()

func _porneste() -> void:
	var obs: Node = preload("res://tool_intro_real_obs.gd").new()
	obs.name = "ObservatorIntro"
	get_tree().root.add_child(obs)
	obs.porneste()
	get_tree().change_scene_to_file("res://loading.tscn")
