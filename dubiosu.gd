extends StaticBody2D

# DUBIOSU — omul în palton negru și pălărie (`harta/dubiosu.png`), pus în lume pe 2026-08-12.
# De pe 2026-08-14 stă NUMAI în Nether → vezi `dubiosi.gd`.
#
# Apeși E pe el și joci un 1v1 de barbut (`dubios_menu.gd`): dă el primul, îți spune miza și
# alegi dacă dai și tu. Îl bați → un status la întâmplare crește cu 25%; pierzi → un status scade
# cu 25% și jocul devine cu 10% mai greu. (Până pe 2026-08-14 îți vindea patru iteme care nu
# existau nicăieri altundeva; au fost scoase de tot din joc.)
#
# ⚠️ Cu un om joci o SINGURĂ dată, ca la omul de Alba-Neagra: după aia își strânge paltonul și
# rămâne consumat chiar dacă pleci din zonă și te întorci, fiindcă `dubiosi.gd` ține minte locul
# (același tipar ca la cufere, `chests.gd::marcheaza_folosit`).
#
# Poziția nodului = linia de SORTARE (Y-sort), NU talpa artei: arta coboară `ACOPERIRE_JOS`
# pixeli sub ea, ca player-ul care trece prin fața lui să fie desenat PESTE el. Același truc ca
# la omul de Alba-Neagra, la aparatul EGT, la copaci și la statuie.

@export var interact_range: float = 190.0    # cât de aproape trebuie să fii ca să apară textul
@export var label_offset_y: float = -150.0   # cât de sus stă textul (îl citește `interact_ui.gd`)
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

# ---------------------------------------------------------------------------
# INTERACȚIUNEA (`interact_ui.gd` cere metodele astea de la orice „interactable")
# ---------------------------------------------------------------------------
# Mai poate fi folosit? `false` după ce ai jucat o dată cu el, ca la cufărul deschis: un „Press E"
# care nu face nimic arată a bug.
func poate_invoca() -> bool:
	return not _folosit

func invoca() -> void:
	if _folosit:
		return
	var meniu = get_tree().get_first_node_in_group("dubios_menu")
	if meniu == null:
		return
	# Se consumă la DESCHIDERE, nu la sfârșitul mâinii: zarurile au ieșit deja din palton, iar el
	# a și dat. Dacă apeși WALK AWAY după ce-i vezi suma, omul rămâne ars — atâta te costă
	# retragerea (vezi capul lui `dubios_menu.gd`).
	consuma()
	meniu.open(self)

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
	# se stinge pe loc: nu mai are ce să-ți vândă
	var t := create_tween()
	t.tween_property(self, "modulate", Color(0.55, 0.55, 0.58), 0.5)
