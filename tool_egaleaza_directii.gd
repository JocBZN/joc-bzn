extends Node

# UNEALTĂ (se rulează ca scenă, o dată):
#
#   godot --headless --path <proiect> res://tool_egaleaza_directii.tscn
#   godot --headless --path <proiect> --import          # OBLIGATORIU după, altfel Godot ține cadrele vechi
#
# Aduce o direcție de mers la ACEEAȘI scară cu celelalte șapte.
#
# GIF-urile vin desenate câte unul pe direcție, deci fiecare poate ieși la alt zoom. Când se
# întâmplă, personajul se micșorează exact în clipa în care se întoarce în partea aia — iar ochiul
# prinde schimbarea de MĂRIME mult mai repede decât aproape orice altă greșeală de artă, chiar și
# la 4%. La pompier, `south` fusese deja reparat așa pe 2026-08-05 (venise pe pânză de 92×92);
# `north` rămăsese cu 4,3% mai mic și s-a văzut în joc.
#
# ⚠️ CE E MĂSURA BUNĂ: **înălțimea siluetei**, nu lățimea și nu aria. `Idle_rotations_8dir.gif`
# (arbitrul: toate cele 8 poze desenate în aceeași imagine, deci sigur la aceeași scară) spune
# limpede de ce — cele 8 poze au înălțimi 58…60 px, dar lățimi 24…37 și arii 991…1395. Un om are
# aceeași înălțime din orice unghi; lățimea și aria depind de poză (din spate ține brațele strânse
# și nu i se vede pieptul). Cine ar egaliza aria ar umfla spatele cu 18% degeaba.
#
# ⚠️ RE-RULABILĂ: unealta nu are un factor scris de mână, ci îl MĂSOARĂ de fiecare dată. După ce
# repară o dată, direcția e la fel cu celelalte, factorul iese ~1,00 și a doua rulare nu mai face
# nimic. Asta contează fiindcă scrie PESTE cadre — sursa adevărată rămâne GIF-ul de alături, deci
# oricând se poate lua totul de la capăt cu `tool_taie_gifuri.ps1`.

const FOLDER := "res://homeless directii/Firefighter/frames"
const PREFIX := "run"
const CADRE := 6
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const TINTA := "north"

# Sub atâta nu umblăm: 1,5% e sub un pixel de textură și nu s-ar vedea nici cu rigla pe ecran.
const PRAG := 0.015
# Peste atâta refuzăm: un factor de 1,4 nu mai e „o direcție desenată puțin altfel", e altceva
# stricat (altă pânză, alt personaj) și trebuie privit cu ochii înainte să rescriem fișiere.
const PLAFON := 1.30
# Lucrăm la 4×: factorul nu e întreg, deci decupajul cade între pixeli, iar rotunjirea la pixel
# întreg ar muta personajul cu până la o jumătate de pixel de textură — adică unul întreg pe
# ecran, la `scale = 2`. Cu 4× eroarea scade la o optime de pixel.
const SUPRA := 4
# Pragul de alfa la măsurat. `Image.get_used_rect()` numără orice alfa > 0, iar după mărire
# marginile capătă un halou de câteva sutimi — cu el, „DUPĂ" ar ieși mereu cu 1-2 px mai înalt
# decât e de fapt. La 0,5 muchia cade unde pixelul e acoperit pe jumătate — adică exact acolo unde
# o vede ochiul, și la fel pentru cadrele vechi (care au alfa „da/nu", deci pragul nu le mișcă).
const PRAG_ALFA := 0.5


func _ready() -> void:
	var inainte := _masoara_tot()
	if inainte.is_empty():
		get_tree().quit()
		return
	_tabel("ÎNAINTE", inainte)

	var referinta := 0.0
	var cate := 0
	for d in DIRECTII:
		if d == TINTA:
			continue
		referinta += inainte[d]
		cate += 1
	referinta /= float(cate)
	var acum: float = inainte[TINTA]
	var f := referinta / acum
	print("")
	print("referință (media celorlalte %d direcții): %.2f px | `%s`: %.2f px → factor %.4f" % [cate, referinta, TINTA, acum, f])

	if absf(f - 1.0) < PRAG:
		print("sub pragul de %.1f%% — nu e nimic de făcut." % (PRAG * 100.0))
		get_tree().quit()
		return
	if f > PLAFON or f < 1.0 / PLAFON:
		push_error("factor %.3f, în afara plafonului de %.2f — uită-te întâi la cadre, nu le rescrie orbește" % [f, PLAFON])
		get_tree().quit()
		return

	# Talpa: cel mai de jos rând opac din TOATE cadrele direcției. Mărirea se face în jurul ei și
	# în jurul mijlocului pânzei, deci personajul nu se ridică de pe pământ și nu sare lateral când
	# se întoarce — singurul lucru care se schimbă e cât e de mare.
	var talpa := _talpa(TINTA)
	print("mărire în jurul punctului (x=%.1f, y=%.1f): mijlocul pânzei și talpa" % [32.0, talpa])
	for i in CADRE:
		_scaleaza(TINTA, i, f, talpa)

	_tabel("DUPĂ", _masoara_tot())
	print("")
	print("%d cadre rescrise. RULEAZĂ ACUM: godot --headless --path . --import" % CADRE)
	get_tree().quit()


# --- măsurat ------------------------------------------------------------------------------------

func _cale(d: String, i: int) -> String:
	return "%s/%s_%s_%d.png" % [FOLDER, PREFIX, d, i]


# ⚠️ `Image.load_from_file`, NU `load()`: `load()` întoarce textura IMPORTATĂ, adică pe cea veche,
# iar tabelul „DUPĂ" ar ieși identic cu „ÎNAINTE" chiar dacă fișierele de pe disc s-au schimbat.
func _img(d: String, i: int) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(_cale(d, i)))


func _contur(img: Image) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > PRAG_ALFA:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


# Înălțimea medie a siluetei, pe direcție — media pe cadre, fiindcă alergarea are un salt și
# un singur cadru n-ar spune nimic.
func _masoara_tot() -> Dictionary:
	var iesire := {}
	for d in DIRECTII:
		var h := 0.0
		for i in CADRE:
			var img := _img(d, i)
			if img == null:
				push_error("lipsește %s" % _cale(d, i))
				return {}
			h += float(_contur(img).size.y)
		iesire[d] = h / float(CADRE)
	return iesire


func _talpa(d: String) -> float:
	var jos := 0
	for i in CADRE:
		var r := _contur(_img(d, i))
		jos = maxi(jos, r.position.y + r.size.y)
	return float(jos)


func _tabel(titlu: String, h: Dictionary) -> void:
	print("--- înălțimea siluetei, %s ---" % titlu)
	for d in DIRECTII:
		var coada := "   <-- ținta" if d == TINTA else ""
		print("  %-12s %5.2f px%s" % [d, h[d], coada])


# --- mărit --------------------------------------------------------------------------------------

# ⚠️ ALFA PREMULTIPLICAT, altfel mărirea lasă franjuri: cadrele vin din GIF, unde transparența e
# „da/nu", iar pixelii invizibili păstrează sub ei o culoare oarecare. Orice filtru care amestecă
# vecini ar trage culoarea aia în marginea personajului. Înmulțind culoarea cu alfa înainte,
# pixelii invizibili devin curat 0 și n-au ce murdări; la final împărțim la loc.
func _premultiplica(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a))


func _dezpremultiplica(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var a := clampf(c.a, 0.0, 1.0)
			if a <= 0.004:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			# Lanczos poate sări peste 1 sau sub 0 la muchii tari; tăiem înapoi în interval.
			img.set_pixel(x, y, Color(clampf(c.r / a, 0.0, 1.0), clampf(c.g / a, 0.0, 1.0), clampf(c.b / a, 0.0, 1.0), a))


func _scaleaza(d: String, i: int, f: float, talpa: float) -> void:
	var img := _img(d, i)
	var lat := img.get_width()
	img.convert(Image.FORMAT_RGBAF)
	_premultiplica(img)

	var w := lat * SUPRA
	img.resize(w, w, Image.INTERPOLATE_LANCZOS)
	var n := int(round(float(w) * f))
	img.resize(n, n, Image.INTERPOLATE_LANCZOS)
	var fe := float(n) / float(w)   # factorul chiar aplicat (n e întreg)

	# Decupăm înapoi o fereastră cât pânza, așezată astfel încât mijlocul (x = jumătate de pânză)
	# și talpa să cadă exact unde erau. `blit_rect` taie singur ce iese din imagine.
	var ox := int(round(0.5 * float(lat) * float(SUPRA) * (fe - 1.0)))
	var oy := int(round(talpa * float(SUPRA) * (fe - 1.0)))
	var pat := Image.create_empty(w, w, false, Image.FORMAT_RGBAF)
	pat.fill(Color(0.0, 0.0, 0.0, 0.0))
	pat.blit_rect(img, Rect2i(ox, oy, w, w), Vector2i(0, 0))

	pat.resize(lat, lat, Image.INTERPOLATE_LANCZOS)
	_dezpremultiplica(pat)
	pat.convert(Image.FORMAT_RGBA8)
	pat.save_png(ProjectSettings.globalize_path(_cale(d, i)))
	print("  %s_%d: ×%.4f (pânză %d→%d), decupat de la (%d, %d)" % [d, i, fe, w, n, ox, oy])
