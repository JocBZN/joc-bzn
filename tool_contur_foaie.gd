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

const CONTUR := Color(0.72, 0.28, 1.0, 1.0)      # același mov ca la proiectile (culoarea implicită)
const GALBEN := Color(1.0, 0.85, 0.15, 1.0)      # galbenul cheii de cufăr
const ALBASTRU := Color(0.15, 0.27, 0.78, 1.0)   # albastru închis — Undead Executioner Puppet
const NEGRU := Color(0.0, 0.0, 0.0, 1.0)         # magnetul de XP (cerut de Răzvan)
const PRAG := 0.35                               # de la ce alfa în sus considerăm că e desen

# O imagine simplă (nu foaie de cadre) se pune tot aici, cu `"cadre": 1`.
# `"culoare"` e opțional; fără el se folosește movul.
#
# Foile pe MAI MULTE RÂNDURI (grile) se scriu cu `"coloane"` + `"randuri"`. Fără ele se
# presupune un singur rând, ca înainte. Celulele goale (o grilă rar iese fix plină) sunt
# sărite și numărate în raport — acolo citești câte cadre are de fapt animația.
const LUCRARI := [
	# Saratalin a IEȘIT de aici pe 2026-08-27: foaia lui de 15 cadre a fost înlocuită cu 64 de
	# cadre de mers pe 8 direcții, care vin cu conturul desenat. Sursa nu mai există, deci o
	# rulare cu intrarea veche ar fi crăpat aici.
	{
		# Cheia de cufăr: o singură imagine de 128×128, deci „un cadru"
		"sursa": "res://harta/Chest/key.png",
		"iesire": "res://harta/Chest/key_contur.png",
		"cadre": 1,
		"culoare": GALBEN,
	},
	{
		# Magnetul de XP: tot o singură imagine de 128×128, ca și cheia
		"sursa": "res://xp/magnet.png",
		"iesire": "res://xp/magnet_contur.png",
		"cadre": 1,
		"culoare": NEGRU,
	},
]

# Undead Executioner Puppet — boss-ul dimensiunii Ender. Toate foile au cadre de 100×100,
# desenul e o siluetă NEAGRĂ, iar podeaua de acolo (nebuloasa) e aproape neagră: fără contur
# nu s-ar vedea deloc. Conturul cerut de Răzvan e albastru închis.
const PUPPET := "res://harta/Portal Ender/Undead executioner puppet/png/"
const PUPPET_FOI := ["idle2", "attacking", "skill1", "summon", "death"]

func _ready() -> void:
	for l in LUCRARI:
		_fa(l["sursa"], l["iesire"], int(l["cadre"]), 1, l.get("culoare", CONTUR))
	for nume in PUPPET_FOI:
		var sursa: String = PUPPET + nume + ".png"
		var img := Image.load_from_file(ProjectSettings.globalize_path(sursa))
		if img == null:
			print("!!! nu pot citi ", sursa)
			continue
		# cadrele sunt pătrate de 100px, deci grila se deduce singură din mărimea foii
		_fa(sursa, PUPPET + nume + "_contur.png", img.get_width() / 100, img.get_height() / 100, ALBASTRU)
	get_tree().quit()

func _fa(sursa: String, iesire: String, coloane: int, randuri: int, culoare: Color) -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(sursa))
	if src == null:
		print("!!! nu pot citi ", sursa)
		return
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	if w % coloane != 0 or h % randuri != 0:
		print("!!! ", sursa.get_file(), ": ", w, "×", h, " nu se împarte la ", coloane, "×", randuri)
		return
	var lat := w / coloane
	var inalt := h / randuri
	print(sursa.get_file(), ": ", w, "×", h, " · ", coloane, "×", randuri, " cadre de ", lat, "×", inalt)
	var pline := 0
	for r in randuri:
		for c in coloane:
			if _contur_cadru(src, c * lat, r * inalt, lat, inalt, r * coloane + c, culoare):
				pline += 1
	print("   cadre desenate: ", pline, " din ", coloane * randuri)
	var err := src.save_png(ProjectSettings.globalize_path(iesire))
	if err != OK:
		print("!!! nu pot scrie ", iesire, " (", err, ")")
		return
	print("   gata: ", iesire)

# Conturul unui singur cadru. Ne uităm DOAR în interiorul ferestrei cadrului: altfel desenul
# dintr-un cadru ar scoate contur în cadrul vecin, iar la rulare (unde cadrele sunt tăiate cu
# AtlasTexture) ar apărea o dâră mov pe margine.
#
# Întoarce `true` dacă în cadru chiar era ceva de desenat (celulele goale din grile nu sunt o
# eroare, doar nu ajung animații).
func _contur_cadru(img: Image, x_start: int, y_start: int, lat: int, inalt: int, idx: int, culoare: Color) -> bool:
	# Întâi harta de „aici e desen", ca să nu conturăm conturul pe care tocmai l-am pus.
	var plin := PackedByteArray()
	plin.resize(lat * inalt)
	var atinge_marginea := false
	var gol := true
	for y in inalt:
		for x in lat:
			var e_desen := img.get_pixel(x_start + x, y_start + y).a >= PRAG
			plin[y * lat + x] = 1 if e_desen else 0
			if e_desen:
				gol = false
				if x == 0 or y == 0 or x == lat - 1 or y == inalt - 1:
					atinge_marginea = true
	if gol:
		return false
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
				img.set_pixel(x_start + x, y_start + y, culoare)
	return true
