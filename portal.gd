@tool
extends StaticBody2D

# Portal fix în lume — sora mai rară a statuii (vezi `statue.gd` și `portals.gd`).
#
# Când player-ul se apropie apare deasupra lui textul „Press E to interact",
# exact ca la statuie (îl afișează `interact_ui.gd`, care se uită la grupul
# „interactable"). Apăsând E te duce în NETHER — a doua dimensiune (vezi `nether.gd`).
#
# ACELAȘI script joacă ambele roluri, după steagul `retur`:
#   • `retur = false` (portalurile din lume, puse de `portals.gd`) → INTRI în Nether;
#   • `retur = true`  (portalul pe care îl pune `nether.gd` unde ai aterizat) → IEȘI.
#
# Poziția nodului Portal = BAZA portalului (talpa) → și linia de la care te
# acoperă (Y-sort), la fel ca la statuie.
#
# ---------------------------------------------------------------------------
# CUM REGLEZI HITBOX-UL (butoanele din Inspector)
# ---------------------------------------------------------------------------
# Scriptul e `@tool`, adică rulează ȘI în editor: orice cifră schimbi mai jos se
# vede PE LOC în fereastra de editare, fără să pornești jocul.
#
#   1. deschide `portal.tscn` și dă click pe nodul de sus, `Portal`;
#   2. în Inspector ai grupul „Hitbox" — `Hitbox Size` (lățime × înălțime, în pixeli)
#      și `Hitbox Pos` (unde stă față de talpa portalului; y negativ = mai sus);
#   3. bifează `Vezi Hitbox` ca să vezi conturul: dreptunghiul ROȘU e zidul de care
#      te lovești, cercul ALBASTRU e raza din care apare „Press E", punctul GALBEN
#      e originea nodului (talpa, linia de Y-sort);
#   4. bifa rămâne bifată și în joc — util ca să te lovești de el și să vezi exact
#      unde e. Când ești mulțumit, DEBIFEAZ-O, altfel se vede și în jocul final.
#
# ⚠️ De acum comanda o dau cifrele astea, NU valorile din nodul `CollisionShape2D`:
# la fiecare pornire scriptul scrie forma după ele. Dacă tragi de pătrățelele
# portocalii ale lui `CollisionShape2D` cu mouse-ul, modificarea se pierde — treci
# prin `Hitbox Size` / `Hitbox Pos`.
#
# Arta (poza) a rămas neatinsă, se reglează tot din `Sprite2D`. Un singur lucru de
# ținut minte acolo: `Sprite2D.offset.y = -25.17` e calculat ca baza artei să cadă
# 74px SUB originea nodului. Cifra 74 nu e la întâmplare: sprite-ul player-ului e
# CENTRAT pe punctul lui de sortare, deci se întinde ~64px sub el. Dacă arta urcă
# prea sus, când player-ul trece prin spate îi rămân picioarele afară, sub portal.
# Copacii și statuia folosesc tot 74. Deci: poți să cobori arta, dar nu s-o urci sub ~64.

@export var interact_range: float = 200.0:   # cât de aproape trebuie să fii ca să apară textul
	set(v):
		interact_range = v
		_redeseneaza()
@export var retur: bool = false              # true doar pe portalul de întoarcere din Nether

@export_group("Hitbox")
## Lățimea și înălțimea zidului, în pixeli.
@export var hitbox_size: Vector2 = Vector2(230, 40):
	set(v):
		hitbox_size = v
		_aplica_hitbox()
## Unde stă zidul față de talpa portalului. y negativ = mai sus.
@export var hitbox_pos: Vector2 = Vector2(0, 0.4):
	set(v):
		hitbox_pos = v
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
	# Se anunță în grupul pe care îl citește `interact_ui.gd`. Statuia e în același grup.
	add_to_group("interactable")

# Scrie forma de coliziune după cifrele din Inspector.
#
# În joc DUPLICĂM forma: `RectangleShape2D` e o sub-resursă a scenei, deci toate portalurile
# ar împărți același obiect și ultimul care scrie ar decide pentru toate. În editor NU
# duplicăm — acolo vrem exact resursa din `portal.tscn`, ca să se salveze în fișier.
func _aplica_hitbox() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return   # setter-ul poate fi chemat la încărcare, înainte să existe copiii
	if cs.shape is RectangleShape2D:
		if not Engine.is_editor_hint() and not cs.shape.resource_local_to_scene:
			cs.shape = cs.shape.duplicate()
			cs.shape.resource_local_to_scene = true
		cs.shape.size = hitbox_size
	cs.position = hitbox_pos
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

# Mai poate fi folosit? `interact_ui.gd` întreabă asta înainte să arate textul.
# Portalul nu se consumă — intri și ieși de câte ori vrei.
func poate_invoca() -> bool:
	return true

# Apăsarea tastei de interacțiune ajunge aici: te duce în Nether sau te aduce înapoi.
func invoca() -> void:
	var nether := get_tree().get_first_node_in_group("nether")
	if nether == null:
		return
	if retur:
		nether.exit_nether()
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		# îi dăm și locul nostru: portalul de întoarcere din Nether se pune exact aici
		nether.enter(player, global_position)

# Conturul de reglaj. E un nod separat (nu desenăm direct în `Portal`) fiindcă `Sprite2D`
# e copil, iar copiii se desenează PESTE părinte — liniile ar fi rămas ascunse sub artă.
class Contur extends Node2D:
	var portal: Node2D = null

	func _draw() -> void:
		if portal == null:
			return
		# zidul (roșu): plin, transparent + contur gros
		var r := Rect2(portal.hitbox_pos - portal.hitbox_size * 0.5, portal.hitbox_size)
		draw_rect(r, Color(1.0, 0.2, 0.2, 0.18))
		draw_rect(r, Color(1.0, 0.25, 0.25), false, 2.0)
		# raza de interacțiune (albastru): de aici încolo apare „Press E"
		draw_arc(Vector2.ZERO, portal.interact_range, 0.0, TAU, 64, Color(0.3, 0.85, 1.0, 0.75), 2.0)
		# originea nodului (galben): talpa portalului și linia lui de Y-sort
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.95, 0.2))
		draw_line(Vector2(-40, 0), Vector2(40, 0), Color(1.0, 0.95, 0.2, 0.6), 1.0)
