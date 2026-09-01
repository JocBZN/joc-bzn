extends StaticBody2D

# POARTA CASTELULUI — ușa spre a patra dimensiune (`prison.gd`), a treia și ultima verigă din
# lanțul de uși: portal Nether → (cade Saratalin) → fântână Ender → (cade Celesto) → POARTA ASTA.
# O naște `prison_gates.gd`, generatorul ei propriu, aprins în clipa în care moare Celesto.
#
# ⚠️ ARTĂ PROPRIE DE PE 2026-09-01. Până azi poarta era `portal_ender.tscn` cu steagul `prison`
# pus înainte de `add_child`: ACEEAȘI fântână de piatră, doar spălată în verde-mucegai. Se vedea
# că e altceva doar dacă te uitai la etichetă. Acum e `harta/castle/Castle_Door_Portal.png`
# (Răzvan, 2026-09-01: „asta vreau să fie portalul pentru castle dimension") — arcadă de piatră,
# ușă dublă de lemn ferecat, doi gargui pe coloane. Steagul `prison` din `portal_ender.gd` a
# dispărut odată cu ea: fântâna Ender e iar doar fântână Ender.
#
# Steagul `retur` spune ce face apăsarea lui E, exact ca la fântână:
#   • `retur = false` → INTRI în castel;
#   • `retur = true`  → IEȘI (dacă a căzut SIR JOHN; altfel `prison.gd` refuză singur).
# E o SINGURĂ poartă, care își schimbă rolul — dimensiunile împart aceleași coordonate, deci ea e
# oricum fix acolo unde aterizezi. `prison.gd::enter` o mută în `World` (altfel ar șterge-o
# golirea decorului), îi aprinde `retur`, iar la ieșire i-l stinge.
#
# Ce cere `prison.gd` de la nodul ăsta, adică interfața care NU se schimbă fără să te uiți acolo:
# `retur`, `visible`, `process_mode`, `global_position`, `set_in_castel()` și `intra_in_pamant()`.
# Iar `interact_ui.gd` cere `interact_range`, `poate_invoca()`, `invoca()`, `eticheta()` și
# (opțional) `label_offset_y`.
#
# Poziția nodului NU e talpa: talpa vizibilă cade cu 74 px MAI JOS (offset −28,1667 × scara 2,4).
# Cifra 74 e aceeași la toate cele trei uși din joc (portal Nether, fântână Ender, poarta asta) —
# de aia `offset`-ul sprite-ului iese cu virgulă: e ales ca să nimerească exact 74, nu din ochi.
# Hitbox-ul se reglează CU MÂNA în editor, ca la statuie și la portal; scriptul nu-l atinge la
# rulare. Muți `Sprite2D` pe verticală → muți `CollisionShape2D` cu aceeași valoare.

const GroundShadow := preload("res://ground_shadow.gd")   # aceeași umbră ca la copaci și portaluri

@export var interact_range: float = 200.0   # cât de aproape trebuie să fii ca să apară textul
@export var retur: bool = false             # true doar cât ești ÎNĂUNTRU (atunci E înseamnă „ieși")

# Cât de sus stă „Enter the Castle" (`interact_ui.gd` citește proprietatea asta dacă există).
# Poarta e mai înaltă decât o fântână — vârful arcadei e la ~204 px deasupra nodului — deci pe
# valoarea obișnuită (−175) textul ar fi ieșit ÎN piatră, peste gargui.
@export var label_offset_y: float = -238.0

# --- cum stă pe sol ---
# Doar UMBRA: elipsa neagră obișnuită, aceeași pe care o au copacii și celelalte două uși, pe
# `z_index = -1` (adică pe podea, sub tot ce trece pe lângă ea). Lățimea, poziția și turtirea le
# calculează `ground_shadow.gd` din PIXELII REALI ai texturii, deci nu există cifre scrise de mână
# care s-ar desincroniza de artă dacă Răzvan redesenează poarta.
#
# ⚠️ Poarta a avut, câteva ore pe 2026-09-01, și LUMINĂ ALBASTRĂ aditivă: o baltă pe jos în fața
# ușii și crăpătura dintre canaturi, amândouă pe același puls. Răzvan a scos-o în aceeași zi
# („scoate lumina albastră de la portal"), deci ușa se citește acum doar din desen. Dacă se pune
# vreodată la loc, e în git la commit-ul `140296a`; de reținut de acolo un singur lucru, ca să nu
# se redescopere pe pielea altcuiva: lumina ADITIVĂ are nevoie de DOUĂ intensități, fiindcă pe
# nisip iese ALBĂ (canalele solului sunt deja aproape pline și mai aduni peste ele), iar pe
# lespedea aproape neagră a castelului aceeași cifră abia se vede.
@export var shadow_alpha: float = 0.45        # cât de închisă e umbra în lumea normală
@export var shadow_alpha_castel: float = 0.30 # pe lespezile castelului doar acoperă piatra
@export var shadow_width: float = 0.92        # fracție din lățimea vizibilă a porții
@export var shadow_squash: float = 0.30       # turtirea: înălțime / lățime
@export var shadow_shift_y: float = -18.0     # o urcă față de talpă (minus = în sus, sub piatră)
@export var fade_dimensiune: float = 0.8      # ca `DIM_FADE` din `atmosphere.gd`

# Închiderea definitivă (după ce ai bătut SIR JOHN și ai ieșit): intră în pământ, ca portalul
# Nether și fântâna Ender. O cheamă `prison.gd::_inchide_poarta`, odată cu cutremurul.
@export var sink_duration: float = 1.0
@export var sink_depth: float = 90.0

var _umbra: Sprite2D
var _in_castel := false
var _fade_tween: Tween

func _ready() -> void:
	add_to_group("interactable")   # de aici vine textul de deasupra (`interact_ui.gd`)
	_construieste_talpa()

# ⚠️ FĂRĂ `%s` și fără `tr()`. `interact_ui.gd` pune textul ăsta ca atare pe Label, iar Godot îl
# traduce singur — deci trebuie să fie EXACT cheia din `i18n.gd`. Dacă i-am lipi tasta („Press E
# to…"), cheia căutată ar fi textul deja compus, n-ar mai exista în tabel și ar rămâne englezesc
# în toate cele 9 limbi. Aceeași capcană ca la rândurile cu cifre din HUD.
func eticheta() -> String:
	return "Leave the Castle" if retur else "Enter the Castle"

# Poarta nu se consumă: intri și ieși de câte ori vrei, cât ține runda. Cine te oprește e
# `prison.gd` — cât trăiește SIR JOHN, `exit_prison()` iese din prima linie.
func poate_invoca() -> bool:
	return true

func invoca() -> void:
	var pris := get_tree().get_first_node_in_group("prison")
	if pris == null:
		return
	if retur:
		pris.exit_prison()
	else:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		# ne dăm pe NOI: cât ești dincolo, tot poarta asta e și ieșirea (`prison.gd::_poarta`)
		pris.enter(p, self)

# ---------- UMBRA ----------

func _construieste_talpa() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	_umbra = GroundShadow.make(sprite.texture, sprite, sprite.scale.x, shadow_alpha,
		shadow_width, shadow_squash, shadow_shift_y)
	add_child(_umbra)

# Chemată din `prison.gd`, lângă `retur`: intri în castel → `true`, ieși → `false`.
# Nu ne uităm singuri după grupul „prison" în fiecare cadru — cine ne schimbă rolul ne spune și cum
# să arătăm, exact ca `portal_ender.gd::set_cosmic`.
#
# Ce se schimbă: umbra slăbește, fiindcă pe lespedea cenușie a castelului o pată neagră tare arată
# ca o gaură în podea, nu ca o umbră.
func set_in_castel(on: bool) -> void:
	if _in_castel == on or _umbra == null:
		return
	_in_castel = on
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # moartea pune jocul pe pauză
	_fade_tween.tween_property(_umbra, "modulate:a",
		shadow_alpha_castel if on else shadow_alpha, fade_dimensiune)

# Chemată din `prison.gd::_inchide_poarta` când te întorci învingător: din clipa aia nu mai există
# porți în runda asta. Identic cu `portal.gd::intra_in_pamant()` și cu sora ei din `portal_ender.gd`.
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
	# Aici `modulate:a` CHIAR merge (spre deosebire de fântâna Ender, unde shaderul își citea
	# singur textura și îl ignora — de aia ea se stinge pe `shader_parameter/fade`). Poarta n-are
	# shader: e piatră desenată, nu lichid care se învârte.
	t.parallel().tween_property(sprite, "modulate:a", 0.0, sink_duration)
	# umbra se stinge odată cu ea — altfel ar rămâne o pată pe pământul gol
	if _umbra != null and is_instance_valid(_umbra):
		t.parallel().tween_property(_umbra, "modulate:a", 0.0, sink_duration)
	t.tween_callback(queue_free)
