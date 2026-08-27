extends Node

# UNEALTĂ (se rulează ca scenă, o dată):
#
#   godot --headless --path <proiect> res://tool_border_mythic.tscn
#   godot --headless --path <proiect> --import          # OBLIGATORIU după
#
# Taie chenarul de raritate MYTHIC din pachetul `Borders/` și-l pune lângă celelalte cinci, în
# `Upgrades/Menu UI/`. Răzvan a ales planșa: „foloseste imaginea din Borders - 16 Border 01".
#
# Cele 16 planșe din `Borders/` sunt ACEEAȘI planșă în 16 palete (5×4 celule de 64×64, siluetele
# identice pixel cu pixel), deci singura întrebare e CARE celulă. Răspunsul nu se ghicește: unealta
# compară SILUETA (alfa) fiecărei celule cu `Border Legendary.png` și o ia pe cea care se
# potrivește exact. Dacă nu se potrivește niciuna, se oprește fără să scrie nimic.
#
# Tipărește și CULOAREA DOMINANTĂ a fiecărui chenar existent, ca să se vadă că metoda scoate
# exact valorile `Color8` scrise deja în `levelup.gd::RARITIES` — abia apoi are voie să spună ce
# culoare are Mythic. (`levelup.gd` zice: „Culorile sunt luate EXACT din border-urile PNG".)

const PLANSA := "res://Borders/16 Border 01.png"
const MODEL := "res://Upgrades/Menu UI/Border Legendary.png"   # silueta după care căutăm celula
const IESIRE := "res://Upgrades/Menu UI/Border Mythic.png"
const MENU_UI := "res://Upgrades/Menu UI/"
const CELULA := 64
const PRAG_ALFA := 0.5
# ⚠️ Culoarea chenarului NU e pixelul cel mai des întâlnit: ăla e umplutura închisă din mijloc
# (32,30,38), identică la toate cinci. Deci sărim peste tot ce e mai întunecat decât `PRAG_V` și
# abia apoi numărăm — așa metoda scoate exact valorile deja scrise în `levelup.gd`.
const PRAG_V := 0.25

const EXISTENTE := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]


func _ready() -> void:
	var model := _img(MODEL)
	var plansa := _img(PLANSA)
	if model == null or plansa == null:
		push_error("lipsește planșa sau modelul")
		get_tree().quit(1)
		return

	var gasit := Vector2i(-1, -1)
	for ry in int(plansa.get_height() / CELULA):
		for rx in int(plansa.get_width() / CELULA):
			var cel := Image.create_empty(CELULA, CELULA, false, Image.FORMAT_RGBA8)
			cel.blit_rect(plansa, Rect2i(rx * CELULA, ry * CELULA, CELULA, CELULA), Vector2i.ZERO)
			if _aceeasi_silueta(cel, model):
				gasit = Vector2i(rx, ry)
				break
		if gasit.x >= 0:
			break
	if gasit.x < 0:
		push_error("nicio celulă din %s n-are silueta lui %s — uită-te cu ochii înainte să scrii ceva" % [PLANSA, MODEL])
		get_tree().quit(1)
		return
	print("celula găsită: (%d, %d) din %s" % [gasit.x, gasit.y, PLANSA])

	print("")
	print("--- culoarea dominantă (pixelul opac cel mai des întâlnit) ---")
	for n in EXISTENTE:
		var c := _dominanta(_img(MENU_UI + "Border %s.png" % n))
		print("  %-12s Color8(%d, %d, %d)" % [n, round(c.r * 255.0), round(c.g * 255.0), round(c.b * 255.0)])

	var iesire := Image.create_empty(CELULA, CELULA, false, Image.FORMAT_RGBA8)
	iesire.blit_rect(plansa, Rect2i(gasit.x * CELULA, gasit.y * CELULA, CELULA, CELULA), Vector2i.ZERO)
	iesire.save_png(ProjectSettings.globalize_path(IESIRE))
	var cm := _dominanta(iesire)
	print("  %-12s Color8(%d, %d, %d)   <-- pune-o în RARITIES" % ["Mythic", round(cm.r * 255.0), round(cm.g * 255.0), round(cm.b * 255.0)])
	print("")
	print("scris %s. RULEAZĂ ACUM: godot --headless --path . --import" % IESIRE)
	get_tree().quit()


func _img(cale: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(cale))


# Doar alfa, nu culoarea: planșele sunt aceeași imagine în palete diferite, deci silueta e
# singurul lucru pe care are voie să-l compare.
func _aceeasi_silueta(a: Image, b: Image) -> bool:
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return false
	for y in a.get_height():
		for x in a.get_width():
			if (a.get_pixel(x, y).a > PRAG_ALFA) != (b.get_pixel(x, y).a > PRAG_ALFA):
				return false
	return true


func _dominanta(img: Image) -> Color:
	var cate := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= PRAG_ALFA or c.v <= PRAG_V:
				continue
			var k := "%d,%d,%d" % [round(c.r * 255.0), round(c.g * 255.0), round(c.b * 255.0)]
			cate[k] = cate.get(k, 0) + 1
	var cel_mai := ""
	var maxim := 0
	for k in cate:
		if cate[k] > maxim:
			maxim = cate[k]
			cel_mai = k
	if cel_mai == "":
		return Color(0, 0, 0)
	var p := cel_mai.split(",")
	return Color8(int(p[0]), int(p[1]), int(p[2]))
