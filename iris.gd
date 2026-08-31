extends ColorRect

# DIAFRAGMA — cercul care se strânge sau se deschide peste player, desenat de
# `moarte_iris.gdshader`. Un `ColorRect` cât tot ecranul: ce arată depinde numai de rază.
#
# O folosesc DOUĂ cinematici, care sunt aceeași animație rulată în sensuri opuse:
#   • `gameover.gd` — se ÎNCHIDE peste tine când mori (inel roșu, ca „YOU DIED");
#   • `intro.gd`    — se DESCHIDE de pe tine când începe runda (inel cyan, ca bara de încărcare).
#
# 🔑 De ce stă într-un fișier separat, deși până pe 2026-08-31 era scrisă direct în `gameover.gd`:
# fiindcă cele două trebuie să rămână oglinda una alteia. Geometria (unde cade centrul, cât de mare
# e raza de la care nu se mai vede negru) și legătura rază → culoare scursă → inel aprins sunt
# exact lucrurile pe care le-ar fi copiat intrarea. Copiate, s-ar fi despărțit de moarte la prima
# reglare — și nimeni n-ar fi prins-o, fiindcă cele două cinematici nu se văd niciodată una lângă
# alta: una e la începutul rundei, cealaltă la sfârșitul ei.
#
# ⚠️ Shaderul și-a păstrat numele de `moarte_iris.gdshader` deși acum îl folosesc amândouă: e citat
# ca atare în `tool_moarte.gd`, are `.uid`-ul lui, iar o redenumire n-ar aduce decât ocazii de
# greșit. Comentariul din capul lui spune că e împărțit.

const IRIS_SHADER := preload("res://moarte_iris.gdshader")

# Culoarea inelului care arde pe marginea DINĂUNTRU a cercului. Ea deosebește cele două
# cinematici. Se poate pune oricând — și înainte, și după `add_child` (vezi setter-ul).
var culoare_inel := Color(0.60, 0.05, 0.07):
	set(c):
		culoare_inel = c
		if _mat != null:
			_mat.set_shader_parameter("culoare_rama", c)

# Raza de la care nu se mai vede NIMIC negru pe ecran, calculată din poziția player-ului
# (vezi `aseaza_pe_player`). Cinematicile pleacă de la ea sau ajung la ea.
var raza_start := 1.2

var _mat: ShaderMaterial

# Materialul se face în `_init`, nu în `_ready`: așa `culoare_inel` poate fi pusă imediat după
# `.new()`, înainte ca nodul să intre în arbore, fără ca ordinea să conteze pentru cine ne
# folosește.
func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = IRIS_SHADER
	_mat.set_shader_parameter("culoare_rama", culoare_inel)
	material = _mat

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # altfel ar mânca clicurile butoanelor de sub el

# Pune cercul peste player și calculează raza de la care ecranul e întreg.
#
# ⚠️ NU atinge raza curentă — o pune cine ne cheamă. Moartea vrea să înceapă cu ecranul întreg
# (`raza_start`), intrarea vrea să înceapă cu ecranul negru (0); dacă am hotărî noi aici, una
# din ele ar clipi în primul cadru.
func aseaza_pe_player() -> void:
	var vp := get_viewport().get_visible_rect().size
	var centru := Vector2(0.5, 0.5)
	var pl := get_tree().get_first_node_in_group("player")
	if pl is Node2D and vp.x > 0.0 and vp.y > 0.0:
		# poziția player-ului PE ECRAN (nu în lume): transformarea lui, prin cameră, în pixeli
		centru = pl.get_global_transform_with_canvas().origin / vp
	# dacă ar muri cumva în afara ecranului, cercul tot trebuie să rămână pe undeva pe aproape
	centru.x = clampf(centru.x, -0.25, 1.25)
	centru.y = clampf(centru.y, -0.25, 1.25)
	var raport := Vector2(vp.x / maxf(vp.y, 1.0), 1.0)
	# Raza „ecran întreg" = colțul cel mai DEPĂRTAT de player, plus o idee. Se calculează, nu e
	# „2.0 și gata": dacă mori într-un colț, colțul opus e la peste 1,2 înălțimi de ecran distanță.
	raza_start = 0.0
	for colt in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		raza_start = maxf(raza_start, ((colt - centru) * raport).length())
	raza_start += 0.02
	_mat.set_shader_parameter("centru", centru)
	_mat.set_shader_parameter("raport", raport)

# Un pas al animației. Culoarea care se scurge și inelul se calculează DIN rază, nu din timp: cât
# de închis e ecranul urmează exact cât de mic e cercul, în orice fază și în orice sens.
func seteaza_raza(r: float) -> void:
	_mat.set_shader_parameter("raza", r)
	var p := clampf(1.0 - r / maxf(raza_start, 0.001), 0.0, 1.0)
	# `pow(p, 1.6)`: culoarea nu se scurge de la prima mișcare a cercului, ci pe măsură ce el chiar
	# se strânge. Liniar, lumea se făcea gri în prima jumătate de secundă și restului nu-i mai
	# rămânea unde să meargă.
	_mat.set_shader_parameter("stins", pow(p, 1.6))
	_mat.set_shader_parameter("rama", clampf(p * 1.3, 0.0, 1.0))
