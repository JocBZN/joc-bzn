extends StaticBody2D

# Aparatul EGT — cazinoul din lume. Când te apropii scrie „Press E to interact" (ca la statuie,
# cufăr și portal), iar la apăsare se OPREȘTE jocul și se deschide interfața din `casino.gd`
# („Let's go gambling"). Unde apar aparatele și cu ce șansă → `egts.gd`.
#
# Spre deosebire de statuie și de cufăr, aparatul NU se consumă: `poate_invoca()` întoarce
# mereu `true`, deci poți juca de câte ori vrei la același EGT. Ce te oprește e riscul, nu jocul.
#
# Poziția nodului = linia de SORTARE (Y-sort), NU talpa artei: arta coboară `ACOPERIRE_JOS`
# pixeli sub ea, ca player-ul care trece prin fața aparatului să fie desenat PESTE el. Fără asta,
# în clipa în care ai trece prin spate ți-ar rămâne picioarele afară, sub aparat. Același truc
# ca la copaci (`props.gd::sort_anchor`) și la statuie.

@export var interact_range: float = 190.0    # cât de aproape trebuie să fii ca să apară textul
@export var label_offset_y: float = -160.0   # cât de sus stă textul (îl citește `interact_ui.gd`)
@export var art_scale: float = 1.6           # cât de mare e aparatul pe ecran (arta e 68×111 px)

# Cât coboară arta SUB linia de sortare, în pixeli de LUME. Trebuie să fie mai mare decât
# jumătatea sprite-ului player-ului (~64px), altfel îi rămân picioarele afară când trece prin
# spate. 74 = cât au copacii și statuia. Dacă schimbi valoarea, mută și `CollisionShape2D`
# din `egt.tscn` cu aceeași cantitate, altfel hitbox-ul se dezlipește de aparat.
const ACOPERIRE_JOS := 74.0

func _ready() -> void:
	# „interactable" = tot ce poate afișa „Press E to interact" (statui, portaluri, cufere, EGT).
	add_to_group("interactable")
	var spr := $Sprite2D as Sprite2D
	spr.scale = Vector2(art_scale, art_scale)
	_aseaza_pe_origine(spr)

# Așază arta astfel încât BAZA ei să cadă cu ACOPERIRE_JOS sub originea nodului.
# Se calculează la rulare (nu cu un `offset` fix în scenă) fiindcă depinde de `art_scale`:
# schimbi scara din inspector și aparatul rămâne așezat corect, fără să mai umbli la offset.
func _aseaza_pe_origine(sprite: Sprite2D) -> void:
	if sprite.texture == null or sprite.scale.y == 0.0:
		return
	var used := sprite.texture.get_image().get_used_rect()
	var jos := float(used.position.y + used.size.y)   # marginea de jos a artei, în pixeli de textură
	sprite.offset.y = ACOPERIRE_JOS / sprite.scale.y - (jos - float(sprite.texture.get_height()) * 0.5)

# Mai poate fi folosit? La EGT mereu da — vezi comentariul de sus.
func poate_invoca() -> bool:
	return true

# Apăsarea tastei de interacțiune ajunge aici (din `interact_ui.gd`).
func invoca() -> void:
	var casino = get_tree().get_first_node_in_group("casino")
	if casino != null:
		casino.open()
