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
# `retur`, `visible`, `process_mode`, `global_position` și `intra_in_pamant()`. Iar `interact_ui.gd`
# cere `interact_range`, `poate_invoca()`, `invoca()`, `eticheta()` și (opțional) `label_offset_y`.
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
# Trei straturi la bază, toate pe `z_index = -1` (adică pe podea, sub tot ce trece pe lângă ea):
#   • BALTA DE LUMINĂ, aditivă — lumina care scapă pe sub ușă, mai lată decât ușa;
#   • UMBRA, elipsă neagră — ancora obișnuită, pusă PESTE lumină (întâi bate lumina, apoi vine
#     contactul cu pământul);
#   • iar peste piatră, dar tot aditivă, CRĂPĂTURA: lumina dintre cele două canaturi.
# De ce e nevoie de lumină: o ușă închisă, desenată în pietre cenușii, e decor — arată ca o ruină
# pe lângă care treci. Fântâna Ender avea aceeași problemă și a rezolvat-o la fel (`halo_*`).
@export var shadow_alpha: float = 0.45        # cât de închisă e umbra în lumea normală
@export var shadow_alpha_castel: float = 0.30 # pe lespezile castelului doar acoperă piatra
@export var shadow_width: float = 0.92        # fracție din lățimea vizibilă a porții
@export var shadow_squash: float = 0.30       # turtirea: înălțime / lățime
@export var shadow_shift_y: float = -18.0     # o urcă față de talpă (minus = în sus, sub piatră)

# Albastru rece, nu portocaliu de torță: e culoarea tăieturii lui SIR JOHN și singura care nu se
# confundă cu focul din Nether sau cu urmele de foc ale player-ului.
#
# ⚠️ Lumina ADITIVĂ (`BLEND_MODE_ADD`) se poartă foarte diferit pe cele două podele, de aia are
# fiecare cifra ei — măsurat pe capturi, 2026-09-01. Pe NISIP/iarbă (fundal deja luminos) o baltă
# de 0,55 iese ALBĂ, ca o lanternă uitată pe jos: canalele roșu și verde ale solului sunt aproape
# pline și mai adaugi peste ele. Pe lespedea aproape neagră a castelului, aceeași cifră e exact
# ce trebuie — acolo lumina chiar are pe ce să se așeze. Deci în lume balta e discretă (0,26) și
# dincolo urcă la 0,72. Crăpătura dintre canaturi rămâne la fel de tare în amândouă: ea cade pe
# LEMN ÎNCHIS, care nu se albește.
@export var glow_color: Color = Color(0.45, 0.78, 0.92)
@export var glow_alpha: float = 0.26          # balta de pe jos, în lumea normală
@export var glow_alpha_castel: float = 0.72   # dincolo, pe piatră întunecată
@export var glow_width: float = 0.66          # fracție din lățimea porții
@export var glow_squash: float = 0.50
@export var glow_shift_y: float = 8.0         # PLUS: lumina se varsă ÎN FAȚA ușii, nu sub arcadă
@export var seam_alpha: float = 0.55          # crăpătura dintre canaturi
@export var seam_alpha_castel: float = 0.75
# Îngustă și înaltă dinadins: e lumina care scapă pe CRĂPĂTURA dintre cele două canaturi, nu o
# pată pe toată ușa. O elipsă lată (prima încercare) ieșea un abur cenușiu peste lemn și nu se
# citea ca lumină; îngustată, se vede de departe că ușa aia are ceva viu în spate.
@export var seam_size: Vector2 = Vector2(56, 210)
@export var seam_shift_y: float = -62.0       # centrul ușii, față de nod
@export var puls: float = 0.14                # cât respiră lumina (fracție din mărime)
@export var puls_timp: float = 1.9            # cât ține o inspirație
@export var fade_dimensiune: float = 0.8      # ca `DIM_FADE` din `atmosphere.gd`

# Închiderea definitivă (după ce ai bătut SIR JOHN și ai ieșit): intră în pământ, ca portalul
# Nether și fântâna Ender. O cheamă `prison.gd::_inchide_poarta`, odată cu cutremurul.
@export var sink_duration: float = 1.0
@export var sink_depth: float = 90.0

var _umbra: Sprite2D
var _balta: Sprite2D
var _crapatura: Sprite2D
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

# ---------- LUMINA ȘI UMBRA ----------

# Textura luminilor: același gradient radial ca la umbre, dar ALB — una singură pentru tot jocul.
# ⚠️ Nu se poate refolosi `GroundShadow.shadow_texture()`: ăla e NEGRU, iar negru adunat la ce e
# dedesubt („blend add") înseamnă exact zero. Pe umbre nu se vede, fiindcă ele se înmulțesc.
static var _tex_lumina: GradientTexture2D = null

static func _textura_lumina() -> GradientTexture2D:
	if _tex_lumina == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.75))   # miez mic, margine lungă: lumină, nu farfurie
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex_lumina = t
	return _tex_lumina

# O pată de lumină aditivă. `blend_mode = ADD` e ce o face lumină și nu abțibild: pe iarbă adaugă
# albastru, pe lespedea castelului adaugă tot albastru, și nicăieri nu acoperă desenul de dedesubt.
func _lumina(marime: Vector2, la: Vector2, alpha: float, sub_picioare: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _textura_lumina()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.scale = marime / 128.0
	s.position = la
	s.modulate = Color(glow_color, alpha)
	if sub_picioare:
		s.z_index = -1     # pe podea, ca umbra: trece pe deasupra ei orice, inclusiv player-ul
	return s

# Lățimea, poziția și turtirea petelor de jos le calculează `ground_shadow.gd` din PIXELII REALI ai
# texturii — deci nu există cifre scrise de mână care s-ar putea desincroniza de artă dacă Răzvan
# redesenează poarta. Balta intră în arbore ÎNAINTEA umbrei: amândouă stau pe `z_index = -1`, deci
# le desparte ordinea din arbore.
func _construieste_talpa() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var sc: float = sprite.scale.x
	var tex := sprite.texture
	_balta = GroundShadow.make(tex, sprite, sc, glow_alpha,
		glow_width, glow_squash, glow_shift_y)
	_balta.texture = _textura_lumina()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_balta.material = m
	_balta.modulate = Color(glow_color, glow_alpha)
	add_child(_balta)
	_umbra = GroundShadow.make(tex, sprite, sc, shadow_alpha,
		shadow_width, shadow_squash, shadow_shift_y)
	add_child(_umbra)
	# Crăpătura dintre canaturi: PESTE piatră (fără `z_index`, adăugată după `Sprite2D`), altfel
	# ar rămâne ascunsă de ușa pe care trebuie s-o lumineze.
	_crapatura = _lumina(seam_size, Vector2(0, seam_shift_y), seam_alpha, false)
	add_child(_crapatura)
	_porneste_pulsul()

# Respirația luminii: balta și crăpătura pe același tween, ca să pulseze ÎMPREUNĂ (două tween-uri
# separate s-ar despărți în câteva zeci de secunde și ar arăta ca două efecte fără legătură).
# Se oprește singur când poarta se scufundă și nodurile sunt șterse.
func _porneste_pulsul() -> void:
	if _balta == null or _crapatura == null:
		return
	var b := _balta.scale
	var c := _crapatura.scale
	var t := _balta.create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(_balta, "scale", b * (1.0 + puls), puls_timp)
	t.parallel().tween_property(_crapatura, "scale", c * (1.0 + puls * 0.5), puls_timp)
	t.tween_property(_balta, "scale", b, puls_timp)
	t.parallel().tween_property(_crapatura, "scale", c, puls_timp)

# Chemată din `prison.gd`, lângă `retur`: intri în castel → `true`, ieși → `false`.
# Nu ne uităm singuri după grupul „prison" în fiecare cadru — cine ne schimbă rolul ne spune și cum
# să arătăm, exact ca `portal_ender.gd::set_cosmic`.
#
# Ce se schimbă: umbra slăbește (pe lespedea cenușie a castelului o pată neagră arată ca o gaură,
# nu ca o umbră) și lumina crește puțin — dincolo ea nu mai e „ceva ciudat pe câmp", e SINGURA
# ieșire, și trebuie găsită de departe.
func set_in_castel(on: bool) -> void:
	if _in_castel == on or _umbra == null:
		return
	_in_castel = on
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # moartea pune jocul pe pauză
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_umbra, "modulate:a",
		shadow_alpha_castel if on else shadow_alpha, fade_dimensiune)
	if _balta != null:
		_fade_tween.tween_property(_balta, "modulate:a",
			glow_alpha_castel if on else glow_alpha, fade_dimensiune)
	if _crapatura != null:
		_fade_tween.tween_property(_crapatura, "modulate:a",
			seam_alpha_castel if on else seam_alpha, fade_dimensiune)

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
	# umbra și luminile se sting odată cu ea — altfel ar rămâne o pată pe pământul gol
	for pata in [_umbra, _balta, _crapatura]:
		if pata != null and is_instance_valid(pata):
			t.parallel().tween_property(pata, "modulate:a", 0.0, sink_duration)
	t.tween_callback(queue_free)
