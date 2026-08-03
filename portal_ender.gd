extends StaticBody2D

# FÂNTÂNA ENDER — ușa spre a treia dimensiune (`ender.gd`). Sora portalului de piatră
# (`portal.gd`), cu aceleași reguli, dar cu o singură deosebire mare: **nu o găsești umblând
# prin lume.** Apare o singură dată pe rundă, în locul unde s-a scufundat portalul Nether-ului,
# după ce l-ai bătut pe Saratalin și te-ai întors viu (vezi `nether.gd::_inchide_portalurile`).
#
# Steagul `retur` spune ce face apăsarea lui E:
#   • `retur = false` → INTRI în Ender;
#   • `retur = true`  → IEȘI.
# Spre deosebire de portalul de piatră (unde sunt DOUĂ noduri, unul în lume și unul pus de
# `nether.gd` dincolo), aici e o SINGURĂ fântână, care își schimbă rolul: dimensiunile împart
# aceleași coordonate, deci ea e oricum exact acolo unde aterizezi. `ender.gd` îi aprinde
# `retur` la intrare și i-l stinge la ieșire.
#
# Poziția nodului = BAZA fântânii (talpa) și linia de la care te acoperă (Y-sort).
# Hitbox-ul se reglează CU MÂNA în editor, ca la statuie și la portal — scriptul nu-l atinge
# niciodată la rulare. Dacă muți `Sprite2D` pe verticală, mută `CollisionShape2D` cu aceeași
# valoare, altfel te lovești de aer.

@export var interact_range: float = 200.0   # cât de aproape trebuie să fii ca să apară textul
@export var retur: bool = false             # true doar pe fântâna de întoarcere din Ender

# Închiderea definitivă (după ce ai ieșit învingător): intră în pământ, ca portalul Nether-ului.
@export var sink_duration: float = 1.0
@export var sink_depth: float = 90.0

func _ready() -> void:
	add_to_group("interactable")   # de aici vine textul „Press E to interact" (`interact_ui.gd`)

# Fântâna nu se consumă — intri și ieși de câte ori vrei, cât ține runda.
func poate_invoca() -> bool:
	return true

func invoca() -> void:
	var ender := get_tree().get_first_node_in_group("ender")
	if ender == null:
		return
	if retur:
		ender.exit_ender()
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		# ne dăm pe NOI: cât ești dincolo, tot fântâna asta e și ieșirea (`ender.gd::_fantana`)
		ender.enter(player, self)

# Chemată din `ender.gd` când te întorci învingător: din clipa aia nu mai există fântâni în
# runda asta. Identic cu `portal.gd::intra_in_pamant()`.
func intra_in_pamant() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)   # nu mai e zid cât coboară
	remove_from_group("interactable")        # și nu mai poți apăsa E pe ea
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		queue_free()
		return
	var t := sprite.create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "position:y", sprite.position.y + sink_depth, sink_duration)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, sink_duration)
	t.tween_callback(queue_free)
