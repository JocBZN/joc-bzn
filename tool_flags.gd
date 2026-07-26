extends SceneTree

# UNEALTĂ (se rulează o singură dată, nu face parte din joc):
# desenează steagurile pixel-art pentru selectorul de limbă și le salvează în `menu/flags/`.
#
#   godot --headless --path <proiect> --script res://tool_flags.gd
#
# 24x16 px, ca să se potrivească cu restul graficii (pixel art, filtru NEAREST).
# Le desenez din cod ca să nu depindem de imagini luate de pe internet (licențe) și ca să
# poată fi regenerate oricând, la altă mărime, schimbând doar W/H.

const W := 24
const H := 16
const OUT := "res://menu/flags"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save("en", _uk())
	_save("zh", _china())
	_save("de", _benzi_orizontale([Color8(0, 0, 0), Color8(221, 0, 0), Color8(255, 206, 0)]))
	_save("es", _spain())
	_save("ru", _benzi_orizontale([Color8(255, 255, 255), Color8(0, 57, 166), Color8(213, 43, 30)]))
	_save("fr", _benzi_verticale([Color8(0, 85, 164), Color8(255, 255, 255), Color8(239, 65, 53)]))
	_save("ja", _japan())
	_save("pl", _benzi_orizontale([Color8(255, 255, 255), Color8(220, 20, 60)]))
	_save("tr", _turkey())
	print("gata: 9 steaguri in ", OUT)
	quit()

func _save(cod: String, img: Image) -> void:
	_contur(img)
	var p := ProjectSettings.globalize_path("%s/%s.png" % [OUT, cod])
	print(cod, " -> ", p, " err=", img.save_png(p))

func _gol(c: Color = Color(0, 0, 0, 0)) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img

# chenar subțire închis, ca steagurile albe (PL, JA) să nu se piardă pe fundalul deschis
func _contur(img: Image) -> void:
	var c := Color8(20, 18, 26)
	for x in W:
		img.set_pixel(x, 0, c)
		img.set_pixel(x, H - 1, c)
	for y in H:
		img.set_pixel(0, y, c)
		img.set_pixel(W - 1, y, c)

func _dreptunghi(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, H)):
		for x in range(maxi(x0, 0), mini(x1, W)):
			img.set_pixel(x, y, c)

func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in H:
		for x in W:
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				img.set_pixel(x, y, c)

# stea în 5 colțuri, aproximată: la 2-3 px arată oricum ca un romb luminos
func _stea(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in H:
		for x in W:
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy)
			if abs(d.x) + abs(d.y) <= r:
				img.set_pixel(x, y, c)

func _benzi_orizontale(culori: Array) -> Image:
	var img := _gol()
	var n := culori.size()
	for i in n:
		var y0 := int(round(float(i) * H / n))
		var y1 := int(round(float(i + 1) * H / n))
		_dreptunghi(img, 0, y0, W, y1, culori[i])
	return img

func _benzi_verticale(culori: Array) -> Image:
	var img := _gol()
	var n := culori.size()
	for i in n:
		var x0 := int(round(float(i) * W / n))
		var x1 := int(round(float(i + 1) * W / n))
		_dreptunghi(img, x0, 0, x1, W, culori[i])
	return img

# Spania: roșu / galben (dublu) / roșu
func _spain() -> Image:
	var img := _gol()
	_dreptunghi(img, 0, 0, W, 4, Color8(170, 21, 27))
	_dreptunghi(img, 0, 4, W, 12, Color8(241, 191, 0))
	_dreptunghi(img, 0, 12, W, H, Color8(170, 21, 27))
	return img

# Japonia: alb cu disc roșu
func _japan() -> Image:
	var img := _gol(Color8(255, 255, 255))
	_disc(img, W * 0.5, H * 0.5, 4.6, Color8(188, 0, 45))
	return img

# China: roșu, o stea mare stânga-sus + patru mici în arc
func _china() -> Image:
	var img := _gol(Color8(222, 41, 16))
	var g := Color8(255, 222, 0)
	_stea(img, 5.5, 6.0, 2.6, g)
	for p in [Vector2(9.5, 2.5), Vector2(11.5, 5.0), Vector2(11.5, 8.0), Vector2(9.5, 10.5)]:
		img.set_pixel(int(p.x), int(p.y), g)
	return img

# Turcia: roșu, semilună (disc alb din care mușcă un disc roșu) + o steluță
func _turkey() -> Image:
	var rosu := Color8(227, 10, 23)
	var img := _gol(rosu)
	_disc(img, 8.6, H * 0.5, 4.7, Color8(255, 255, 255))
	_disc(img, 10.2, H * 0.5, 4.0, rosu)
	_stea(img, 15.5, H * 0.5, 1.9, Color8(255, 255, 255))
	return img

# Marea Britanie: cruce dublă pe albastru (diagonalele albe + roșii, apoi crucea dreaptă)
func _uk() -> Image:
	var albastru := Color8(1, 33, 105)
	var alb := Color8(255, 255, 255)
	var rosu := Color8(200, 16, 46)
	var img := _gol(albastru)
	# diagonalele (Sf. Andrei + Sf. Patrick): grosime dată de distanța până la dreapta
	for y in H:
		for x in W:
			var fx := (x + 0.5) / W
			var fy := (y + 0.5) / H
			var d := minf(absf(fx - fy), absf(fx - (1.0 - fy)))
			if d < 0.115:
				img.set_pixel(x, y, alb)
	for y in H:
		for x in W:
			var fx := (x + 0.5) / W
			var fy := (y + 0.5) / H
			var d := minf(absf(fx - fy), absf(fx - (1.0 - fy)))
			if d < 0.045:
				img.set_pixel(x, y, rosu)
	# crucea Sf. Gheorghe, peste tot restul
	_dreptunghi(img, 0, 5, W, 11, alb)
	_dreptunghi(img, 9, 0, 15, H, alb)
	_dreptunghi(img, 0, 6, W, 10, rosu)
	_dreptunghi(img, 10, 0, 14, H, rosu)
	return img
