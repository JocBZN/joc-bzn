extends Node

# UNEALTĂ (se rulează ca scenă, o dată):
#
#   godot --headless --path <proiect> res://tool_taie_atacuri.tscn
#   godot --headless --path <proiect> --import          # OBLIGATORIU după
#
# Taie efectele lui SIR JOHN din foaia `harta/castle/boss/atlas/`, adică din `Attacks.gif` —
# un ATLAS de 9×7 celule de 96×96, fiecare celulă fiind un efect propriu, animat pe cele 4 cadre
# ale GIF-ului. Din 63 de efecte, jocul folosește trei; restul rămân în foaie, pentru mai târziu.
#
# Foaia intră în repo ca 4 PNG-uri (`atlas_0..3.png`), nu ca GIF, exact din motivul pentru care
# `harta/EGT/Roulette Table.png` a rămas și el acolo: unealta trebuie să fie re-rulabilă fără
# PowerShell și fără sursa originală. GIF-ul lui Răzvan stă alături, neatins.
#
# ⚠️ FUNDALUL NU E TRANSPARENT. Foaia e complet opacă, cu un mov închis (31,16,42) pe 70% din
# suprafață. Se scoate prin potrivire EXACTĂ, nu cu prag: culorile vin dintr-o paletă de GIF, deci
# nu există tranziții — un prag ar fi mâncat și albastrul închis din efecte.
#
# ⚠️ ROTAȚIA nu e cosmetică. Cometa (celula 0,1) e desenată zburând spre DREAPTA, cu dâra în urmă;
# atacul o vrea CĂZÂND, deci se rotește 90° în sensul acelor de ceas. Rotită la tăiere, nu din
# `rotation` la rulare: nodul care o folosește (`prison_bolovan.gd`) își rotește și cercul de
# avertizare de pe pământ, iar ăla trebuie să rămână drept.

const ATLAS := "res://harta/castle/boss/atlas/atlas_%d.png"
const CADRE_ATLAS := 4
const CELULA := 96
const IESIRE := "res://harta/castle/boss/%s/"

# Ce tăiem. `celule` merge la pas cu cadrele de ieșire: o celulă înseamnă cele 4 cadre ale ei,
# iar două celule una după alta înseamnă 4 cadre din prima, apoi 4 din a doua.
# `rot` e în sferturi de tură, în sensul acelor de ceas.
#
# ⚠️ Celulele se scriu ca [RÂND, COLOANĂ], nu ca număr liniar. Prima variantă folosea indici
# liniari, iar eu îi citeam de pe o grilă etichetată „rând-coloană" — au ieșit patru efecte
# complet greșite (un stâlp de flăcări în loc de inel). Perechea nu se poate citi greșit.
const RETETE := [
	# ATACUL 1 — unda care pleacă din el când înfige sabia în lespezi. Celula (0,4) e un cerc SUBȚIRE
	# cu crăpături în el — o pecete, nu un covrig. Prima alegere a fost (4,5), un tor GROS care creștea
	# singur; mărit de opt ori ca să ajungă la raza atacului, ieșea o pată albastră pe jumătate de
	# ecran (văzut pe captură). Un contur subțire rămâne citibil oricât îl mărești, iar creșterea o
	# face acum scara din `prison_inel.gd`, nu desenul.
	{"nume": "atac_inel", "celule": [[0, 4]], "rot": 0},
	# ATACUL 2 — lovitura care cade peste tine. Cometa (0,1) rotită ca să cadă, apoi izbucnirea
	# din pământ (5,8), care are doar DOUĂ cadre desenate — de aia `cate`: ultimele două celule ale
	# ei sunt goale, iar două cadre goale la coada unei animații înseamnă un impact care se termină
	# într-o pauză. Deci 4 + 2, nu 5 + 4 ca la bolovanul de piatră al Warden-ului.
	{"nume": "atac_lovitura", "celule": [[0, 1]], "rot": 1},
	{"nume": "atac_lovitura", "celule": [[5, 8]], "rot": 0, "de_la": 4, "cate": 2},
	# ATACUL 3 — tăietura de sabie, semiluna care zboară. Celula (3,4) se deschide de la o seceră
	# mică la un arc lat, adică exact desenul unei lovituri care se desface. OGLINDITĂ: în foaie
	# burta arcului e la stânga, iar un proiectil trebuie să zboare cu burta ÎNAINTE (0 rad = est,
	# ca la toate celelalte). Neoglindită, tăietura ar fi arătat ca și cum zboară cu spatele.
	{"nume": "atac_taietura", "celule": [[3, 4]], "rot": 0, "oglinda": true},
]


func _ready() -> void:
	var atlas := []
	for f in CADRE_ATLAS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS % f))
		if img == null:
			push_error("lipsește %s" % (ATLAS % f))
			get_tree().quit()
			return
		atlas.append(img)
	var fundal: Color = atlas[0].get_pixel(0, 0)
	print("fundalul scos: ", fundal)
	var d := DirAccess.open(ProjectSettings.globalize_path("res://harta/castle/boss/"))
	for reteta in RETETE:
		var nume: String = reteta["nume"]
		if d != null and not d.dir_exists(nume):
			d.make_dir(nume)
		var de_la: int = reteta.get("de_la", 0)
		var n := de_la
		for celula in reteta["celule"]:
			for f in int(reteta.get("cate", CADRE_ATLAS)):
				var img := _taie(atlas[f], int(celula[0]), int(celula[1]), fundal, int(reteta["rot"]), bool(reteta.get("oglinda", false)))
				var cale := IESIRE % nume + "frame_%d.png" % n
				img.save_png(ProjectSettings.globalize_path(cale))
				_raport(nume, n, img)
				n += 1
	print("")
	print("RULEAZĂ ACUM: godot --headless --path . --import")
	get_tree().quit()


func _taie(sursa: Image, rand: int, coloana: int, fundal: Color, rot: int, oglindit: bool) -> Image:
	var cx := coloana * CELULA
	var cy := rand * CELULA
	var iesire := Image.create_empty(CELULA, CELULA, false, Image.FORMAT_RGBA8)
	iesire.fill(Color(0, 0, 0, 0))
	for y in CELULA:
		for x in CELULA:
			var p := sursa.get_pixel(cx + x, cy + y)
			if p.is_equal_approx(fundal):
				continue
			# rotire în sensul acelor de ceas, de `rot` ori: (x,y) → (lat-1-y, x)
			var nx := x
			var ny := y
			for _i in rot:
				var t := nx
				nx = CELULA - 1 - ny
				ny = t
			if oglindit:
				nx = CELULA - 1 - nx
			iesire.set_pixel(nx, ny, Color(p.r, p.g, p.b, 1.0))
	return iesire


# Cifrele de care au nevoie scripturile atacurilor: conturul opac și, pentru un efect care se
# lărgește, RAZA lui în pixeli de artă (de aia există `RAZA_ARTA` în `prison_inel.gd`). Le
# tipărim ca să nu le mai măsoare nimeni de mână.
func _raport(nume: String, n: int, img: Image) -> void:
	var x0 := CELULA
	var y0 := CELULA
	var x1 := -1
	var y1 := -1
	for y in CELULA:
		for x in CELULA:
			if img.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		print("  %s/frame_%d: GOL" % [nume, n])
		return
	var c := Vector2(CELULA, CELULA) * 0.5
	var raza := maxf(maxf(absf(float(x0) - c.x), absf(float(x1) - c.x)), maxf(absf(float(y0) - c.y), absf(float(y1) - c.y)))
	print("  %s/frame_%d: contur %dx%d @ (%d,%d)  rază_max %.0f  semi-lățime %.0f  semi-înălțime %.0f" \
		% [nume, n, x1 - x0 + 1, y1 - y0 + 1, x0, y0, raza, (x1 - x0 + 1) * 0.5, (y1 - y0 + 1) * 0.5])
