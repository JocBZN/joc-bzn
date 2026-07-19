extends Node2D

# Unda de șoc a lui Panic Button (stil „Mama Mega" din Binding of Isaac): un inel care se umflă din
# player peste tot ecranul și dă damage-ul PE MĂSURĂ ce ajunge la fiecare inamic — nu tuturor deodată.
# Ăsta e tot rostul: cei de lângă tine mor primii, apoi valul se rostogolește spre margini.
#
# Rulează în `_process` (nu în fizică): mișcarea e vizuală, iar `take_damage` de aici n-are voie să
# cadă în mijlocul pasului de fizică (aceeași capcană ca la Thunder God — vezi log-ul din 2026-07-17).

var damage: int = 0
var duration: float = 0.55     # cât îi ia să măture ecranul
var max_radius: float = 800.0  # până unde ajunge (îl pune player.gd din mărimea ecranului)

var _t: float = 0.0
var _raza: float = 0.0
var _loviti := {}              # instance_id -> true, ca un inamic să nu încaseze de două ori

func _ready() -> void:
	z_index = -1               # pe sol: sub player și sub inamici, ca aura stingătorului
	top_level = true           # nu se mișcă cu player-ul — valul pleacă din locul detonării și rămâne acolo

func _process(delta: float) -> void:
	_t += delta
	var p := clampf(_t / duration, 0.0, 1.0)
	# Frontul pornește repede și încetinește spre margine (ease-out) — arată ca o suflare care se
	# stinge, nu ca un cerc care se dilată mecanic.
	_raza = max_radius * (1.0 - pow(1.0 - p, 2.0))
	_lovește()
	queue_redraw()
	if p >= 1.0:
		queue_free()

# Tot ce a intrat sub front și n-a încasat încă. Verific distanța în FIECARE cadru, nu o dată la
# spawn: inamicii se mișcă, iar unul care fuge spre margine trebuie prins când îl ajunge valul.
func _lovește() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		var id := enemy.get_instance_id()
		if _loviti.has(id):
			continue
		if global_position.distance_to(enemy.global_position) > _raza:
			continue
		_loviti[id] = true
		enemy.take_damage(damage)
		Fx.damage_number(enemy.global_position, damage, true)  # roșu, ca la critic

# Inelul: un miez alb-fierbinte pe front, cu un halou portocaliu gros în urma lui. Se subțiază și se
# stinge pe măsură ce se depărtează, ca să nu rămână un cerc gras desenat peste tot ecranul la final.
#
# GROSIMILE SUNT MARI INTENȚIONAT. Două motive, ambele văzute la prima încercare (valorile de atunci,
# 26→6px, ieșeau ca niște fire abia vizibile):
#   1. `atmosphere.gd` pune o vignetă peste toată lumea (CanvasLayer 3), iar unda e pe sol, sub ea →
#      orice culoare se spală. Trebuie să pornească mai tare ca să ajungă „normală" pe ecran.
#   2. Camera stă pe zoom 0.7, deci grosimile astea în pixeli de LUME se văd cu ~30% mai subțiri.
# Dacă vreodată se schimbă vigneta sau zoom-ul, aici se reglează.
func _draw() -> void:
	if _raza < 1.0:
		return
	var p := clampf(_t / duration, 0.0, 1.0)
	var fade := 1.0 - p * p                    # se stinge accelerat spre final
	var gros := lerpf(80.0, 24.0, p)           # frontul se subțiază pe măsură ce se întinde
	draw_arc(Vector2.ZERO, _raza, 0.0, TAU, 96, Color(1.0, 0.45, 0.08, 0.85 * fade), gros, true)
	draw_arc(Vector2.ZERO, _raza, 0.0, TAU, 96, Color(1.0, 0.98, 0.88, 1.0 * fade), gros * 0.3, true)
	# un al doilea inel, mai mic și mai slab, care aleargă în urma primului → senzație de suflu dublu
	if _raza > 60.0:
		draw_arc(Vector2.ZERO, _raza * 0.72, 0.0, TAU, 64,
			Color(1.0, 0.35, 0.05, 0.4 * fade), gros * 0.55, true)
