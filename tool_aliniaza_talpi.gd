extends Node

# UNEALTĂ (se rulează ca scenă, o dată după ce ai tăiat GIF-urile):
#
#   godot --headless --path <proiect> res://tool_aliniaza_talpi.tscn
#   godot --headless --path <proiect> --import          # OBLIGATORIU după
#
# Aduce toate cadrele unei animații pe 8 direcții pe ACEEAȘI pânză, cu TALPA la aceeași
# înălțime. E altă problemă decât `tool_egaleaza_directii.gd`: acolo o direcție e desenată la
# altă SCARĂ (personajul se micșorează când se întoarce); aici direcțiile sunt la aceeași
# scară, dar sunt AȘEZATE altfel în pânză (sau chiar pe pânze de mărimi diferite), deci
# personajul SALTĂ pe verticală când se întoarce.
#
# De ce se întâmplă: GIF-urile vin desenate câte unul pe direcție. Lui Saratalin, `north` și
# `south` au venit pe 88×88 iar celelalte șase pe 92×92 — iar `AnimatedSprite2D` centrează
# textura, deci distanța de la mijlocul pânzei până la talpă (28…32 px) ajunge direct pe ecran.
# La `scale = 3` sunt 12 px de săltare la fiecare întoarcere.
#
# ⚠️ Aliniem PE DIRECȚIE, nu pe cadru: în interiorul unei direcții, diferența de talpă între
# cadre e legănatul mersului, adică intenția desenatorului. Mutăm toate cele 8 cadre ale unei
# direcții cu ACELAȘI număr de pixeli, deci legănatul rămâne întreg.
#
# ⚠️ Numai mutare, niciun redimensionat: pixelii se copiază unu-la-unu (`blit_rect`), deci nu
# e nevoie nici de alfa premultiplicat, nici de Lanczos. Nimic nu se poate încețoșa.
#
# ⚠️ RE-RULABILĂ: după prima trecere toate pânzele sunt PANZA și toate tălpile la TINTA_TALPA,
# deci a doua rulare calculează deplasare 0 și scrie fișiere identice. Sursa adevărată rămân
# GIF-urile de alături — oricând se poate lua de la capăt cu `tool_taie_gifuri.ps1`.

const FOLDER := "res://harta/nether/Nether Boss/frames"
const PREFIX := "walk"
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const CADRE := 8

# Pânza comună. Trebuie să încapă cea mai mare pânză de intrare PLUS deplasarea; unealta
# verifică și refuză dacă ar tăia din desen.
const PANZA := 96
# Unde stă talpa în pânza nouă. 80 din 96 lasă 15 px sub tălpi (ca în GIF-urile originale) și
# destul deasupra pentru cea mai înaltă siluetă (65 px).
const TINTA_TALPA := 80
# Pragul de alfa la măsurat: 0,5 e muchia pe care o vede ochiul. Cadrele venite din GIF au
# alfa „da/nu", deci pragul nu le mișcă oricum.
const PRAG_ALFA := 0.5


func _ready() -> void:
	var stare := _masoara_tot()
	if stare.is_empty():
		get_tree().quit(1)
		return
	_tabel("ÎNAINTE", stare)

	# Verificăm întâi TOATE deplasările, abia apoi scriem: dacă una singură ar tăia din desen,
	# vrem să ne oprim cu folderul neatins, nu la jumătatea lui.
	var mutari := {}
	for d in DIRECTII:
		var lat: int = stare[d]["panza"]
		var dx := int(round((PANZA - lat) * 0.5))
		var dy: int = TINTA_TALPA - int(stare[d]["talpa"])
		if dx < 0 or dy < 0 or dx + lat > PANZA or dy + lat > PANZA:
			push_error("`%s`: pânza %d cu deplasarea (%d, %d) nu încape în %d — ridică PANZA sau coboară TINTA_TALPA" % [d, lat, dx, dy, PANZA])
			get_tree().quit(1)
			return
		mutari[d] = Vector2i(dx, dy)

	var atinse := 0
	for d in DIRECTII:
		var m: Vector2i = mutari[d]
		if m == Vector2i.ZERO and int(stare[d]["panza"]) == PANZA:
			print("  %-12s deja aliniat" % d)
			continue
		for i in CADRE:
			_muta(d, i, m)
		atinse += CADRE
		print("  %-12s pânză %d → %d, mutat cu (%+d, %+d)" % [d, int(stare[d]["panza"]), PANZA, m.x, m.y])

	print("")
	_tabel("DUPĂ", _masoara_tot())
	print("")
	if atinse == 0:
		print("nimic de făcut — cadrele erau deja aliniate.")
	else:
		print("%d cadre rescrise. RULEAZĂ ACUM: godot --headless --path . --import" % atinse)
	get_tree().quit()


func _cale(d: String, i: int) -> String:
	return "%s/%s_%s_%d.png" % [FOLDER, PREFIX, d, i]


# ⚠️ `Image.load_from_file`, NU `load()`: `load()` întoarce textura IMPORTATĂ, adică pe cea
# veche, iar tabelul „DUPĂ" ar ieși identic cu „ÎNAINTE" chiar dacă discul s-a schimbat.
# (Aceeași capcană ca în `tool_egaleaza_directii.gd`.)
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


# Pentru fiecare direcție: pânza (toate cadrele ei o au pe aceeași) și TALPA, adică cel mai de
# jos rând opac din toate cele 8 cadre. Talpa e măsura care contează: acolo atinge pământul.
func _masoara_tot() -> Dictionary:
	var iesire := {}
	for d in DIRECTII:
		var talpa := 0
		var panza := -1
		var inalt := 0
		for i in CADRE:
			var img := _img(d, i)
			if img == null:
				push_error("lipsește %s" % _cale(d, i))
				return {}
			if panza < 0:
				panza = img.get_width()
			elif panza != img.get_width():
				push_error("`%s`: cadrele nu-s toate pe aceeași pânză (%d vs %d)" % [d, panza, img.get_width()])
				return {}
			var r := _contur(img)
			talpa = maxi(talpa, r.position.y + r.size.y)
			inalt = maxi(inalt, r.size.y)
		iesire[d] = {"panza": panza, "talpa": talpa, "inalt": inalt}
	return iesire


func _tabel(titlu: String, stare: Dictionary) -> void:
	print("--- %s ---" % titlu)
	print("  %-12s %5s %6s %7s %8s" % ["direcție", "pânză", "talpă", "siluetă", "centru→talpă"])
	for d in DIRECTII:
		var s: Dictionary = stare[d]
		# „centru→talpă" e ce ajunge pe ecran: `AnimatedSprite2D` centrează textura, deci
		# distanța de la mijlocul pânzei până la tălpi e exact cât stă personajul sub punctul
		# lui de poziție. Dacă numărul ăsta diferă între direcții, personajul saltă.
		var fata := float(s["talpa"]) - float(s["panza"]) * 0.5
		print("  %-12s %5d %6d %7d %8.1f" % [d, int(s["panza"]), int(s["talpa"]), int(s["inalt"]), fata])


# Copiere unu-la-unu într-o pânză nouă, goală. `blit_rect` înlocuiește pixelii (nu-i amestecă),
# iar fondul e transparent curat, deci nu apare niciun franjur.
func _muta(d: String, i: int, m: Vector2i) -> void:
	var img := _img(d, i)
	var pat := Image.create_empty(PANZA, PANZA, false, Image.FORMAT_RGBA8)
	pat.fill(Color(0.0, 0.0, 0.0, 0.0))
	img.convert(Image.FORMAT_RGBA8)
	pat.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), m)
	pat.save_png(ProjectSettings.globalize_path(_cale(d, i)))
