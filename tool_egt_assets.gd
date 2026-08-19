extends Node

# Scoate din poza mare a mesei (`harta/EGT/Roulette Table.png`) imaginile pe care le folosește
# cazinoul (`casino.gd` + `casino_roata.gd`):
#
#   table.png     — masa cu fundalul alb făcut TRANSPARENT (dacă poza vine cu colțuri albe;
#                   poza din 2026-08-19 vine deja cu fundal transparent, deci pasul nu face nimic)
#   wheel.png     — DISCUL roții, decupat rotund, ca să poată fi rotit separat peste masă
#   chip_red.png  — jetonul roșu din rândul de jetoane de jos, pus peste zona pe care pariezi
#   ball.png      — BILA de ruletă. Nu e decupată din poză (poza n-are așa ceva): e DESENATĂ aici,
#                   pixel cu pixel, cu paleta artei (fildeș + contur închis, ca jetoanele).
#
# Rulează-l dacă schimbi poza mesei:
#   godot --headless --path <proiect> res://tool_egt_assets.tscn
# apoi OBLIGATORIU `--import`, altfel jocul rulat direct nu poate `load()` texturile noi.
# ⚠️ Apoi remăsoară și constantele de geometrie din `casino.gd` (GRID_X0, WHEEL_CENTER etc.),
# fiindcă sunt date în pixelii ACESTEI poze. Unealta cu care le-am măsurat (linii albe, centrul
# roții, unghiurile buzunarelor) e descrisă în CLAUDE.md, la sesiunea din 2026-08-19.

const SURSA := "res://harta/EGT/Roulette Table.png"

# Măsurate pe poza din 2026-08-19 (1660×948). Centrul e ales de un căutător care ia raza ramei
# de aur la 360 de unghiuri și alege punctul care o face cât mai constantă — nu din ochi.
const WHEEL_CENTRU := Vector2i(261, 650)   # centrul discului roții în poza mare (măsurat: 260,5 / 649,5)
const WHEEL_RAZA := 174                    # rama de aur se termină la ~171; 174 lasă și umbra ei
const CHIP_CROP := Rect2i(929, 726, 76, 78)  # pătratul în care încape jetonul roșu (al 4-lea din rândul de jos)

# --- BILA ---
const BALL_D := 22            # cât de mare e bila, în pixelii pozei mesei
const BALL_CONTUR := Color8(58, 49, 40)
const BALL_RAMPA := [         # de la lumină la umbră (fildeș, ca bila adevărată de ruletă)
	Color8(255, 252, 244),
	Color8(242, 236, 221),
	Color8(220, 210, 187),
	Color8(179, 167, 141),
]

func _ready() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SURSA))

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

	# ---- bila ----
	_deseneaza_bila().save_png(ProjectSettings.globalize_path("res://harta/EGT/ball.png"))

	print("gata: table.png (", masa.get_size(), ")  wheel.png (", disc.get_size(), ")  chip_red.png (", chip.get_size(), ")  ball.png (", BALL_D, ")")
	get_tree().quit()

# O bilă de ruletă în stilul pozei: contur închis de 1px, patru trepte de fildeș și o sclipire
# în stânga-sus. Desenată, nu decupată — și pentru că poza n-are bilă, și pentru că așa se poate
# schimba mărimea fără să se împăstreze (poza s-ar întinde, desenul se redesenează).
func _deseneaza_bila() -> Image:
	var im := Image.create(BALL_D, BALL_D, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var c := Vector2(BALL_D - 1, BALL_D - 1) * 0.5
	var r := float(BALL_D) * 0.5
	var lumina := Vector2(-0.58, -0.62).normalized()   # de sus-stânga, ca umbrele jetoanelor din poză
	for y in BALL_D:
		for x in BALL_D:
			var p := Vector2(x, y) - c
			var dist := p.length()
			if dist > r - 0.5:
				continue
			if dist > r - 1.6:
				im.set_pixel(x, y, BALL_CONTUR)
				continue
			# „sferă": cât de mult e întors pixelul spre lumină
			var t: float = clampf(p.normalized().dot(lumina) * (dist / r), -1.0, 1.0)
			var i := 3
			if t > 0.45: i = 0
			elif t > 0.0: i = 1
			elif t > -0.5: i = 2
			im.set_pixel(x, y, BALL_RAMPA[i])
	# sclipirea (2×2 pixeli albi), ca la orice bilă lustruită
	var sx := int(c.x + lumina.x * r * 0.45)
	var sy := int(c.y + lumina.y * r * 0.45)
	for dy in 2:
		for dx in 2:
			im.set_pixel(sx + dx, sy + dy, Color(1, 1, 1))
	return im

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
