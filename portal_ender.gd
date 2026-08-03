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
@export var shadow_alpha: float = 0.42        # cât de închisă e umbra în lumea normală
@export var shadow_alpha_ender: float = 0.30  # mai slabă dincolo: acolo doar acoperă stele
# ⚠️ `shadow_width` e PESTE 1 (copacii au 0.60) și `shadow_shift_y` e POZITIV (ei îl au negativ).
# Nu e o cifră aleasă din ochi: fântâna e un butoi rotund, lat cât toată silueta, așa că o elipsă
# de 60% i-ar sta întreagă ASCUNSĂ în spate — prima variantă chiar a ieșit invizibilă în joc.
# Ca să se vadă, trebuie să fie puțin mai lată decât piatra și împinsă sub ea. Copacii n-au
# problema asta: acolo umbra iese în lături de sub un trunchi subțire.
@export var shadow_width: float = 1.02        # fracție din lățimea vizibilă a fântânii
@export var shadow_squash: float = 0.26       # turtirea: înălțime / lățime
@export var shadow_shift_y: float = 10.0      # o urcă/coboară față de talpă
@export var halo_color: Color = Color(0.42, 0.32, 1.0)
@export var halo_alpha_lume: float = 0.16     # abia se simte pe iarbă
@export var halo_alpha_ender: float = 0.55    # dincolo e el ancora
@export var halo_scale: float = 1.7           # de câte ori e mai lat decât umbra
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
