extends StaticBody2D

# ALBA-NEAGRA — omul cu trei pahare (`harta/Alba Neagra/Alba Neagra.png`). Apeși E pe el și se
# deschide jocul de ghicit bila (`alba_menu.gd`). Unde apar oamenii ăștia în lume → `albas.gd`.
#
# ⚠️ Spre deosebire de aparatul EGT, care nu se consumă niciodată, **un om joacă o SINGURĂ dată**
# (cerut de Răzvan pe 2026-08-11): odată ce ai început prima rundă la el, își strânge paharele —
# și rămâne consumat chiar dacă pleci din zonă și te întorci, fiindcă `albas.gd` ține minte locul
# (același tipar ca la cufere, `chests.gd::marcheaza_folosit`).
#
# Poziția nodului = linia de SORTARE (Y-sort), NU talpa artei: arta coboară `ACOPERIRE_JOS`
# pixeli sub ea, ca player-ul care trece prin fața lui să fie desenat PESTE el. Același truc ca
# la aparatul EGT, la copaci și la statuie.

@export var interact_range: float = 190.0    # cât de aproape trebuie să fii ca să apară textul
@export var label_offset_y: float = -150.0   # cât de sus stă textul (îl citește `interact_ui.gd`)
@export var art_scale: float = 1.6           # cât de mare e pe ecran (arta e 128×128)

const ACOPERIRE_JOS := 74.0

# ⚠️ `Sprite2D` din `alba.tscn` are scrise ÎN SCENĂ exact valorile pe care le pune `_ready()`
# (`scale = 1.6`, `offset.y = -13.75`). Nu le folosește jocul — el le recalculează oricum — sunt
# acolo DOAR ca editorul să arate omul la mărimea și în locul din joc, altfel potrivești
# `CollisionShape2D` după o imagine mai mică și mai sus decât cea adevărată (2026-08-12).
# Schimbi `art_scale`, `ACOPERIRE_JOS` sau poza? Rescrie și cifrele din scenă, altfel editorul
# minte din nou — în tăcere. Formula e `_aseaza_pe_origine` de mai jos.

# --- RESPIRAȚIA (cerută de Răzvan: „să nu pară așa static") ---
# Un singur sprite, deci nu putem mișca omul fără să mișcăm și masa lui. Ce se poate face fără
# să se rupă desenul: îl întindem pe VERTICALĂ cu câteva miimi, cu pivotul FIX PE TALPĂ. Masa,
# fiind jos, stă practic pe loc (0,2 px), iar umerii urcă și coboară ~2px — cât respiră un om.
#
# ⚠️ Pivotul trebuie să fie talpa artei, nu centrul: cu pivotul în centru, masa ar fi coborât în
# pământ la fiecare inspirație și s-ar fi văzut cum plutește. `_aseaza_pe_origine` ne dă exact
# unde e talpa, deci pivotul iese din același calcul.
const RESP_SCALA := 1.018    # cât se întinde la inspirație (1.0 = deloc)
const RESP_TIMP := 2.3       # cât ține o inspirație (secunde); expirația ține la fel

var _folosit := false

func _ready() -> void:
	# „interactable" = tot ce poate afișa „Press E to interact" (statui, portaluri, cufere, EGT).
	add_to_group("interactable")
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
# Un Sprite2D se scalează din CENTRUL lui, nu dintr-un pivot pe care să-l putem muta. Ca talpa să
# rămână lipită de pământ, coborâm desenul cu exact cât l-ar ridica întinderea. Marginea de jos,
# în pixeli de nod, e `(offset.y + H/2) × scale.y`; ca ea să iasă aceeași la scala `k` ori mai
# mare, offset-ul trebuie să scadă cu `talpa × (k−1) / k`.
func _respira(spr: Sprite2D) -> void:
	var talpa := spr.offset.y + float(spr.texture.get_height()) * 0.5   # în pixeli de TEXTURĂ
	var dy := talpa * (RESP_SCALA - 1.0) / RESP_SCALA
	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(spr, "scale:y", art_scale * RESP_SCALA, RESP_TIMP)
	t.parallel().tween_property(spr, "offset:y", spr.offset.y - dy, RESP_TIMP)
	t.tween_property(spr, "scale:y", art_scale, RESP_TIMP)
	t.parallel().tween_property(spr, "offset:y", spr.offset.y, RESP_TIMP)

# Mai poate fi folosit? `interact_ui.gd` întreabă asta înainte să arate textul.
# `false` după ce a fost jucat, ca la cufărul deschis: un om care și-a strâns paharele n-are ce
# să-ți mai spună, iar un „Press E" care nu face nimic arată a bug.
func poate_invoca() -> bool:
	return not _folosit

# Apăsarea tastei de interacțiune ajunge aici (din `interact_ui.gd`).
func invoca() -> void:
	if _folosit:
		return
	var meniu = get_tree().get_first_node_in_group("alba_menu")
	if meniu != null:
		meniu.open(self)

# Chemată de meniu în clipa în care începe PRIMA rundă (nu la deschiderea meniului: dacă doar te
# uiți și pleci, omul rămâne întreg).
func consuma() -> void:
	if _folosit:
		return
	_folosit = true
	# generatorul ține minte locul, ca omul să nu revină întreg când chunk-ul se descarcă și se
	# regenerează — se întâmplă și dacă te îndepărtezi și revii, și la fiecare intrare/ieșire din
	# Nether, Ender sau Limbo (ele golesc toate generatoarele). Același tipar ca la cufăr.
	var gen := get_parent()
	while gen != null and not gen.has_method("marcheaza_folosit"):
		gen = gen.get_parent()
	if gen != null:
		gen.marcheaza_folosit(global_position)
	# se stinge pe loc: nu mai e nimic de jucat aici
	var t := create_tween()
	t.tween_property(self, "modulate", Color(0.55, 0.55, 0.58), 0.5)
