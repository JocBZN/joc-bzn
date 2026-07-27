extends Node

# Generator de contur pentru FOI DE CADRE (spritesheet-uri): ia o foaie, o taie mental în
# cadre și pune pe fiecare cadru un contur MOV de 1px plin, lipit de desen. Scrie o foaie
# NOUĂ; sursa lui Răzvan rămâne neatinsă, deci poți rula unealta de câte ori vrei fără să
# se îngroașe conturul (dacă ar scrie peste sursă, a doua rulare ar contura conturul).
#
# Rulare:  godot --headless --path <proj> res://tool_contur_foaie.tscn
#          apoi:  godot --headless --path <proj> --import   (ca să importe PNG-ul nou)
#
# Fratele lui `tool_contur.gd`, care face același lucru pentru PROIECTILE (le și rotește,
# cadru cu cadru, și pune contur de 2px). Aici nu rotim nimic: cadrele există deja în foaie,
# noi doar le desenăm marginea.
#
# Ca să conturezi altă foaie, mai pui o linie în `LUCRARI`.

const CONTUR := Color(0.72, 0.28, 1.0, 1.0)      # același mov ca la proiectile
const PRAG := 0.35                               # de la ce alfa în sus considerăm că e desen

const LUCRARI := [
	{
		# Saratalin, boss-ul Nether-ului: 3360×240 = 15 cadre de 224×240
		"sursa": "res://harta/nether/Nether Boss/Saratalin.png",
		"iesire": "res://harta/nether/Nether Boss/Saratalin_contur.png",
		"cadre": 15,
	},
]

func _ready() -> void:
	for l in LUCRARI:
		_fa(l["sursa"], l["iesire"], int(l["cadre"]))
	get_tree().quit()

func _fa(sursa: String, iesire: String, cadre: int) -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(sursa))
	if src == null:
		print("!!! nu pot citi ", sursa)
		return
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	if w % cadre != 0:
		print("!!! ", sursa.get_file(), ": lățimea ", w, " nu se împarte la ", cadre, " cadre")
		return
	var lat := w / cadre
	print(sursa.get_file(), ": ", w, "×", h, " · ", cadre, " cadre de ", lat, "×", h)
	for i in cadre:
		_contur_cadru(src, i * lat, lat, h, i)
	var err := src.save_png(ProjectSettings.globalize_path(iesire))
	if err != OK:
		print("!!! nu pot scrie ", iesire, " (", err, ")")
		return
	print("   gata: ", iesire)

# Conturul unui singur cadru. Ne uităm DOAR în interiorul ferestrei cadrului: altfel desenul
# dintr-un cadru ar scoate contur în cadrul vecin, iar la rulare (unde cadrele sunt tăiate cu
# AtlasTexture) ar apărea o dâră mov pe margine.
func _contur_cadru(img: Image, x_start: int, lat: int, inalt: int, idx: int) -> void:
	# Întâi harta de „aici e desen", ca să nu conturăm conturul pe care tocmai l-am pus.
	var plin := PackedByteArray()
	plin.resize(lat * inalt)
	var atinge_marginea := false
	for y in inalt:
		for x in lat:
			var e_desen := img.get_pixel(x_start + x, y).a >= PRAG
			plin[y * lat + x] = 1 if e_desen else 0
			if e_desen and (x == 0 or y == 0 or x == lat - 1 or y == inalt - 1):
				atinge_marginea = true
	if atinge_marginea:
		print("   ! cadrul ", idx, ": desenul atinge marginea cadrului, acolo conturul iese tăiat")
	for y in inalt:
		for x in lat:
			if plin[y * lat + x] == 1:
				continue
			var vecin := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= lat or ny >= inalt:
						continue
					if plin[ny * lat + nx] == 1:
						vecin = true
			if vecin:
				img.set_pixel(x_start + x, y, CONTUR)
