@tool
extends Node

# UNEALTĂ: recolorează explozia de la impact a Mage Staff-ului în paleta PROIECTILULUI, ca cele
# două să fie evident aceeași vrajă. Nu face parte din joc; se rulează o dată, când se schimbă arta:
#
#   "<godot.exe>" --path "<proiect>" res://tool_recolor_boom.tscn
#   "<godot.exe>" --headless --path "<proiect>" --import      ← OBLIGATORIU după, altfel PNG-urile
#                                                               noi n-au `.import` și nu se încarcă
#
# CUM, și de ce așa: NU e un „filtru de culoare" pus peste (`modulate` înmulțește, iar mov × galben
# dă maro murdar — movul n-are aproape deloc verde). E o **schimbare de paletă**: amândouă animațiile
# sunt pixel art curat, cu exact 5 culori opace fiecare și alfa numai 0 sau 255. Le ordonăm pe
# amândouă după LUMINOZITATE și le legăm una la una — cea mai deschisă a exploziei ia cea mai
# deschisă a proiectilului, ș.a.m.d. Așa explozia iese cu FIX culorile proiectilului, nu cu o
# aproximare, iar umbrele rămân umbre: contrastul desenului original nu se atinge.
#
# Sursa (`fx/mage_boom`) NU se scrie niciodată — ieșirea merge în alt folder. Așa unealta se poate
# re-rula oricând fără să macine ce a măcinat deja (lecția de la conturul negru al sferei mage).

const SURSA := "res://fx/mage_boom"          # explozia originală (movă) — doar se CITEȘTE
const PALETA := "res://fx/mage_attack"       # de la cine împrumutăm culorile (proiectilul galben)
const IESIRE := "res://fx/mage_boom_yellow"  # unde scriem rezultatul

var _erori: Array[String] = []

func _ready() -> void:
	var pal_sursa := _paleta(SURSA)
	var pal_tinta := _paleta(PALETA)
	print("paleta %s: %d culori" % [SURSA, pal_sursa.size()])
	print("paleta %s: %d culori" % [PALETA, pal_tinta.size()])
	if pal_sursa.is_empty() or pal_tinta.is_empty():
		_erori.append("una dintre palete a iesit goala (cadre lipsa sau necitite?)")
	elif pal_sursa.size() != pal_tinta.size():
		# Fără asta ar trebui ghicit ce culoare la ce culoare merge, iar ghicitul pe pixel art
		# strică umbrele. Mai bine pică zgomotos decât să scrie ceva urât.
		_erori.append("paletele au marimi diferite (%d vs %d) - legarea 1:1 nu mai are sens" % [pal_sursa.size(), pal_tinta.size()])
	if not _erori.is_empty():
		_gata()
		return

	# harta veche → nouă, pereche cu pereche, în ordinea luminozității
	var harta := {}
	for i in pal_sursa.size():
		harta[_cheie(pal_sursa[i])] = pal_tinta[i]
		print("  %s  ->  %s" % [_hex(pal_sursa[i]), _hex(pal_tinta[i])])

	# Convertim TOT în memorie și scriem abia la sfârșit, doar dacă n-a scârțâit nimic. Altfel o
	# unealtă care pică la jumătate ar lăsa pe disc o animație jumătate recolorată, jumătate nu.
	var gata: Array[Image] = []
	var i := 0
	while FileAccess.file_exists(ProjectSettings.globalize_path("%s/frame_%d.png" % [SURSA, i])):
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/frame_%d.png" % [SURSA, i]))
		if img == null:
			_erori.append("nu pot citi cadrul %d din %s" % [i, SURSA])
			break
		img.convert(Image.FORMAT_RGBA8)
		var neatinse := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				var k := _cheie(c)
				if harta.has(k):
					var nou: Color = harta[k]
					nou.a = c.a          # alfa rămâne al desenului original
					img.set_pixel(x, y, nou)
				else:
					neatinse += 1
		if neatinse > 0:
			_erori.append("cadrul %d are %d pixeli cu o culoare care nu e in paleta" % [i, neatinse])
		gata.append(img)
		i += 1
	if i == 0:
		_erori.append("n-am gasit niciun frame_N.png in %s" % SURSA)
	if not _erori.is_empty():
		print("nu scriu nimic, vezi erorile de mai jos")
		_gata()
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IESIRE))
	for j in gata.size():
		var cale := ProjectSettings.globalize_path("%s/frame_%d.png" % [IESIRE, j])
		if gata[j].save_png(cale) != OK:
			_erori.append("nu pot scrie %s" % cale)
	print("cadre scrise: ", gata.size())
	_gata()
	_gata()

# Culorile opace dintr-un folder de cadre, ORDONATE de la cea mai închisă la cea mai deschisă.
# Ordinea e tot ce contează: pe ea se leagă cele două palete.
func _paleta(dir: String) -> Array:
	var vazute := {}
	var i := 0
	while FileAccess.file_exists(ProjectSettings.globalize_path("%s/frame_%d.png" % [dir, i])):
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/frame_%d.png" % [dir, i]))
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.0:
						vazute[_cheie(c)] = c
		i += 1
	var culori: Array = vazute.values()
	culori.sort_custom(func(a: Color, b: Color) -> bool: return _lum(a) < _lum(b))
	return culori

# Luminozitatea percepută (Rec. 601). Cu ea decidem care culoare e „umbra" și care „lumina":
# o medie simplă ar pune movul închis peste galbenul deschis, fiindcă ochiul vede verdele
# de vreo cinci ori mai tare decât albastrul.
func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

# Cheie pe canalele RGB, ignorând alfa (arta e pixel art curat: alfa e ori 0, ori 255).
func _cheie(c: Color) -> int:
	return (int(round(c.r * 255.0)) << 16) | (int(round(c.g * 255.0)) << 8) | int(round(c.b * 255.0))

func _hex(c: Color) -> String:
	return "#%06X" % _cheie(c)

func _gata() -> void:
	if _erori.is_empty():
		print("REZULTAT: OK  (nu uita `--headless --import`)")
	else:
		for e in _erori:
			print("EROARE: ", e)
		print("REZULTAT: PICAT")
	if not Engine.is_editor_hint():
		get_tree().quit()
