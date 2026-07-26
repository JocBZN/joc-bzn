@tool
extends "res://hitbox_reglabil.gd"

# Portal fix în lume — sora mai rară a statuii (vezi `statue.gd` și `portals.gd`).
#
# Când player-ul se apropie apare deasupra lui textul „Press E to interact", exact ca la
# statuie (îl afișează `interact_ui.gd`). Apăsând E te duce în NETHER — a doua dimensiune
# (vezi `nether.gd`).
#
# ACELAȘI script joacă ambele roluri, după steagul `retur`:
#   • `retur = false` (portalurile din lume, puse de `portals.gd`) → INTRI în Nether;
#   • `retur = true`  (portalul pe care îl pune `nether.gd` unde ai aterizat) → IEȘI.
#
# Poziția nodului Portal = BAZA portalului (talpa) → și linia de la care te
# acoperă (Y-sort), la fel ca la statuie.
#
# BUTOANELE DE HITBOX (Nord/Sud/Est/Vest + Vezi Hitbox) vin din `hitbox_reglabil.gd` —
# explicația completă e acolo, în capul fișierului.
#
# Arta (poza) se reglează din `Sprite2D`. Un singur lucru de ținut minte acolo:
# `Sprite2D.offset.y = -25.17` e calculat ca baza artei să cadă 74px SUB originea nodului.
# Cifra 74 nu e la întâmplare: sprite-ul player-ului e CENTRAT pe punctul lui de sortare,
# deci se întinde ~64px sub el. Dacă arta urcă prea sus, când player-ul trece prin spate
# îi rămân picioarele afară, sub portal. Copacii și statuia folosesc tot 74. Deci: poți
# să cobori arta, dar nu s-o urci sub ~64.

@export var retur: bool = false   # true doar pe portalul de întoarcere din Nether

# --- Închiderea definitivă (după ce l-ai bătut pe Saratalin) ---
@export var sink_duration: float = 1.0   # cât durează scufundarea
@export var sink_depth: float = 90.0     # cât de adânc coboară (se stinge oricum în paralel)

# Portalul intră în pământ și dispare, ca statuia după invocare. Chemat din `nether.gd`
# când te întorci învingător: din clipa aia nu mai există portaluri în runda asta.
func intra_in_pamant() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)   # nu mai e zid cât coboară
	remove_from_group("interactable")        # și nu mai poți apăsa E pe el
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		queue_free()
		return
	var t := sprite.create_tween()
	t.set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "position:y", sprite.position.y + sink_depth, sink_duration)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, sink_duration)
	t.tween_callback(queue_free)

# Portalul nu se consumă — intri și ieși de câte ori vrei.
func poate_invoca() -> bool:
	return true

# Apăsarea tastei de interacțiune ajunge aici: te duce în Nether sau te aduce înapoi.
func invoca() -> void:
	var nether := get_tree().get_first_node_in_group("nether")
	if nether == null:
		return
	if retur:
		nether.exit_nether()
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		# îi dăm și locul nostru: portalul de întoarcere din Nether se pune exact aici
		nether.enter(player, global_position)
