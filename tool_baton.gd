extends Node

# Generator: din bastona orientată nord-est (police baton.png) scoate o rotire COMPLETĂ, cadru
# cu cadru, fiecare cu contur mov de 2px (1px plin + 1px translucid = glow discret).
# Rulare: godot --headless --path <proj> res://tool_baton.tscn --quit-after 300

const DIR := "res://boss/lightning_burst_003_large_violet/"
const SURSA := DIR + "police baton.png"
const CADRE := 16                                # 16 × 22.5° = cerc complet
const CONTUR := Color(0.72, 0.28, 1.0, 1.0)      # mov
const PRAG := 0.35                               # de la ce alfa în sus considerăm că e desen

func _ready() -> void:
	var src := Image.load_from_file(SURSA)
	if src == null:
		print("!!! nu pot citi ", SURSA)
		get_tree().quit()
		return
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	# Centrul REAL al desenului (nu al fișierului): altfel bastona se învârte excentric și pare
	# că șchioapătă. Luăm dreptunghiul pixelilor opaci și ne rotim în jurul centrului lui.
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a >= PRAG:
				x0 = mini(x0, x); y0 = mini(y0, y)
				x1 = maxi(x1, x); y1 = maxi(y1, y)
	if x1 < 0:
		print("!!! imaginea e goală")
		get_tree().quit()
		return
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var latime := x1 - x0 + 1
	var inaltime := y1 - y0 + 1
	# pânza trebuie să încapă desenul rotit în orice poziție: diagonala + loc de contur
	var lat := int(ceil(sqrt(float(latime * latime + inaltime * inaltime)))) + 6
	if lat % 2 == 1:
		lat += 1
	print("sursă ", w, "×", h, " · desen ", latime, "×", inaltime, " · pânză ", lat, "×", lat)
	for i in CADRE:
		var unghi := TAU * i / CADRE
		var img := _roteste(src, cx, cy, lat, unghi)
		_contur(img)
		var cale := "%sframe%04d.png" % [DIR, i]
		var err := img.save_png(ProjectSettings.globalize_path(cale))
		if err != OK:
			print("!!! nu pot scrie ", cale, " (", err, ")")
	print("gata: ", CADRE, " cadre scrise în ", DIR)
	get_tree().quit()

# Rotire cu vecinul cel mai apropiat (pixel art: fără interpolare, ca să nu se încețoșeze).
# Mergem invers: pentru fiecare pixel din destinație aflăm din ce pixel al sursei vine.
func _roteste(src: Image, cx: float, cy: float, lat: int, unghi: float) -> Image:
	var dst := Image.create_empty(lat, lat, false, Image.FORMAT_RGBA8)
	var c := cos(-unghi)
	var s := sin(-unghi)
	var m := (lat - 1) * 0.5
	for y in lat:
		for x in lat:
			var dx := x - m
			var dy := y - m
			var sx := int(round(cx + dx * c - dy * s))
			var sy := int(round(cy + dx * s + dy * c))
			if sx >= 0 and sy >= 0 and sx < src.get_width() and sy < src.get_height():
				dst.set_pixel(x, y, src.get_pixel(sx, sy))
	return dst

# Contur de 2px: inelul lipit de desen e mov plin, al doilea e mov pe jumătate transparent —
# așa arată a strălucire, nu a chenar desenat cu creionul.
func _contur(img: Image) -> void:
	var lat := img.get_width()
	var inalt := img.get_height()
	var plin := PackedByteArray()
	plin.resize(lat * inalt)
	for y in inalt:
		for x in lat:
			plin[y * lat + x] = 1 if img.get_pixel(x, y).a >= PRAG else 0
	for y in inalt:
		for x in lat:
			if plin[y * lat + x] == 1:
				continue
			var d := 99
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= lat or ny >= inalt:
						continue
					if plin[ny * lat + nx] == 1:
						d = mini(d, maxi(abs(ox), abs(oy)))
			if d == 1:
				img.set_pixel(x, y, CONTUR)
			elif d == 2:
				img.set_pixel(x, y, Color(CONTUR.r, CONTUR.g, CONTUR.b, 0.5))
