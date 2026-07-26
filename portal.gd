extends StaticBody2D

# Portal fix în lume — sora mai rară a statuii (vezi `statue.gd` și `portals.gd`).
# Imaginea + HITBOX-ul sunt în scena portal.tscn (editabile vizual în editor).
#
# Când player-ul se apropie apare deasupra lui textul „Press E to interact",
# exact ca la statuie (îl afișează `interact_ui.gd`, care se uită la grupul
# „interactable"). Apăsând E te duce în NETHER — a doua dimensiune (vezi `nether.gd`).
#
# ACELAȘI script joacă ambele roluri, după steagul `retur`:
#   • `retur = false` (portalurile din lume, puse de `portals.gd`) → INTRI în Nether;
#   • `retur = true`  (portalul pe care îl pune `nether.gd` unde ai aterizat) → IEȘI.
#
# Poziția nodului Portal = BAZA portalului (talpa) → și linia de la care te
# acoperă (Y-sort), la fel ca la statuie.

@export var interact_range: float = 200.0   # cât de aproape trebuie să fii ca să apară textul
@export var retur: bool = false             # true doar pe portalul de întoarcere din Nether

# ⚠️ HITBOX-ul și poziția artei se reglează MANUAL în editor, în `portal.tscn`.
# Scriptul NU le mai atinge la rulare, deci CE VEZI ÎN EDITOR = CE IESE ÎN JOC.
#
# Două lucruri de ținut minte când tragi de ele:
# 1. `Sprite2D.offset.y = -25.17` e calculat ca baza artei să cadă 74px SUB originea
#    nodului. Cifra 74 nu e la întâmplare: sprite-ul player-ului e CENTRAT pe punctul lui
#    de sortare, deci se întinde ~64px sub el. Dacă arta portalului urcă prea sus, când
#    player-ul trece prin spate îi rămân picioarele afară, sub portal. Copacii și statuia
#    folosesc tot 74. Deci: poți să cobori arta, dar nu s-o urci sub ~64.
# 2. Dacă muți Sprite2D pe verticală, mută `CollisionShape2D` cu ACEEAȘI valoare, altfel
#    hitbox-ul rămâne în urmă și te lovești de aer.

func _ready() -> void:
	# Se anunță în grupul pe care îl citește `interact_ui.gd`. Statuia e în același grup.
	add_to_group("interactable")

# Mai poate fi folosit? `interact_ui.gd` întreabă asta înainte să arate textul.
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
