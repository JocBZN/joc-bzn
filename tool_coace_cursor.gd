extends Node

# UNEALTĂ: COACE CADRELE CURSORULUI (2026-09-26). Nu face parte din joc.
#
# Din mâna desenată de Răzvan (`menu/Mouse.png`, dreaptă) scoate `menu/Mouse_anim.png`: o bandă
# de cadre cu mâna ÎNCLINATĂ spre stânga și apăsarea de clic (se strânge, se apleacă, se
# întunecă puțin, apoi sare înapoi cu un mic „resort"). `gamepad.gd` doar taie banda în bucăți.
#
# De ce coaptă și nu rotită în joc: o rotire de pixel art cu „cel mai apropiat pixel" iese
# zimțată, iar una cu interpolare iese cețoasă. Aici e metoda RotSprite: poza se mărește de 8 ori
# cu Scale2x (EPX) — care rotunjește diagonalele în loc să facă scări — și abia apoi se rotește și
# se eșantionează înapoi la mărimea de pixel. Costă ~1 s, prea mult pentru pornirea jocului.
#
# 🔑 VÂRFUL degetului e ancora: toate cadrele se rotesc și se micșorează în jurul lui, iar el
# cade pe ACELAȘI pixel în fiecare cadru. Altfel clicul ar „tremura" cu animația.
#
# Rulare: godot --headless --path . res://tool_coace_cursor.tscn, apoi `--headless --import`.
# Tipărește VARF-ul și mărimea cadrului — trebuie să bată cu constantele din `gamepad.gd`.

const SURSA := "res://menu/Mouse.png"
const IESIRE := "res://menu/Mouse_anim.png"
# Vârful arătătorului în poza dreaptă: degetul ocupă x=15..18 pe primul rând plin (y=1), deci
# mijlocul lui e x=17, iar muchia de sus y=1.
const VARF_SURSA := Vector2(17.0, 1.0)

# [unghi în grade (minus = spre stânga), mărime, lumină]. Ordinea e cea din `gamepad.gd`.
const CADRE := [
	[-15.0, 1.00, 1.00],   # 0 repaus
	[-16.5, 0.95, 0.95],   # 1 apasă
	[-18.0, 0.90, 0.90],   # 2 apasă
	[-18.5, 0.87, 0.86],   # 3 ȚINUT (stă aici cât ții butonul)
	[-14.0, 1.05, 1.04],   # 4 dă drumul: sare puțin peste (resortul)
	[-15.5, 0.99, 1.00],   # 5 se așază
]

const PANZA := 128                     # pânză de lucru, destul de mare pentru orice cadru
const VARF_PANZA := Vector2(40.0, 8.0) # unde stă vârful pe pânza de lucru

func _ready() -> void:
	var src: Image = load(SURSA).get_image()
	src.convert(Image.FORMAT_RGBA8)
	var mare := _epx(_epx(_epx(_curata(src))))   # 8x
	print("sursa %dx%d -> %dx%d" % [src.get_width(), src.get_height(), mare.get_width(), mare.get_height()])

	var panze: Array[Image] = []
	var cutie := Rect2i()
	for c in CADRE:
		var p := _roteste(mare, deg_to_rad(c[0]), c[1], c[2])
		panze.append(p)
		var u := p.get_used_rect()
		cutie = u if cutie.size == Vector2i.ZERO else cutie.merge(u)
	cutie = cutie.grow(1)   # un pixel de aer, ca umbra/marginea să nu atingă muchia

	var w := cutie.size.x
	var h := cutie.size.y
	var banda := Image.create(w * CADRE.size(), h, false, Image.FORMAT_RGBA8)
	for i in panze.size():
		banda.blit_rect(panze[i], cutie, Vector2i(i * w, 0))
	banda.save_png(ProjectSettings.globalize_path(IESIRE))
	var varf := Vector2i(VARF_PANZA) - cutie.position
	print("CADRU %dx%d, %d cadre" % [w, h, CADRE.size()])
	print("VARF %s" % varf)
	for i in panze.size():
		var a := banda.get_pixel(i * w + varf.x, varf.y + 1).a
		print("  cadrul %d: alfa sub vârf = %.2f" % [i, a])
	get_tree().quit()

# Pixelii complet transparenți au culori „ascunse" diferite; EPX compară culori exact, deci
# fără asta ar vedea muchii acolo unde nu e nimic.
func _curata(img: Image) -> Image:
	var o := img.duplicate()
	for y in o.get_height():
		for x in o.get_width():
			if o.get_pixel(x, y).a < 0.5:
				o.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var c: Color = o.get_pixel(x, y)
				c.a = 1.0
				o.set_pixel(x, y, c)
	return o

func _px(img: Image, x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)

# Scale2x / EPX: fiecare pixel devine 2x2, iar colțurile iau culoarea vecinilor când două laturi
# se potrivesc — o treaptă de diagonală devine o pantă netedă.
func _epx(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var o := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := img.get_pixel(x, y)
			var a := _px(img, x, y - 1)
			var b := _px(img, x + 1, y)
			var c := _px(img, x - 1, y)
			var d := _px(img, x, y + 1)
			o.set_pixel(2 * x, 2 * y, a if (c == a and c != d and a != b) else p)
			o.set_pixel(2 * x + 1, 2 * y, b if (a == b and a != c and b != d) else p)
			o.set_pixel(2 * x, 2 * y + 1, c if (d == c and d != b and c != a) else p)
			o.set_pixel(2 * x + 1, 2 * y + 1, d if (b == d and b != a and d != c) else p)
	return o

# Fiecare pixel al pânzei se întreabă „de unde din poza mare vin?" (rotire inversă, în jurul
# vârfului) și ia pixelul de acolo, fără amestec — rămâne pixel art curat.
func _roteste(mare: Image, unghi: float, marime: float, lumina: float) -> Image:
	var o := Image.create(PANZA, PANZA, false, Image.FORMAT_RGBA8)
	var zoom := float(mare.get_width()) / 48.0
	var cs := cos(-unghi)
	var sn := sin(-unghi)
	for y in PANZA:
		for x in PANZA:
			var d := (Vector2(x + 0.5, y + 0.5) - VARF_PANZA) / marime
			var s := VARF_SURSA + Vector2(d.x * cs - d.y * sn, d.x * sn + d.y * cs)
			var mx := int(floor(s.x * zoom))
			var my := int(floor(s.y * zoom))
			var c := _px(mare, mx, my)
			if c.a > 0.0:
				o.set_pixel(x, y, Color(c.r * lumina, c.g * lumina, c.b * lumina, 1.0))
	return o
