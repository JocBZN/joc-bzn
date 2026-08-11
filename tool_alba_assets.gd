extends Node

# Scoate din poza mare a mesei de Alba-Neagra (`harta/Alba Neagra/Alba Neagra Table.png`) cele
# două imagini de care are nevoie meniul (`alba_menu.gd`):
#
#   table.png  — masa FĂRĂ cele trei pahare (ele trebuie să se poată mișca separat) și cu
#                fundalul negru făcut transparent
#   cup.png    — UN pahar, decupat din poză, cu masa din jurul lui făcută transparentă
#
# Bila nu se desenează aici: e sfera de XP din joc (`xp/xp1.png`), cum a cerut Răzvan.
#
# Rulează-l dacă schimbi poza mesei:
#   godot --headless --path <proiect> res://tool_alba_assets.tscn
#   godot --headless --path <proiect> --import      (ca noile PNG-uri să poată fi `load()`-ate)
# ⚠️ Apoi remăsoară constantele de geometrie din `alba_menu.gd` — sunt date în pixelii ACESTEI poze.
#
# ---------------------------------------------------------------------------
# CUM SE ȘTERG PAHARELE (partea netrivială)
# ---------------------------------------------------------------------------
# Paharele nu stau într-un dreptunghi gol: ele ies cu vârful DEASUPRA muchiei din spate a mesei,
# deci în caseta fiecăruia sunt și pixeli de masă, și pixeli de fundal. Un dreptunghi umplut cu
# „culoarea medie a mesei" ar fi tăiat muchia din spate în trei locuri.
#
# De aia peticul se COPIAZĂ pe rânduri, dintr-o fâșie curată de masă de lângă pahar (spațiile
# dintre pahare, respectiv marginile). Pe un rând de deasupra muchiei, fâșia curată e transparentă
# — deci petecul iese transparent exact acolo unde trebuie, fără să știm noi unde e muchia.
# Fâșia se oglindește la fiecare repetare, ca să nu se vadă un tipar care se repetă.
const SURSA := "res://harta/Alba Neagra/Alba Neagra Table.png"
const OUT_MASA := "res://harta/Alba Neagra/table.png"
const OUT_PAHAR := "res://harta/Alba Neagra/cup.png"

const MARJA := 6         # cu câți pixeli lărgim caseta unui pahar (umbra lui de pe masă)
# ⚠️ Căutăm conturul negru DOAR în banda de sus a pozei. Fața din față a mesei are ornamente
# săpate, cu linii aproape la fel de închise ca al paharelor: fără bandă, caseta unui pahar cobora
# până la 794 (adică peste tot ornamentul) și mai apărea și un al patrulea „pahar" de 54px, care
# era de fapt crăpătura din dreapta mesei. Banda ține doar tăblia.
const BANDA_JOS := 460   # până unde căutăm pahare (pixeli din poza sursă)
const LAT_MIN := 100     # sub atât nu e pahar, e o zgârietură/crăpătură

func _ready() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SURSA))
	img.convert(Image.FORMAT_RGBA8)

	# 1. fundalul negru → transparent (flood fill din margini, ca la `tool_egt_assets.gd`)
	_umple_din_margini(img, _e_negru)

	# 2. unde sunt paharele? Conturul lor e NEGRU GROS, iar după pasul 1 negrul din poză a rămas
	#    doar pe ele — deci coloanele cu pixeli negri sunt exact paharele.
	var casete := _casete_pahare(img)
	print("pahare gasite: ", casete.size())
	for c in casete:
		print("  ", c)
	if casete.size() != 3:
		push_error("astept 3 pahare, am gasit %d — verifica pragurile" % casete.size())
		get_tree().quit(1)
		return

	# 3. paharul din MIJLOC, decupat (e cel văzut cel mai din față, deci cel mai neutru)
	var pahar := _decupeaza_pahar(img, casete[1])
	pahar.save_png(ProjectSettings.globalize_path(OUT_PAHAR))

	# 4. masa fără pahare
	var masa := img.duplicate() as Image
	for c in casete:
		_petic(masa, c, casete)
	masa.save_png(ProjectSettings.globalize_path(OUT_MASA))

	print("gata: table.png (", masa.get_size(), ")  cup.png (", pahar.get_size(), ")")
	get_tree().quit()

# ---------------------------------------------------------------------------
# Casetele celor trei pahare, din coloanele care conțin contur negru.
func _casete_pahare(im: Image) -> Array:
	var w := im.get_width()
	var h := im.get_height()
	var jos := mini(BANDA_JOS, h)
	var coloane := []
	for x in w:
		var are := false
		for y in jos:
			if _e_contur(im.get_pixel(x, y)):
				are = true
				break
		coloane.append(are)
	# grupăm coloanele vecine în runde; ignorăm zgârieturile de câțiva pixeli
	var casete := []
	var x0 := -1
	for x in w + 1:
		var are: bool = x < w and coloane[x]
		if are and x0 < 0:
			x0 = x
		elif not are and x0 >= 0:
			if x - x0 >= LAT_MIN:
				casete.append(_caseta_verticala(im, x0, x - 1))
			x0 = -1
	return casete

# Pentru un interval de coloane, găsește și marginile de sus/jos ale conturului.
func _caseta_verticala(im: Image, x0: int, x1: int) -> Rect2i:
	var h := im.get_height()
	var jos := mini(BANDA_JOS, h)
	var y0 := h
	var y1 := -1
	for x in range(x0, x1 + 1):
		for y in jos:
			if _e_contur(im.get_pixel(x, y)):
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	var r := Rect2i(x0 - MARJA, y0 - MARJA, x1 - x0 + 1 + 2 * MARJA, y1 - y0 + 1 + 2 * MARJA)
	return r.intersection(Rect2i(0, 0, im.get_width(), h))

# ---------------------------------------------------------------------------
# Un pahar decupat: luăm caseta și ștergem tot ce se vede din MASĂ în jurul lui. Ștergerea e tot
# un flood fill din marginile casetei — se oprește în conturul negru al paharului, deci albul
# dinăuntru rămâne întreg.
func _decupeaza_pahar(im: Image, caseta: Rect2i) -> Image:
	var p := im.get_region(caseta)
	p.convert(Image.FORMAT_RGBA8)
	_umple_din_margini(p, _nu_e_pahar)
	return p

# Peticul care ia locul unui pahar: rând cu rând, copiat din masa de LÂNGĂ el.
#
# ⚠️ Jumătatea stângă a peticului se ia din stânga paharului, cea dreaptă din dreapta. Prima
# variantă lua o singură fâșie, „cea mai lată" — și alegea marginea mesei, adică a copiat colțul
# rotunjit și ornamentul de acolo în mijlocul tăbliei (se vedea ca niște crestături). Masa e în
# perspectivă: muchia din spate urcă și coboară pe la colțuri, deci petecul TREBUIE luat din
# vecinătatea imediată, singura care are muchia la aceeași înălțime.
#
# Copierea se face în OGLINDĂ pornind de la lipitură (primul pixel copiat e chiar vecinul ei),
# deci nu există sudură vizibilă și nici tipar care se repetă identic.
const DONOR_LAT := 70    # câte coloane de lângă pahar folosim ca sursă

func _petic(im: Image, caseta_pahar: Rect2i, toate: Array) -> void:
	# ⚠️ Peticul urcă până în MARGINEA DE SUS a pozei, nu doar cât ține paharul: deasupra
	# paharelor nu e decât fundal, iar acolo mai rămăseseră câteva puncte albe din desenul lor
	# (un reflex care ieșea din casetă). Rândurile de sus se copiază oricum din fundal, deci
	# ies transparente — vezi explicația de la capul funcției.
	var caseta := Rect2i(caseta_pahar.position.x, 0, caseta_pahar.size.x, caseta_pahar.end.y)
	var st := _donor(im, caseta, toate, -1)
	var dr := _donor(im, caseta, toate, 1)
	if st < 0 and dr < 0:
		return
	var mijloc := caseta.position.x + caseta.size.x / 2
	for y in range(caseta.position.y, caseta.end.y):
		for x in range(caseta.position.x, caseta.end.x):
			var sx := 0
			if (x < mijloc and st >= 0) or dr < 0:
				# cât de adânc în petic suntem, numărat de la lipitura din STÂNGA
				sx = st - _oglinda(x - caseta.position.x)
			else:
				# ...respectiv de la cea din DREAPTA
				sx = dr + _oglinda(caseta.end.x - 1 - x)
			sx = clampi(sx, 0, im.get_width() - 1)
			im.set_pixel(x, y, im.get_pixel(sx, y))

# Indexul dus-întors în fâșia donatoare: 0,1,…,L-1,L-1,…,1,0,0,1,… — fără sudură la capete.
func _oglinda(d: int) -> int:
	var i := absi(d) % (DONOR_LAT * 2)
	return i if i < DONOR_LAT else DONOR_LAT * 2 - 1 - i

# Prima coloană curată de masă în direcția `dir` (-1 = stânga, 1 = dreapta), sau -1 dacă nu există.
func _donor(im: Image, caseta: Rect2i, toate: Array, dir: int) -> int:
	var w := im.get_width()
	var x: int = caseta.position.x - 1 if dir < 0 else caseta.end.x
	while x >= 0 and x < w:
		var liber := true
		for c in toate:
			var r := c as Rect2i
			if x >= r.position.x - 2 and x < r.end.x + 2:
				liber = false
				break
		if liber:
			return x
		x += dir
	return -1

# ---------------------------------------------------------------------------
# Flood fill din margini, identic cu cel din `tool_egt_assets.gd`.
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

func _e_negru(c: Color) -> bool:
	return c.a > 0.5 and c.r < 0.12 and c.g < 0.12 and c.b < 0.12

# Conturul paharelor: negru, dar rămas ÎN poză după ce fundalul a fost șters.
func _e_contur(c: Color) -> bool:
	return c.a > 0.5 and c.r < 0.20 and c.g < 0.20 and c.b < 0.20

# Ce se șterge din caseta paharului: MASA din jurul lui. Flood-ul pleacă din marginile casetei și
# se oprește în două feluri de pixeli — conturul negru al paharului și fundalul deja transparent.
#
# ⚠️ Condiția `a > 0.5` (adică „nu trece prin transparent") nu e de prisos, e chiar miezul: partea
# de sus a paharului iese DEASUPRA mesei, iar acolo silueta nu are contur desenat — o desparte de
# fundal chiar negrul fundalului. După ce fundalul a devenit transparent (pasul 1), un flood care
# ar fi trecut prin transparent ar fi intrat în pahar pe deasupra și l-ar fi golit pe tot. Exact
# asta s-a și întâmplat la prima încercare: ieșise doar conturul, gol pe dinăuntru.
func _nu_e_pahar(c: Color) -> bool:
	return c.a > 0.5 and not _e_contur(c)
