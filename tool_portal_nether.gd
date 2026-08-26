extends Node

# Pregătește cele două texturi de care are nevoie vâltoarea din portalul Nether
# (vezi `portal_nether.gdshader` și `portal.tscn`):
#
#   1. `harta/nether/portal_vartej.png` — cele 10 cadre desenate de Răzvan
#      (`harta/nether/1.png` … `10.png`) lipite una lângă alta, într-o singură foaie
#      de 1280×128. Shaderul are nevoie de UN SINGUR sampler ca să poată amesteca
#      două cadre vecine (topirea dintre ele), lucru imposibil cu un AnimatedSprite2D.
#   2. `harta/nether/portal_masca.png` — forma EXACTĂ a golului din arcadă
#      (`harta/Portal 1.png`), alb pe transparent. Ea e cea care ține animația
#      înăuntru: shaderul înmulțește totul cu ea, deci în afara arcadei nu iese nimic.
#
# Rulare:  godot --headless --path <proj> res://tool_portal_nether.tscn
#          apoi:  godot --headless --path <proj> --import
#
# Se rulează DIN NOU dacă:
#   • Răzvan mai desenează cadre (pune `11.png`, `12.png`… — se prind singure);
#   • se schimbă desenul portalului (`harta/Portal 1.png`) → masca nu mai e pe formă.
# După ce crește numărul de cadre, pune noua cifră în `portal.tscn`, la
# `shader_parameter/cadre` (unealta o tipărește la final).

const CADRE_DIR := "res://harta/nether/"
const ARTA_PORTAL := "res://harta/Portal 1.png"
const FOAIE := "res://harta/nether/portal_vartej.png"
const MASCA := "res://harta/nether/portal_masca.png"

# Sub cât e considerat „gol" un pixel din arta portalului. Pixelii de pe muchie sunt
# semi-transparenți (anti-aliasing); îi lăsăm pietrei, iar masca îi recuperează prin
# umflarea cu 1px de mai jos.
const PRAG_GOL := 0.3

func _ready() -> void:
	var cadre := _incarca_cadrele()
	if cadre.is_empty():
		print("!!! n-am găsit niciun cadru în ", CADRE_DIR)
		get_tree().quit()
		return
	_scrie_foaia(cadre)
	_scrie_masca()
	print("gata. Pune în portal.tscn:  shader_parameter/cadre = ", float(cadre.size()))
	get_tree().quit()


# Cadrele se cheamă 1.png, 2.png, … — le luăm în ordine până se termină.
func _incarca_cadrele() -> Array[Image]:
	var lista: Array[Image] = []
	var i := 1
	while true:
		var cale := "%s%d.png" % [CADRE_DIR, i]
		if not FileAccess.file_exists(ProjectSettings.globalize_path(cale)):
			break
		var img := Image.load_from_file(cale)
		if img == null:
			print("!!! nu pot citi ", cale)
			break
		lista.append(img)
		i += 1
	return lista


func _scrie_foaia(cadre: Array[Image]) -> void:
	var w := cadre[0].get_width()
	var h := cadre[0].get_height()
	for c in cadre:
		if c.get_width() != w or c.get_height() != h:
			print("!!! cadrele n-au toate aceeași mărime — foaia ar ieși strâmbă")
			return
	var foaie := Image.create(w * cadre.size(), h, false, Image.FORMAT_RGBA8)
	for i in cadre.size():
		var c: Image = cadre[i]
		c.convert(Image.FORMAT_RGBA8)
		foaie.blit_rect(c, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	foaie.save_png(ProjectSettings.globalize_path(FOAIE))
	print("foaia: ", FOAIE, "  ", foaie.get_size(), "  (", cadre.size(), " cadre de ", w, "×", h, ")")


# Masca = TOT ce e transparent în arta portalului, dar nu se leagă de marginea imaginii.
#
# Adică: umplem întâi „afarăul" pornind de pe rama de 1px a imaginii; ce rămâne transparent
# și neatins e, prin definiție, închis de piatră — golul arcadei (plus rosturile mici de
# lângă treaptă, care sunt tot înăuntru). Așa nu trebuie ghicit niciun punct de start și
# nu se strică dacă Răzvan mai mișcă arcada prin cele 128×128.
func _scrie_masca() -> void:
	var img := Image.load_from_file(ARTA_PORTAL)
	if img == null:
		print("!!! nu pot citi ", ARTA_PORTAL)
		return
	var w := img.get_width()
	var h := img.get_height()

	var afara := []
	afara.resize(w * h)
	afara.fill(false)
	var q: Array[Vector2i] = []
	for x in w:
		_pune(img, afara, q, w, h, Vector2i(x, 0))
		_pune(img, afara, q, w, h, Vector2i(x, h - 1))
	for y in h:
		_pune(img, afara, q, w, h, Vector2i(0, y))
		_pune(img, afara, q, w, h, Vector2i(w - 1, y))
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_pune(img, afara, q, w, h, p + d)

	# umflăm golul cu 1px, ca vâltoarea să intre puțin SUB buza de piatră și să nu
	# rămână un fir de lumină între ea și arcadă (arcada se desenează peste, oricum)
	var m := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := 0
	var minx := w
	var maxx := -1
	var miny := h
	var maxy := -1
	for y in h:
		for x in w:
			var on := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h:
						if img.get_pixel(xx, yy).a < PRAG_GOL and not afara[yy * w + xx]:
							on = true
			m.set_pixel(x, y, Color(1, 1, 1, 1) if on else Color(0, 0, 0, 0))
			if on:
				n += 1
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if n == 0:
		print("!!! arta portalului n-are niciun gol închis — masca ar fi goală, nu salvez")
		return
	m.save_png(ProjectSettings.globalize_path(MASCA))
	print("masca: ", MASCA, "  ", n, " pixeli, între x ", minx, "..", maxx, " și y ", miny, "..", maxy)


# Marchează un pixel ca „afară" dacă e transparent și încă neatins.
func _pune(img: Image, afara: Array, q: Array[Vector2i], w: int, h: int, p: Vector2i) -> void:
	if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
		return
	if afara[p.y * w + p.x]:
		return
	if img.get_pixel(p.x, p.y).a >= PRAG_GOL:
		return
	afara[p.y * w + p.x] = true
	q.push_back(p)
