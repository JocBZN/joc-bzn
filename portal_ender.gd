extends StaticBody2D

# FÂNTÂNA ENDER — ușa spre a treia dimensiune (`ender.gd`). Sora portalului de piatră
# (`portal.gd`), cu aceleași reguli, dar cu o deosebire mare: **în prima parte a rundei nu
# există niciuna.** Apar toate deodată, după ce l-ai bătut pe Saratalin și te-ai întors viu:
# generatorul de portaluri trece pe fântâni (`portals.gd::treci_pe_ender`), așa că fiecare loc
# de portal Nether de pe hartă naște una — inclusiv cel de sub picioarele tale, unde tocmai
# s-a scufundat portalul prin care ai ieșit (vezi `nether.gd::_inchide_portalurile`).
# Cad la rândul lor când bați Undead Executioner-ul și ieși din Ender (`ender.gd`).
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

const GroundShadow := preload("res://ground_shadow.gd")   # aceeași umbră ca la copaci și cactuși

@export var interact_range: float = 200.0   # cât de aproape trebuie să fii ca să apară textul
@export var retur: bool = false             # true doar pe fântâna de întoarcere din Ender

# Închiderea definitivă (după ce ai ieșit învingător): intră în pământ, ca portalul Nether-ului.
@export var sink_duration: float = 1.0
@export var sink_depth: float = 90.0

# --- cum stă pe sol ---
# Fântâna are DOUĂ pete la bază, una peste alta, ambele pe `z_index = -1` (deci pe podea, sub
# tot ce trece pe lângă ea):
#   • UMBRA, elipsă neagră — ancora obișnuită, ca la copaci;
#   • HALOUL, aceeași elipsă dar violet și mai lată, care respiră încet — lumina bălții din ea.
# De ce amândouă: în lumea normală umbra face treaba, dar în ENDER podeaua e o nebuloasă
# aproape neagră, iar negru pe negru nu se vede. Acolo urcă haloul, iar piatra se stinge puțin
# (`ender_tint`) — altfel fântâna e cel mai luminos lucru de pe ecran și stă ca un abțibild.
@export var shadow_alpha: float = 0.45        # cât de închisă e umbra în lumea normală
@export var shadow_alpha_ender: float = 0.30  # mai slabă dincolo: acolo doar acoperă stele
# ⚠️ Cele trei cifre de mai jos sunt STRÂNS legate între ele, și fiecare e reglată pe capturi, nu
# din cap (Răzvan, 2026-08-04: „e proasta umbra la portalu de ender", apoi „fă fix înconjuru ei,
# adică umbra trebuie pusă mai sus și mai mare").
#
# Fântâna e un butoi ROTUND, lat cât toată silueta — nu un copac cu trunchi subțire, deci umbra
# nu e o baltă sub un punct de sprijin, ci CERCUL pe care stă butoiul, umflat puțin. Măsurat în
# pixelii texturii: talpa e o elipsă lată de ~72 px, înaltă de ~26 (marginile din lateral la
# y=99, botul din față la y=112) — adică turtirea ei reală e ~0.36, nu 0.18, iar CENTRUL ei e cu
# ~33 px (în coordonatele nodului) mai sus decât `base_y`, care e chiar botul de jos al pietrei.
# De aia arătau prost variantele de dinainte: elipsa era pusă cu centrul pe bot, deci ieșea toată
# în JOS, pe iarbă, ca o pată de murdărie, și turtită prea tare ca să se vadă pe lateral.
# Reglajul bun: centrul elipsei pe centrul tălpii (`shift_y` ≈ -33) și puțin mai mare decât ea
# (lățime 1.15, turtire 0.42) → rămâne un inel de umbră de jur împrejur, egal în stânga, în
# dreapta și în față; partea de sus intră firesc sub piatră.
@export var shadow_width: float = 1.15        # fracție din lățimea vizibilă a fântânii
@export var shadow_squash: float = 0.42       # turtirea: înălțime / lățime (talpa reală ≈ 0.36)
@export var shadow_shift_y: float = -33.0     # o urcă/coboară față de talpă (minus = în sus, sub piatră)
@export var halo_color: Color = Color(0.42, 0.32, 1.0)
# Rămâne 0.16: la reglarea umbrei am pus una lângă alta o poză cu haloul așa și una cu el la
# 0.09, pe aceeași iarbă, și nu se deosebesc. Deci pata mare de dinainte era a UMBREI, nu a lui —
# iar coborât și el, s-ar fi stins degeaba și în Ender, unde chiar ține fântâna pe podea.
@export var halo_alpha_lume: float = 0.16     # abia se simte pe iarbă
@export var halo_alpha_ender: float = 0.55    # dincolo e el ancora
@export var halo_scale: float = 1.5           # de câte ori e mai lat decât umbra (1.15 × 1.5 ≈ cât era)
@export var halo_puls: float = 0.16           # cât respiră (fracție din mărime)
@export var halo_puls_timp: float = 2.2       # cât ține o inspirație
@export var ender_tint: Color = Color(0.80, 0.84, 1.0)   # cât se stinge piatra în Ender
@export var fade_dimensiune: float = 0.8      # ca `DIM_FADE` din `atmosphere.gd`

var _umbra: Sprite2D
var _halou: Sprite2D
var _cosmic := false          # suntem în Ender?
var _fade_tween: Tween

func _ready() -> void:
	add_to_group("interactable")   # de aici vine textul „Press E to interact" (`interact_ui.gd`)
	_construieste_talpa()

# Haloul se adaugă ÎNAINTEA umbrei: amândouă sunt pe `z_index = -1`, deci le desparte ordinea
# din arbore, iar umbra trebuie să cadă PESTE lumină (întâi bate lumina, apoi vine contactul).
# Lățimea, poziția și turtirea le calculează `ground_shadow.gd` din pixelii reali ai texturii,
# deci nu există cifre scrise de mână care s-ar putea desincroniza de artă.
func _construieste_talpa() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var sc: float = sprite.scale.x
	var tex := sprite.texture
	_halou = GroundShadow.make(tex, sprite, sc, halo_alpha_lume,
		shadow_width * halo_scale, shadow_squash, shadow_shift_y)
	_halou.modulate = Color(halo_color, halo_alpha_lume)
	add_child(_halou)
	_umbra = GroundShadow.make(tex, sprite, sc, shadow_alpha,
		shadow_width, shadow_squash, shadow_shift_y)
	add_child(_umbra)
	_porneste_pulsul()

# Respirația haloului. Tween pe nodul lui, în buclă — se oprește singur când fântâna se scufundă
# și nodul e șters.
func _porneste_pulsul() -> void:
	if _halou == null:
		return
	var baza := _halou.scale
	var t := _halou.create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(_halou, "scale", baza * (1.0 + halo_puls), halo_puls_timp)
	t.tween_property(_halou, "scale", baza, halo_puls_timp)

# Chemată din `ender.gd`, lângă `retur`: intri dincolo → `true`, ieși → `false`.
# Nu ne uităm singuri după grupul „ender" în fiecare cadru — cine ne schimbă rolul ne spune și
# cum să arătăm, exact ca la `retur`.
func set_cosmic(on: bool) -> void:
	if _cosmic == on or _halou == null:
		return
	_cosmic = on
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # vezi `atmosphere.gd`: moartea pune jocul pe pauză
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_halou, "modulate:a",
		halo_alpha_ender if on else halo_alpha_lume, fade_dimensiune)
	if _umbra != null:
		_fade_tween.tween_property(_umbra, "modulate:a",
			shadow_alpha_ender if on else shadow_alpha, fade_dimensiune)
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		# doar RGB — alfa rămâne a lui, ca scufundarea să și-o poată anima liniștită
		var c := ender_tint if on else Color(1, 1, 1)
		c.a = sprite.modulate.a
		_fade_tween.tween_property(sprite, "modulate", c, fade_dimensiune)

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
	# umbra și haloul se sting odată cu ea — altfel ar rămâne o pată pe pământul gol
	for pata in [_umbra, _halou]:
		if pata != null and is_instance_valid(pata):
			t.parallel().tween_property(pata, "modulate:a", 0.0, sink_duration)
	t.tween_callback(queue_free)
