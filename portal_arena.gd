extends StaticBody2D

# PORTALUL ARENEI — ușa spre lupta finală (`arena.gd`), cu toți trei boșii deodată.
# Cerut de Răzvan pe 2026-10-28: „portalul vreau să îl iei pe ăla de la Saratalin și să îi schimbi
# culoarea (de la animația de la portal doar, el să rămână tot așa de piatră)".
#
# Deci `portal_arena.tscn` e `portal.tscn` (arcada Nether-ului) cu ACEEAȘI piatră
# (`harta/Portal 1.png`) și ACELAȘI shader de vâltoare (`portal_nether.gdshader`) — s-au schimbat
# doar cele patru culori ale vâltorii, din mov în roșu-sânge cu scântei aurii, plus un puls puțin
# mai iute. Dacă vrei altă culoare, sunt `shader_parameter/culoare_*` din .tscn, nu cod.
#
# Răsar pe hartă din `arena_portals.gd`, abia după ce cade SIR JOHN (`prison.gd::boss_invins`).
#   • `retur = false` → E te duce în arenă;
#   • `retur = true`  → ești în arenă și E te scoate — dar numai după ce i-ai bătut pe toți trei
#     (altfel `arena.gd::exit_arena` refuză singur, cu anunț).

@export var interact_range: float = 200.0   # cât de aproape trebuie să fii ca să apară textul
@export var retur: bool = false

@export var sink_duration: float = 1.0
@export var sink_depth: float = 90.0

func _ready() -> void:
	add_to_group("interactable")   # de aici vine „Press E" de deasupra (`interact_ui.gd`)

func eticheta() -> String:
	return "Leave the Arena" if retur else "Enter the Arena"

func poate_invoca() -> bool:
	return true

func invoca() -> void:
	var arena := get_tree().get_first_node_in_group("arena")
	if arena == null:
		return
	if retur:
		arena.exit_arena()
	else:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		arena.enter(p, self)

# Ieși învingător → portalul intră în pământ, ca arcada Nether-ului (copiat din `portal.gd`, cu
# aceeași capcană: vâltoarea se stinge pe `shader_parameter/fade`, nu pe `modulate`).
func intra_in_pamant() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)
	remove_from_group("interactable")
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		queue_free()
		return
	var t := sprite.create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "position:y", sprite.position.y + sink_depth, sink_duration)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, sink_duration)
	var vartej := get_node_or_null("Vartej") as Sprite2D
	if vartej != null:
		t.parallel().tween_property(vartej, "position:y", vartej.position.y + sink_depth, sink_duration)
		var mat := vartej.material as ShaderMaterial
		if mat != null:
			t.parallel().tween_property(mat, "shader_parameter/fade", 0.0, sink_duration)
	t.tween_callback(queue_free)
