extends StaticBody2D

# DUBIOSU — omul în palton negru și pălărie (`harta/dubiosu.png`), pus în lume pe 2026-08-12.
# Unde apare → `dubiosi.gd`.
#
# ⚠️ DEOCAMDATĂ NU FACE NIMIC, așa a cerut Răzvan. Stă în iarbă, respiră și te oprește dacă dai
# să treci prin el — atât. NU e în grupul „interactable", deci `interact_ui.gd` nici nu se uită
# la el: nu apare „Press E to interact" și n-are `invoca()`. Când primește o treabă, se adaugă
# amândouă (`add_to_group("interactable")` + `invoca()`, plus `poate_invoca()` dacă se consumă) —
# vezi `alba.gd`, care le are pe toate trei.
#
# Poziția nodului = linia de SORTARE (Y-sort), NU talpa artei: arta coboară `ACOPERIRE_JOS`
# pixeli sub ea, ca player-ul care trece prin fața lui să fie desenat PESTE el. Același truc ca
# la omul de Alba-Neagra, la aparatul EGT, la copaci și la statuie.

@export var art_scale: float = 1.6           # cât de mare e pe ecran (arta e 128×128)

const ACOPERIRE_JOS := 74.0

# ⚠️ `Sprite2D` din `dubiosu.tscn` are scrise ÎN SCENĂ exact valorile pe care le pune `_ready()`
# (`scale = 1.6`, `offset.y = -12.75`). Nu le folosește jocul — el le recalculează oricum — sunt
# acolo DOAR ca editorul să arate omul la mărimea și în locul din joc, altfel potrivești
# `CollisionShape2D` după o imagine mai mică și mai sus decât cea adevărată.
# Schimbi `art_scale`, `ACOPERIRE_JOS` sau poza? Rescrie și cifrele din scenă, altfel editorul
# minte, în tăcere. Formula e `_aseaza_pe_origine` de mai jos.
#
# Cifrele artei lui (măsurate): desenul ocupă x 31…97, y 8…123 din cele 128×128, deci e lat de
# 66 px și înalt de 115, centrat pe mijlocul pozei.

# --- RESPIRAȚIA (o are și omul de Alba-Neagra: „să nu pară așa static") ---
# Îl întindem pe VERTICALĂ cu câteva miimi, cu pivotul FIX PE TALPĂ: pălăria urcă și coboară
# ~2 px, tălpile stau pe loc.
#
# ⚠️ Pivotul trebuie să fie talpa, nu centrul: un `Sprite2D` se scalează din centrul lui, deci cu
# pivotul implicit i-ar intra picioarele în pământ la fiecare inspirație și s-ar vedea cum
# plutește. De aia coborâm `offset.y` cu exact cât l-ar ridica întinderea (calculul din `_respira`).
const RESP_SCALA := 1.018    # cât se întinde la inspirație (1.0 = deloc)
const RESP_TIMP := 2.3       # cât ține o inspirație (secunde); expirația ține la fel

func _ready() -> void:
	var spr := $Sprite2D as Sprite2D
	spr.scale = Vector2(art_scale, art_scale)
	_aseaza_pe_origine(spr)
	_respira(spr)

# Așază arta astfel încât BAZA ei să cadă cu ACOPERIRE_JOS sub originea nodului.
# Se calculează la rulare (nu cu un `offset` fix în scenă) fiindcă depinde de `art_scale`.
func _aseaza_pe_origine(sprite: Sprite2D) -> void:
	if sprite.texture == null or sprite.scale.y == 0.0:
		return
	var used := sprite.texture.get_image().get_used_rect()
	var jos := float(used.position.y + used.size.y)   # marginea de jos a artei, în pixeli de textură
	sprite.offset.y = ACOPERIRE_JOS / sprite.scale.y - (jos - float(sprite.texture.get_height()) * 0.5)

# Respirația: `scale.y` dus-întors, cu talpa ținută pe loc din `offset`.
#
# Marginea de jos, în pixeli de nod, e `(offset.y + H/2) × scale.y`; ca ea să iasă aceeași la
# scala `k` ori mai mare, offset-ul trebuie să scadă cu `talpa × (k−1) / k`.
func _respira(spr: Sprite2D) -> void:
	var talpa := spr.offset.y + float(spr.texture.get_height()) * 0.5   # în pixeli de TEXTURĂ
	var dy := talpa * (RESP_SCALA - 1.0) / RESP_SCALA
	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(spr, "scale:y", art_scale * RESP_SCALA, RESP_TIMP)
	t.parallel().tween_property(spr, "offset:y", spr.offset.y - dy, RESP_TIMP)
	t.tween_property(spr, "scale:y", art_scale, RESP_TIMP)
	t.parallel().tween_property(spr, "offset:y", spr.offset.y, RESP_TIMP)
