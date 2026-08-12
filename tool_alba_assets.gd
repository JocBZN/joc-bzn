extends Node

# Taie din poza omului cu paharele (`harta/Alba Neagra/Alba Neagra.png`, 128×128 — ACEEAȘI poză
# care se vede în lume) cele două imagini de care are nevoie meniul (`alba_menu.gd`):
#
#   scene.png — omul și masa lui, FĂRĂ cele trei pahare (ele trebuie să se miște separat)
#   cup.png   — UN pahar, decupat FIX pe conturul lui negru, cu masa din jur transparentă
#
# Meniul desenează ACELAȘI pahar (cel din STÂNGA, are silueta întreagă) pe toate cele trei locuri,
# cum a cerut Răzvan: „copiază paharul din stânga și dă copy-paste în celelalte locuri".
# Bila nu se desenează aici: e sfera de XP din joc (`xp/xp1.png`).
#
# Rulează-l dacă schimbi poza omului:
#   godot --headless --path <proiect> res://tool_alba_assets.tscn
#   godot --headless --path <proiect> --import      (ca noile PNG-uri să poată fi `load()`-ate)
# ⚠️ Apoi copiază constantele tipărite la final în `alba_menu.gd` — sunt în pixelii ACESTEI poze.
#
# ---------------------------------------------------------------------------
# CUM SE DECUPEAZĂ UN PAHAR (partea netrivială)
# ---------------------------------------------------------------------------
# Paharul e desenat cu un CONTUR ÎNCHIS, deci silueta lui = „tot ce e înăuntrul conturului" +
# conturul însuși. Nu se poate lua după cât e de deschis la culoare: umbrele de pe pahar au EXACT
# aceeași valoare ca tăblia mesei (155) — prima variantă lua doar pixelii aproape albi și paharul
# ieșea ciuruit, ca o pată de lapte mâncată de molii.
#
# Deci:
#   1. pornim dintr-un pixel aproape alb (numai paharele au așa ceva pe tăblie);
#   2. umplem în lături tot ce NU e contur — ne oprim singuri în linia neagră, oricât de închise
#      sau deschise ar fi pixelii dinăuntru; ăsta e INTERIORUL;
#   3. adăugăm conturul: pixelii închiși lipiți (sus/jos/stânga/dreapta) de interior.
#
# ⚠️ Pasul 3 ia UN SINGUR pixel în jur, nu urmărește linia neagră mai departe: sus, conturul
# paharului e lipit de muchia neagră a mesei (rândul 82), care merge dintr-o margine în alta a
# pozei. Dacă am urmări linia, am decupa jumătate de masă odată cu paharul.
#
# ⚠️ PRAG_CONTUR trebuie să fie 0.35, nu 0.20: conturul nu e negru uniform, pe stânga paharului
# (rândul 90) e un gri de ~0.25. Cu 0.20 umplerea se scurgea prin el pe toată masa — de aici
# veneau decupajele stricate.
#
# ---------------------------------------------------------------------------
# CUM SE ȘTERG DE PE MASĂ
# ---------------------------------------------------------------------------
# Nu putem umple cu „culoarea medie a mesei": tăblia are textură (crăpături, pete), iar sus, peste
# muchia mesei, pixelii sunt ai omului, nu ai mesei. Deci peticul se COPIAZĂ pe rânduri, în
# OGLINDĂ, din pixelii de lângă pahar: jumătatea stângă din stânga lui, jumătatea dreaptă din
# dreapta lui. Așa fiecare rând se repară cu material din chiar rândul lui — muchia neagră a mesei
# iese muchie, tăblia iese tăblie, mâinile omului ies mâini.
#
# ⚠️ Se lucrează pe LĂȚIMEA MĂȘTII PE RÂNDUL ĂLA, nu pe toată caseta: sus paharul e îngust, iar
# dacă am șterge toată lățimea casetei am scobi în mâinile omului. Și dacă sursa iese din poză sau
# e transparentă (în stânga omului nu e nimic), se ia din partea cealaltă.
#
# ⚠️ Paharele se peticesc de la STÂNGA la DREAPTA: cel din mijloc copiază din zona în care era cel
# din stânga, deja reparată. Invers, ar copia pixeli de pahar înapoi pe masă.

const SURSA := "res://harta/Alba Neagra/Alba Neagra.png"
const OUT_SCENA := "res://harta/Alba Neagra/scene.png"
const OUT_PAHAR := "res://harta/Alba Neagra/cup.png"

const BANDA_SUS := 78       # între ce rânduri căutăm pahare: tăblia mesei
const BANDA_JOS := 98       # ⚠️ NU mai jos: de la 101 începe fața din față a mesei, care are
                            #    pixeli deschiși ce ar porni o umplere pe toată piatra
const PRAG_DESCHIS := 0.70  # de unde pornim căutarea: numai paharele sunt așa deschise pe tăblie
const PRAG_CONTUR := 0.35   # sub cât e „contur" (vezi ⚠️ de mai sus; tăblia e ≥ 0.5)
const MIN_PIXELI := 40      # sub atât e o lucire de pe piatră, nu un pahar
const MAX_PIXELI := 400     # peste atât s-a scurs umplerea pe masă — aruncăm insula
const MAX_LATIME := 24      # la fel, dar pe lățime/înălțime
const MARJA_JOS := 2        # rânduri în plus șterse sub pahar (umbra lui de contact)

var _interzis := {}         # pixelii tuturor paharelor: nu se copiază din ei când peticim masa

func _ready() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SURSA))
	img.convert(Image.FORMAT_RGBA8)

	var pahare := _gaseste_paharele(img)
	for pah in pahare:
		print("pahar: ", pah["box"], "  pixeli=", (pah["masca"] as Dictionary).size())
	if pahare.size() != 3:
		push_error("Am găsit %d pahare, nu 3. Verifică pragurile." % pahare.size())
		get_tree().quit(1)
		return

	# 1. paharul decupat — cel din STÂNGA: are silueta întreagă (cel din mijloc e pe jumătate
	#    ascuns de mâinile omului), iar unul singur trebuie să meargă pe toate cele trei locuri
	var p0: Dictionary = pahare[0]
	var cutie: Rect2i = p0["box"]
	var masca: Dictionary = p0["masca"]
	var pahar := Image.create(cutie.size.x, cutie.size.y, false, Image.FORMAT_RGBA8)
	pahar.fill(Color(0, 0, 0, 0))
	for p in masca:
		pahar.set_pixelv(p - cutie.position, img.get_pixelv(p))
	pahar.save_png(ProjectSettings.globalize_path(OUT_PAHAR))
	_arata(pahar)

	# 2. scena fără pahare
	# ⚠️ Întâi însemnăm TOATE paharele ca „sursă interzisă": altfel peticul unui pahar copiază
	# pixeli din vecinul lui (sau din franjurii lui gri) și pe masă rămân cioburi negre.
	for pah in pahare:
		for c in (pah["masca"] as Dictionary):
			_interzis[c] = true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					_interzis[c + Vector2i(dx, dy)] = true
	for pah in pahare:
		_sterge(img, pah["masca"], pah["box"])
	img.save_png(ProjectSettings.globalize_path(OUT_SCENA))

	# 3. cifrele pentru `alba_menu.gd`
	print("\n--- de copiat în alba_menu.gd ---")
	var talpi: Array = []
	var centre: Array = []
	for pah in pahare:
		var b: Rect2i = pah["box"]
		centre.append(b.position.x + b.size.x / 2.0)
		talpi.append(b.end.y)
	print("const SLOT_X := [%.1f, %.1f, %.1f]" % [centre[0], centre[1], centre[2]])
	print("const CUP_W := %d.0" % cutie.size.x)
	print("const CUP_H := %d.0" % cutie.size.y)
	# TALPA = talpa paharului DECUPAT (cel din stânga): el se desenează pe toate trei locurile,
	# deci el dă linia pe care stau. (Cel din mijloc e desenat un pixel mai jos în poza originală.)
	print("const TALPA := %.1f" % (cutie.end.y as float))
	print("(tălpile celor trei pahare: %s; caseta celui decupat: %s)" % [talpi, cutie])
	get_tree().quit()

# --- găsirea paharelor -------------------------------------------------------
func _gaseste_paharele(img: Image) -> Array:
	var gasite: Array = []
	var vazut := {}
	for y in range(BANDA_SUS, BANDA_JOS + 1):
		for x in img.get_width():
			var p := Vector2i(x, y)
			if vazut.has(p) or _zid(img, p) or not _deschis(img, p):
				continue
			# INTERIORUL: tot ce se poate atinge fără să treci prin contur
			var interior: Dictionary = {}
			var q: Array[Vector2i] = [p]
			while not q.is_empty():
				var c: Vector2i = q.pop_back()
				if interior.has(c) or not _in_banda(img, c) or _zid(img, c):
					continue
				interior[c] = true
				vazut[c] = true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					q.append(c + d)
			if interior.size() < MIN_PIXELI or interior.size() > MAX_PIXELI:
				continue
			var masca := interior.duplicate()
			# CONTURUL: pixelii închiși lipiți de interior (doar un pixel în jur — vezi ⚠️ de sus)
			for c in interior:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var v: Vector2i = c + d
					if not masca.has(v) and _in_banda(img, v) and _contur(img, v):
						masca[v] = true
			_astupa_crestaturile(img, masca)
			var box := Rect2i(masca.keys()[0], Vector2i.ONE)
			for c in masca:
				box = box.expand(c).expand(c + Vector2i.ONE)
			if box.size.x > MAX_LATIME or box.size.y > MAX_LATIME:
				continue
			gasite.append({"box": box, "masca": masca})
	gasite.sort_custom(func(a, b): return (a["box"] as Rect2i).position.x < (b["box"] as Rect2i).position.x)
	return gasite

# Unde conturul e desenat pe DOI pixeli (unul negru, unul gri), interiorul se oprește la cel gri
# și în siluetă rămâne o crestătură de un pixel. O astupăm geometric: un pixel închis înconjurat
# pe 3 din 4 laturi de mască e evident tot contur.
# ⚠️ Nu merge cu 2 laturi: la rândul 82 conturul paharului e lipit de muchia neagră a mesei, care
# traversează toată poza — cu pragul prea mic am decupa bucăți din masă odată cu paharul.
func _astupa_crestaturile(img: Image, masca: Dictionary) -> void:
	for pas in 3:
		var noi: Array[Vector2i] = []
		for c in masca.keys():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = c + d
				if masca.has(v) or not _in_banda(img, v) or not _contur(img, v):
					continue
				var laturi := 0
				for e in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if masca.has(v + e):
						laturi += 1
				if laturi >= 3:
					noi.append(v)
		if noi.is_empty():
			return
		for v in noi:
			masca[v] = true

func _in_banda(img: Image, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
		and p.y >= BANDA_SUS and p.y <= BANDA_JOS

func _lumina(img: Image, p: Vector2i) -> float:
	var c := img.get_pixelv(p)
	return (c.r + c.g + c.b) / 3.0

func _gol(img: Image, p: Vector2i) -> bool:
	return img.get_pixelv(p).a < 0.5

func _contur(img: Image, p: Vector2i) -> bool:
	return not _gol(img, p) and _lumina(img, p) < PRAG_CONTUR

# zid pentru umplere: conturul negru, dar și golul (altfel s-ar scurge pe lângă om)
func _zid(img: Image, p: Vector2i) -> bool:
	return _gol(img, p) or _lumina(img, p) < PRAG_CONTUR

func _deschis(img: Image, p: Vector2i) -> bool:
	return _lumina(img, p) > PRAG_DESCHIS

# --- ștersul unui pahar de pe masă -------------------------------------------
func _sterge(img: Image, masca: Dictionary, box: Rect2i) -> void:
	for y in range(box.position.y, box.end.y + MARJA_JOS):
		var a: int
		var b: int
		if y >= box.end.y - 2:
			# la bază umbra de contact e mai lată decât paharul: ștergem toată caseta
			a = box.position.x
			b = box.end.x - 1
		else:
			# sus paharul e îngust și are mâinile omului lângă el: ștergem doar cât ține
			# masca pe rândul ăsta, plus un pixel de fiecare parte (franjurii gri ai conturului)
			a = box.end.x
			b = box.position.x
			for x in range(box.position.x, box.end.x):
				if masca.has(Vector2i(x, y)):
					a = mini(a, x)
					b = maxi(b, x)
			if a > b:
				continue
			a -= 1
			b += 1
		_petic_rand(img, y, a, b)

# Un rând [a..b] reparat în oglindă: jumătatea stângă din stânga lui, dreapta din dreapta lui.
func _petic_rand(img: Image, y: int, a: int, b: int) -> void:
	if y < 0 or y >= img.get_height():
		return
	var w := b - a + 1
	var st := _surse(img, y, a - 1, -1, w)
	var dr := _surse(img, y, b + 1, 1, w)
	if st.is_empty() and dr.is_empty():
		return                                  # n-avem de unde copia: lăsăm rândul cum e
	for i in w:
		var sursa := _ia(st, i) if i < w / 2.0 else _ia(dr, w - 1 - i)
		if sursa < 0:
			sursa = _ia(dr, w - 1 - i) if i < w / 2.0 else _ia(st, i)
		if sursa >= 0:
			img.set_pixel(a + i, y, img.get_pixel(sursa, y))

# Următorii `cate` pixeli buni pornind de la `start` în direcția `pas`: sar peste transparent și
# peste zonele paharelor (⚠️ altfel un pahar se peticește cu pixeli din alt pahar).
func _surse(img: Image, y: int, start: int, pas: int, cate: int) -> Array[int]:
	var gasite: Array[int] = []
	var x := start
	while gasite.size() < cate and x >= 0 and x < img.get_width():
		var p := Vector2i(x, y)
		if not _gol(img, p) and not _interzis.has(p):
			gasite.append(x)
		x += pas
	return gasite

# Al `i`-lea pixel bun; dacă s-au terminat, îl repetăm pe ultimul (mai bine decât să sărim în
# celălalt capăt al pozei, unde materialul e cu totul altul).
func _ia(lista: Array[int], i: int) -> int:
	if lista.is_empty():
		return -1
	return lista[mini(i, lista.size() - 1)]

# --- verificare vizuală în consolă -------------------------------------------
func _arata(pahar: Image) -> void:
	print("\n--- paharul decupat (' ' = transparent) ---")
	for y in pahar.get_height():
		var rand := ""
		for x in pahar.get_width():
			var c := pahar.get_pixel(x, y)
			if c.a < 0.5:
				rand += " "
			elif (c.r + c.g + c.b) / 3.0 < PRAG_CONTUR:
				rand += "#"
			else:
				rand += "o"
		print("|" + rand + "|")
