@tool
extends StaticBody2D

# Bază comună pentru obiectele fixe din lume cu care poți interacționa apăsând E:
# `portal.gd` (Portalul spre Nether) și `summoning_portal.gd` (structura care îl cheamă
# pe Saratalin). Ține un singur lucru: HITBOX-UL REGLABIL DIN INSPECTOR.
#
# ---------------------------------------------------------------------------
# CUM REGLEZI HITBOX-UL (butoanele din Inspector)
# ---------------------------------------------------------------------------
# Scriptul e `@tool`, adică rulează ȘI în editor: orice cifră schimbi se vede PE LOC
# în fereastra de editare, fără să pornești jocul.
#
#   1. deschide scena obiectului (`portal.tscn` / `summoning_portal.tscn`) — dublu-click
#      pe fișier în panoul FileSystem, stânga-jos;
#   2. în Scene (stânga-sus) dă click pe nodul de SUS — nu pe `CollisionShape2D`,
#      butoanele sunt pe nodul părinte;
#   3. în Inspector, jos, ai secțiunea **Hitbox**. Patru cifre, câte una pentru fiecare
#      latură — cât se întinde zidul din TALPA obiectului în direcția aia, în pixeli:
#         Nord = în sus     Sud = în jos     Est = la dreapta     Vest = la stânga
#      Mărești `Nord` → peretele crește în sus. Mărești `Est` → crește spre dreapta. Atât.
#   4. bifează `Vezi Hitbox` ca să vezi ce faci: dreptunghi ROȘU = zidul (cu literele
#      N/S/E/V pe laturi), cerc ALBASTRU = raza din care apare „Press E", punct GALBEN
#      = talpa obiectului (linia lui de Y-sort);
#   5. bifa merge și în joc. Când ești mulțumit, DEBIFEAZ-O.
#
# ⚠️ Comanda o dau cele patru cifre, NU nodul `CollisionShape2D`: la fiecare încărcare
# scriptul îi scrie forma după ele. Dacă tragi de pătrățelele portocalii cu mouse-ul,
# modificarea se pierde. Treci prin Nord/Sud/Est/Vest.
#
# Dacă aveai Godot DESCHIS când s-a schimbat scriptul și secțiunea nu apare:
# Project → Reload Current Project. Editorul ține minte vechea versiune a unui `@tool`.

@export var interact_range: float = 200.0:   # cât de aproape trebuie să fii ca să apară textul
	set(v):
		interact_range = v
		_redeseneaza()

@export_group("Hitbox")
## Cât urcă zidul DEASUPRA tălpii obiectului (px).
@export var nord: float = 20.0:
	set(v):
		nord = v
		_aplica_hitbox()
## Cât coboară zidul SUB talpa obiectului (px).
@export var sud: float = 20.0:
	set(v):
		sud = v
		_aplica_hitbox()
## Cât se întinde zidul la DREAPTA (px).
@export var est: float = 115.0:
	set(v):
		est = v
		_aplica_hitbox()
## Cât se întinde zidul la STÂNGA (px).
@export var vest: float = 115.0:
	set(v):
		vest = v
		_aplica_hitbox()
## Desenează conturul (și în joc). Debifeaz-o când ai terminat de reglat.
@export var vezi_hitbox: bool = false:
	set(v):
		vezi_hitbox = v
		if _contur != null:
			_contur.visible = v
			_contur.queue_redraw()

var _contur: Contur = null

func _ready() -> void:
	_porneste_contur()
	_aplica_hitbox()
	if Engine.is_editor_hint():
		return   # în editor ne oprim aici: grupurile și logica de joc n-au ce căuta acolo
	# „interactable" = tot ce poate afișa textul „Press E to interact" (vezi `interact_ui.gd`).
	add_to_group("interactable")

# Traduce cele patru laturi în ce înțelege Godot: un dreptunghi (mărime + centru).
#   lățime = vest + est, înălțime = nord + sud
#   centrul = la mijloc între laturi, față de talpă
#
# În joc DUPLICĂM forma: `RectangleShape2D` e o sub-resursă a scenei, deci toate obiectele
# ar împărți același obiect și ultimul care scrie ar decide pentru toate. În editor NU
# duplicăm — acolo vrem exact resursa din `.tscn`, ca să se salveze în fișier.
func _aplica_hitbox() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return   # setter-ul poate fi chemat la încărcare, înainte să existe copiii
	if cs.shape is RectangleShape2D:
		if not Engine.is_editor_hint() and not cs.shape.resource_local_to_scene:
			cs.shape = cs.shape.duplicate()
			cs.shape.resource_local_to_scene = true
		# minim 1px: un dreptunghi de 0 ar dispărea de tot și n-ai mai nimeri înapoi
		cs.shape.size = Vector2(maxf(vest + est, 1.0), maxf(nord + sud, 1.0))
	cs.position = Vector2((est - vest) * 0.5, (sud - nord) * 0.5)
	_redeseneaza()

func _redeseneaza() -> void:
	if _contur != null:
		_contur.queue_redraw()

func _porneste_contur() -> void:
	if _contur != null:
		return
	_contur = Contur.new()
	_contur.portal = self
	_contur.z_index = 100   # ultimul copil + z mare = desenat PESTE artă, nu sub ea
	_contur.visible = vezi_hitbox
	add_child(_contur)

# --- ce completează scripturile care moștenesc de aici ---

# Mai poate fi folosit? `interact_ui.gd` întreabă asta înainte să arate textul.
func poate_invoca() -> bool:
	return true

# Ce se întâmplă când apeși E. Gol aici — îl scrie fiecare obiect în felul lui.
func invoca() -> void:
	pass

# Conturul de reglaj. E un nod separat (nu desenăm direct în obiect) fiindcă `Sprite2D`
# e copil, iar copiii se desenează PESTE părinte — liniile ar fi rămas ascunse sub artă.
class Contur extends Node2D:
	var portal: Node2D = null

	func _draw() -> void:
		if portal == null:
			return
		# tipurile sunt scrise explicit: `portal` e un `Node2D`, deci GDScript nu poate
		# ghici singur ce tip au `nord`/`sud`/... și refuză să compileze fără ele
		var sus: float = -portal.nord
		var jos: float = portal.sud
		var st: float = -portal.vest
		var dr: float = portal.est
		# zidul (roșu): plin transparent + contur gros
		var r := Rect2(Vector2(st, sus), Vector2(dr - st, jos - sus))
		draw_rect(r, Color(1.0, 0.2, 0.2, 0.18))
		draw_rect(r, Color(1.0, 0.25, 0.25), false, 2.0)
		# literele pe laturi, ca să știi care cifră mișcă ce
		var font := ThemeDB.fallback_font
		var c := Color(1.0, 0.55, 0.55)
		draw_string(font, Vector2((st + dr) * 0.5 - 5, sus - 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
		draw_string(font, Vector2((st + dr) * 0.5 - 5, jos + 18), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
		draw_string(font, Vector2(dr + 6, (sus + jos) * 0.5 + 6), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
		draw_string(font, Vector2(st - 20, (sus + jos) * 0.5 + 6), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
		# raza de interacțiune (albastru): de aici încolo apare „Press E"
		var raza: float = portal.interact_range
		draw_arc(Vector2.ZERO, raza, 0.0, TAU, 64, Color(0.3, 0.85, 1.0, 0.75), 2.0)
		# talpa obiectului (galben): originea nodului și linia lui de Y-sort
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.95, 0.2))
		draw_line(Vector2(-40, 0), Vector2(40, 0), Color(1.0, 0.95, 0.2, 0.6), 1.0)
