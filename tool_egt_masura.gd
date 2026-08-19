extends Node

# RIGLA pentru poza mesei de ruletă. Scoate, din `harta/EGT/table.png`, toate cifrele pe care
# `casino.gd` și `casino_roata.gd` le au scrise ca niște constante:
#
#   · liniile albe ale grilei de pariuri → GRID_X0/X1, GRID_Y0/Y1, ZERO_RECT, DOZ_*, OUT_*, COL2_*
#   · centrul și raza roții                → WHEEL_CENTER, WHEEL_R
#   · unghiul și culoarea fiecărui buzunar → tabelul BUZUNARE din `casino_roata.gd`
#   · rândul de jetoane de jos             → CHIP_CROP din `tool_egt_assets.gd`
#
# Rulează:  godot --headless --path <proiect> res://tool_egt_masura.tscn
#
# DE CE există: masa e desenată de mână, deci NIMIC nu cade la distanțe egale — buzunarele au
# între 11,3° și 14,2°, iar coloanele grilei diferă cu până la 3 px între ele. Cifrele ghicite
# „din ochi" sau împărțite egal se văd: jetonul cade lângă căsuță, bila se oprește pe muchia
# dintre două buzunare. Când Răzvan schimbă poza, rulezi asta și rescrii constantele din raport.
#
# ⚠️ Raportul e pentru OM: nu scrie nimic în cod. Constantele se trec cu mâna, ca să treacă și
# printr-o pereche de ochi (o poză nouă poate să aibă, de exemplu, alt număr de buzunare).

const SRC := "res://harta/EGT/table.png"

var img: Image

func _ready() -> void:
	img = Image.load_from_file(ProjectSettings.globalize_path(SRC))
	print("poza: ", img.get_size(), "   partea folosită: ", img.get_used_rect())
	print("")
	print("=== GRILA (linii albe) ===")
	print("coloane, în grila numerelor:      ", _coloane(285, 540, 120))
	print("coloane, pe rândul duzinilor:     ", _coloane(550, 615, 40))
	print("coloane, pe rândul de jos:        ", _coloane(625, 700, 40))
	print("rânduri, în grilă (x 660..1470):  ", _randuri(660, 1470, 300, 0, 0))
	print("→ GRID_X0/X1 și GRID_Y0/Y1 se scot POTRIVIND o dreaptă pe toate liniile (cea mai bună")
	print("  împărțire în 12, respectiv 3), nu luând prima și ultima linie.")
	print("")
	var c := _centrul_rotii()
	print("=== ROATA ===")
	print("WHEEL_CENTER = ", c, "   raza ramei de aur = %.1f" % _raza_medie(c))
	print("profil radial (câte 2 px, R=roșu N=negru V=verde G=aur L=lemn):")
	var prof := ""
	for r in range(0, 180, 2):
		prof += _dominant(c, float(r))
	print("  ", prof)
	print("")
	print("=== BUZUNARELE (pentru tabelul BUZUNARE din casino_roata.gd) ===")
	_buzunare(c)
	print("")
	print("=== RÂNDUL DE JETOANE DE JOS (pentru CHIP_CROP) ===")
	print("coloane: ", _jetoane_coloane())
	print("rânduri: ", _jetoane_randuri())
	get_tree().quit()

# ---------------------------------------------------------------------------
# LINIILE ALBE
# ---------------------------------------------------------------------------
func _coloane(y0: int, y1: int, prag: int) -> String:
	var a := PackedInt32Array()
	a.resize(img.get_width())
	for y in range(y0, y1):
		for x in img.get_width():
			if _e_alb(img.get_pixel(x, y)):
				a[x] += 1
	return _grupe(a, prag)

func _randuri(x0: int, x1: int, prag: int, y0: int, y1: int) -> String:
	if y1 == 0:
		y1 = img.get_height()
	var a := PackedInt32Array()
	a.resize(img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			if _e_alb(img.get_pixel(x, y)):
				a[y] += 1
	return _grupe(a, prag)

# Șiruri de valori peste prag, scrise ca „de la-până la" (o linie albă are 3–6 px grosime).
func _grupe(a: PackedInt32Array, prag: int) -> String:
	var s := ""
	var start := -1
	for i in a.size():
		if a[i] > prag:
			if start < 0:
				start = i
		elif start >= 0:
			s += "%d-%d " % [start, i - 1]
			start = -1
	if start >= 0:
		s += "%d-%d " % [start, a.size() - 1]
	return s

# ---------------------------------------------------------------------------
# ROATA
# ---------------------------------------------------------------------------
# Centrul NU se ia din dreptunghiul în care încape aurul: rama are pete de umbră care trag
# dreptunghiul într-o parte. Se caută punctul care face RAZA ramei cât mai constantă pe toate
# cele 360 de direcții — adică exact ce înseamnă „centrul unui cerc".
func _centrul_rotii() -> Vector2:
	var pornire := _bbox_aur()
	var best := pornire
	var best_var := 1e20
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var cand := pornire + Vector2(dx, dy)
			var raze := _raze(cand)
			if raze.size() < 300:
				continue
			var m := 0.0
			for r in raze:
				m += r
			m /= raze.size()
			var v := 0.0
			for r in raze:
				v += (r - m) * (r - m)
			v /= raze.size()
			if v < best_var:
				best_var = v
				best = cand
	return best

func _bbox_aur() -> Vector2:
	var minx := 99999
	var maxx := -1
	var miny := 99999
	var maxy := -1
	for y in range(400, img.get_height()):
		for x in range(0, 640):
			if _e_aur(img.get_pixel(x, y)):
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	return Vector2(minx + maxx, miny + maxy) * 0.5

# Pentru fiecare unghi, cea mai depărtată rază la care mai e aur = marginea de afară a ramei.
func _raze(c: Vector2) -> Array:
	var out := []
	for i in 360:
		var d := Vector2.from_angle(TAU * i / 360.0)
		var ultim := -1.0
		for r in range(150, 185):
			var p := c + d * float(r)
			if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
				break
			if _e_aur(img.get_pixelv(Vector2i(p))):
				ultim = float(r)
		if ultim > 0:
			out.append(ultim)
	return out

func _raza_medie(c: Vector2) -> float:
	var raze := _raze(c)
	var s := 0.0
	for r in raze:
		s += r
	return s / maxf(1.0, float(raze.size()))

func _dominant(c: Vector2, r: float) -> String:
	var cnt := {}
	for i in 720:
		var p := c + Vector2.from_angle(TAU * i / 720.0) * r
		if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
			continue
		var k := _cat(img.get_pixelv(Vector2i(p)))
		cnt[k] = int(cnt.get(k, 0)) + 1
	var bk := "?"
	var bv := -1
	for k in cnt:
		if cnt[k] > bv:
			bv = cnt[k]
			bk = k
	return bk

# Buzunarele: la fiecare optime de grad se ia culoarea care domină pe grosimea inelului de
# afară (razele 128–160), apoi se taie în segmente. Aurul despărțitorilor se sare — el e
# granița, nu buzunarul.
func _buzunare(c: Vector2) -> void:
	var N := 2880
	var cat := []
	for i in N:
		var d := Vector2.from_angle(TAU * i / N)
		var nr := {"R": 0, "N": 0, "V": 0, "G": 0, "L": 0, "?": 0}
		for r in range(128, 160):
			nr[_cat(img.get_pixelv(Vector2i(c + d * float(r))))] += 1
		var b := "?"
		var bv := -1
		for k in nr:
			if nr[k] > bv:
				bv = nr[k]
				b = k
		cat.append(b)
	var i0 := 0
	while i0 < N and cat[i0] == cat[N - 1]:
		i0 += 1
	var seg := []
	var cur := ""
	var start := 0
	for j in N:
		var i := (i0 + j) % N
		var k: String = cat[i]
		if k == "G" or k == "L" or k == "?":
			continue
		if k != cur:
			if cur != "":
				seg.append([cur, start, i])
			cur = k
			start = i
	if cur != "":
		seg.append([cur, start, (i0 + N) % N])
	var nume := {"R": "RED", "N": "BLACK", "V": "GREEN"}
	var linie := ""
	for s in seg:
		var a0: float = float(s[1]) / N * 360.0
		var a1: float = float(s[2]) / N * 360.0
		if a1 < a0:
			a1 += 360.0
		linie += "[%.2f, \"%s\"], " % [fmod((a0 + a1) * 0.5, 360.0), nume[s[0]]]
	print("buzunare găsite: ", seg.size())
	print(linie)
	print("⚠️ Verifică numărul ȘI lățimile: dacă apar segmente mult mai înguste decât restul,")
	print("   alea sunt marginile desenate ale buzunarului verde, nu buzunare adevărate.")

# ---------------------------------------------------------------------------
# JETOANELE
# ---------------------------------------------------------------------------
func _jetoane_coloane() -> String:
	var a := PackedInt32Array()
	a.resize(img.get_width())
	for y in range(720, 830):
		for x in range(640, 1520):
			if _e_jeton(img.get_pixel(x, y)):
				a[x] += 1
	return _grupe(a, 8)

func _jetoane_randuri() -> String:
	var a := PackedInt32Array()
	a.resize(img.get_height())
	for y in range(700, 860):
		for x in range(890, 1010):
			if _e_jeton(img.get_pixel(x, y)):
				a[y] += 1
	return _grupe(a, 8)

# ---------------------------------------------------------------------------
# CULORI
# ---------------------------------------------------------------------------
func _e_alb(c: Color) -> bool:
	return c.a > 0.5 and c.r > 0.85 and c.g > 0.85 and c.b > 0.85

func _e_aur(c: Color) -> bool:
	return c.a > 0.5 and c.r > 0.70 and c.g > 0.50 and c.b < 0.42 and c.r > c.b * 1.6

# „nu e pânza verde" — jetoanele sunt orice altceva
func _e_jeton(c: Color) -> bool:
	return c.a > 0.5 and not (c.g > c.r * 1.15 and c.g > c.b * 1.15)

func _cat(c: Color) -> String:
	if c.a < 0.5:
		return "?"
	if c.r > 0.52 and c.g < 0.34 and c.b < 0.34:
		return "R"
	if _e_aur(c):
		return "G"
	if c.g > 0.40 and c.r < 0.42 and c.b < 0.48:
		return "V"
	if c.r < 0.26 and c.g < 0.26 and c.b < 0.26:
		return "N"
	return "L"
