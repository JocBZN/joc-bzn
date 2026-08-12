extends Node

# Taie din poza omului cu paharele (`harta/Alba Neagra/Alba Neagra.png`, 128×128 — ACEEAȘI poză
# care se vede în lume) cele două imagini de care are nevoie meniul (`alba_menu.gd`):
#
#   scene.png — omul și masa lui, FĂRĂ cele trei pahare (ele trebuie să se miște separat)
#   cup.png   — UN pahar, decupat, cu masa din jurul lui transparentă
#
# Bila nu se desenează aici: e sfera de XP din joc (`xp/xp1.png`), cum a cerut Răzvan.
#
# Rulează-l dacă schimbi poza omului:
#   godot --headless --path <proiect> res://tool_alba_assets.tscn
#   godot --headless --path <proiect> --import      (ca noile PNG-uri să poată fi `load()`-ate)
# ⚠️ Apoi remăsoară constantele de geometrie din `alba_menu.gd` — sunt în pixelii ACESTEI poze.
# Unealta le și tipărește la final, gata de copiat.
#
# ---------------------------------------------------------------------------
# CUM GĂSEȘTE PAHARELE
# ---------------------------------------------------------------------------
# Sunt singurele lucruri APROAPE ALBE de pe masă (masa e gri-cald, omul e albastru/maro), deci le
# găsim ca „insule" de pixeli deschiși, cu flood fill, în banda tăbliei. Insulele mai mici de
# `MIN_PIXELI` sunt lumini de pe piatră, nu pahare.
#
# Conturul: paharul e desenat cu o linie neagră care NU e deschisă la culoare, deci nu intră în
# insulă. Îl luăm separat — orice pixel închis lipit de insulă (8 vecini) face parte din pahar.
# Fără asta, paharul decupat iese fără contur și arată ca o pată de lapte.
#
# ---------------------------------------------------------------------------
# CUM SE ȘTERG DE PE MASĂ (partea netrivială)
# ---------------------------------------------------------------------------
# Nu putem umple cu „culoarea medie a mesei": tăblia are textură (crăpături, pete), iar deasupra
# muchiei din spate pixelii sunt ai omului, nu ai mesei. Deci peticul se COPIAZĂ pe rânduri, în
# OGLINDĂ, din pixelii de lângă pahar (la stânga lui). Pe rândurile de deasupra muchiei, sursa e
# tot om/fundal, deci peticul iese corect fără să știm noi unde e muchia.
#
# ⚠️ Paharele se peticesc de la STÂNGA la DREAPTA: cel din mijloc copiază din zona în care era cel
# din stânga, deja reparată. Invers, ar copia pixeli de pahar înapoi pe masă.

const SURSA := "res://harta/Alba Neagra/Alba Neagra.png"
const OUT_SCENA := "res://harta/Alba Neagra/scene.png"
const OUT_PAHAR := "res://harta/Alba Neagra/cup.png"

const BANDA_SUS := 78      # între ce rânduri căutăm pahare (tăblia mesei; mâinile omului stau mai sus)
const BANDA_JOS := 108
const PRAG_DESCHIS := 0.645 # peste cât e „pahar" (corpul paharului e 174…243, tăblia e ≤155)
const PRAG_CONTUR := 0.20  # sub cât e „contur" (conturul e 1…4; umbra de pe masă e ~100, deci rămâne pe masă)
const MIN_PIXELI := 25     # sub atât e o lucire de pe piatră, nu un pahar
const MARJA_JOS := 2       # rânduri în plus șterse sub pahar (umbra lui de contact)

func _ready() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SURSA))
	img.convert(Image.FORMAT_RGBA8)

	var pahare := _gaseste_paharele(img)
	for pah in pahare:
		print("insulă: ", pah["box"], "  pixeli=", (pah["masca"] as Dictionary).size())
	if pahare.size() != 3:
		push_error("Am găsit %d pahare, nu 3. Verifică pragurile." % pahare.size())
		get_tree().quit(1)
		return

	# 1. paharul decupat — îl luăm pe cel din STÂNGA (are silueta întreagă; cel din mijloc e
	#    desenat mai scund, iar unul singur trebuie să meargă pe toate cele trei locuri)
	var p0: Dictionary = pahare[0]
	var cutie: Rect2i = p0["box"]
	var pahar := Image.create(cutie.size.x, cutie.size.y, false, Image.FORMAT_RGBA8)
	pahar.fill(Color(0, 0, 0, 0))
	var masca: Dictionary = p0["masca"]
	for p in masca:
		pahar.set_pixelv(p - cutie.position, img.get_pixelv(p))
	pahar.save_png(ProjectSettings.globalize_path(OUT_PAHAR))

	# 2. scena fără pahare
	for pah in pahare:
		_sterge(img, (pah["box"] as Rect2i).grow(1))
	img.save_png(ProjectSettings.globalize_path(OUT_SCENA))

	# 3. cifrele pentru `alba_menu.gd`
	print("\n--- de copiat în alba_menu.gd ---")
	var talpi: Array = []
	var centre: Array = []
	for pah in pahare:
		var b: Rect2i = pah["box"]
		centre.append(b.position.x + b.size.x / 2.0)
		talpi.append(b.end.y - MARJA_JOS)
	print("const SLOT_X := [%.1f, %.1f, %.1f]" % [centre[0], centre[1], centre[2]])
	print("const CUP_W := %d.0" % cutie.size.x)
	print("const CUP_H := %d.0" % cutie.size.y)
	print("talpile paharelor (y): ", talpi, "  -> TALPA recomandat: ", talpi.max())
	print("caseta paharului decupat: ", cutie)
	get_tree().quit()

# --- găsirea paharelor -------------------------------------------------------
func _gaseste_paharele(img: Image) -> Array:
	var gasite: Array = []
	var vazut := {}
	for y in range(BANDA_SUS, BANDA_JOS):
		for x in img.get_width():
			var p := Vector2i(x, y)
			if vazut.has(p) or not _deschis(img, p):
				continue
			# insula de pixeli deschiși
			var insula: Dictionary = {}
			var q: Array[Vector2i] = [p]
			while not q.is_empty():
				var c: Vector2i = q.pop_back()
				if insula.has(c) or not _in_banda(img, c) or not _deschis(img, c):
					continue
				insula[c] = true
				vazut[c] = true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					q.append(c + d)
			if insula.size() < MIN_PIXELI:
				continue
			var masca := insula.duplicate()
			# ⚠️ GĂURILE. Paharul are pe el umbre de EXACT aceeași culoare ca tăblia (155), deci
			# pragul de „deschis" le lasă pe dinafară și paharul decupat iese ciuruit — prima
			# încercare arăta ca o pată de lapte mâncată de molii. Le luăm geometric: tot ce e
			# ÎNCONJURAT de insulă (nu poți ajunge la el de pe marginea casetei fără să treci prin
			# insulă) e pahar, indiferent ce culoare are.
			for gaura in _gauri(insula):
				masca[gaura] = true
			# conturul: pixelii închiși lipiți de mască
			for c in masca.keys():
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var v: Vector2i = c + Vector2i(dx, dy)
						if masca.has(v) or not _in_banda(img, v):
							continue
						var col := img.get_pixelv(v)
						if col.a > 0.5 and (col.r + col.g + col.b) / 3.0 < PRAG_CONTUR:
							masca[v] = true
			var box := Rect2i(masca.keys()[0], Vector2i.ONE)
			for c in masca:
				box = box.expand(c).expand(c + Vector2i.ONE)
			gasite.append({"box": box, "masca": masca})
	gasite.sort_custom(func(a, b): return (a["box"] as Rect2i).position.x < (b["box"] as Rect2i).position.x)
	return gasite

# Pixelii înconjurați complet de `insula`: umplu caseta ei (lărgită cu 1) pornind de pe margine,
# fără să calc pe insulă; ce rămâne neatins e „gaură".
func _gauri(insula: Dictionary) -> Array:
	var box := Rect2i(insula.keys()[0], Vector2i.ONE)
	for c in insula:
		box = box.expand(c).expand(c + Vector2i.ONE)
	box = box.grow(1)
	var atins := {}
	var q: Array[Vector2i] = []
	for x in range(box.position.x, box.end.x):
		q.append(Vector2i(x, box.position.y))
		q.append(Vector2i(x, box.end.y - 1))
	for y in range(box.position.y, box.end.y):
		q.append(Vector2i(box.position.x, y))
		q.append(Vector2i(box.end.x - 1, y))
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		if atins.has(c) or insula.has(c) or not box.has_point(c):
			continue
		atins[c] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			q.append(c + d)
	var gasite: Array = []
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p := Vector2i(x, y)
			if not atins.has(p) and not insula.has(p):
				gasite.append(p)
	return gasite

func _in_banda(img: Image, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
		and p.y >= BANDA_SUS and p.y <= BANDA_JOS

func _deschis(img: Image, p: Vector2i) -> bool:
	var c := img.get_pixelv(p)
	return c.a > 0.5 and (c.r + c.g + c.b) / 3.0 > PRAG_DESCHIS

# --- ștersul unui pahar de pe masă -------------------------------------------
# Rând cu rând, în oglindă, din pixelii de la STÂNGA casetei.
func _sterge(img: Image, box: Rect2i) -> void:
	var w := box.size.x
	for y in range(box.position.y, box.end.y + MARJA_JOS):
		if y < 0 or y >= img.get_height():
			continue
		for i in w:
			var dest := Vector2i(box.position.x + i, y)
			var sursa := Vector2i(box.position.x - 1 - i, y)   # oglindit
			if sursa.x < 0:
				sursa.x = box.end.x + i                        # dacă nu e loc la stânga, ia din dreapta
			if sursa.x < 0 or sursa.x >= img.get_width():
				continue
			img.set_pixelv(dest, img.get_pixelv(sursa))
