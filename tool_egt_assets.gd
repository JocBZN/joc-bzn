extends Node

# Scoate din poza mare a mesei (`harta/EGT/Roulette Table.png`) cele trei imagini pe care le
# folosește cazinoul (`casino.gd`):
#
#   table.png     — masa cu fundalul alb făcut TRANSPARENT (poza originală are colțurile albe,
#                   iar pe fundalul întunecat al meniului se vedea ca un dreptunghi alb)
#   wheel.png     — DISCUL roții, decupat rotund, ca să poată fi rotit separat peste masă
#   chip_red.png  — jetonul roșu din rândul de jetoane de jos, pus peste zona pe care pariezi
#
# Rulează-l dacă schimbi poza mesei:
#   godot --headless --path <proiect> res://tool_egt_assets.tscn
# ⚠️ Apoi remăsoară și constantele de geometrie din `casino.gd` (GRID_X0, WHEEL_CENTER etc.),
# fiindcă sunt date în pixelii ACESTEI poze.

const SURSA := "res://harta/EGT/Roulette Table.png"

const WHEEL_CENTRU := Vector2i(265, 652)   # centrul discului roții în poza mare
const WHEEL_RAZA := 173                    # până unde se întinde rama aurie (partea care se rotește)
const CHIP_CROP := Rect2i(936, 739, 72, 72)  # pătratul în care încape jetonul roșu (al 4-lea de jos)

func _ready() -> void:
	var img := Image.load_from_file(SURSA)

	# ---- masa, fără fundalul alb ----
	var masa := img.duplicate() as Image
	masa.convert(Image.FORMAT_RGBA8)
	_umple_din_margini(masa, _e_alb)
	masa.save_png(ProjectSettings.globalize_path("res://harta/EGT/table.png"))

	# ---- discul roții ----
	var d := WHEEL_RAZA * 2
	var disc := img.get_region(Rect2i(WHEEL_CENTRU.x - WHEEL_RAZA, WHEEL_CENTRU.y - WHEEL_RAZA, d, d))
	disc.convert(Image.FORMAT_RGBA8)
	var c := Vector2(WHEEL_RAZA, WHEEL_RAZA)
	for y in d:
		for x in d:
			if Vector2(x, y).distance_to(c) > float(WHEEL_RAZA) - 1.0:
				disc.set_pixel(x, y, Color(0, 0, 0, 0))
	disc.save_png(ProjectSettings.globalize_path("res://harta/EGT/wheel.png"))

	# ---- jetonul roșu ----
	var chip := img.get_region(CHIP_CROP)
	chip.convert(Image.FORMAT_RGBA8)
	_umple_din_margini(chip, _e_verde)
	chip.save_png(ProjectSettings.globalize_path("res://harta/EGT/chip_red.png"))

	print("gata: table.png (", masa.get_size(), ")  wheel.png (", disc.get_size(), ")  chip_red.png (", chip.get_size(), ")")
	get_tree().quit()

# Pornim din marginile imaginii și ștergem tot ce trece testul `test`, întinzându-ne din
# aproape în aproape. Flood fill, nu un simplu test de culoare pe toată imaginea: altfel
# liniile albe ale grilei (la masă) sau albul jetoanelor ar fi dispărut și ele.
func _umple_din_margini(im: Image, test: Callable) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var vazut := {}
	var coada: Array[Vector2i] = []
	for x in w:
		coada.append(Vector2i(x, 0))
		coada.append(Vector2i(x, h - 1))
	for y in h:
		coada.append(Vector2i(0, y))
		coada.append(Vector2i(w - 1, y))
	while coada.size() > 0:
		var p: Vector2i = coada.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or vazut.has(p):
			continue
		vazut[p] = true
		if not test.call(im.get_pixel(p.x, p.y)):
			continue
		im.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		coada.append(Vector2i(p.x + 1, p.y))
		coada.append(Vector2i(p.x - 1, p.y))
		coada.append(Vector2i(p.x, p.y + 1))
		coada.append(Vector2i(p.x, p.y - 1))

func _e_alb(c: Color) -> bool:
	return c.a > 0.5 and c.r > 0.90 and c.g > 0.90 and c.b > 0.90

# Pânza verde de sub jeton (inclusiv umbra lui, tot verde închis). Jetonul e roșu/alb/negru,
# deci nu trece testul.
func _e_verde(c: Color) -> bool:
	return c.a > 0.5 and c.g > c.r * 1.12 and c.g > c.b * 1.12
