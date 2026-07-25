extends StaticBody2D

# Portal fix în lume — sora mai rară a statuii (vezi `statue.gd` și `portals.gd`).
# Imaginea + HITBOX-ul sunt în scena portal.tscn (editabile vizual în editor).
#
# Când player-ul se apropie apare deasupra lui textul „Press E to interact",
# exact ca la statuie (îl afișează `interact_ui.gd`, care se uită la grupul
# „interactable"). ATENȚIE: deocamdată apăsarea tastei NU FACE NIMIC — e doar
# schela. Când vrei să facă ceva (teleportare, deschis o zonă etc.), scrii în
# `invoca()` de mai jos; restul (raza, textul, tasta) e deja pus la punct.
#
# Poziția nodului Portal = BAZA portalului (talpa) → și linia de la care te
# acoperă (Y-sort), la fel ca la statuie.

@export var interact_range: float = 200.0   # cât de aproape trebuie să fii ca să apară textul

# Cât coboară arta SUB linia de sortare (pixeli de ecran). Trebuie să fie mai mare decât
# jumătatea sprite-ului player-ului (~64px), altfel îi rămân picioarele afară când trece
# prin spatele portalului. 74 = cât au copacii și statuia.
const ACOPERIRE_JOS := 74.0

func _ready() -> void:
	_aseaza_pe_origine($Sprite2D as Sprite2D)
	# Se anunță în grupul pe care îl citește `interact_ui.gd`. Statuia e în același grup.
	add_to_group("interactable")

# Mai poate fi folosit? `interact_ui.gd` întreabă asta înainte să arate textul.
# Portalul n-are (încă) o stare de „consumat", deci mereu `true`.
func poate_invoca() -> bool:
	return true

# Apăsarea tastei de interacțiune ajunge aici. GOL INTENȚIONAT — portalul încă nu face nimic.
func invoca() -> void:
	pass

# Așază arta astfel încât baza ei desenată să cadă cu ACOPERIRE_JOS sub originea nodului.
# Se calculează la rulare (nu cu un `offset` fix din scenă) fiindcă imaginea are gol
# transparent în jur — `get_used_rect()` ne dă exact zona desenată. Copiat din `statue.gd`.
func _aseaza_pe_origine(sprite: Sprite2D) -> void:
	if sprite == null or sprite.texture == null or sprite.scale.y == 0.0:
		return
	var used := sprite.texture.get_image().get_used_rect()
	var jos := float(used.position.y + used.size.y)   # marginea de jos a artei, în pixeli de textură
	sprite.offset.y = ACOPERIRE_JOS / sprite.scale.y - (jos - float(sprite.texture.get_height()) * 0.5)
