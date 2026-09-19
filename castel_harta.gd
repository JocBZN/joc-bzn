extends Node2D

# HARTA CASTELULUI LUI SIR JOHN — singura hartă FĂCUTĂ DE MÂNĂ din joc (cerută pe 2026-09-18:
# „fă dimensiunea lui Sir John predeterminată, să arate ca un castel, puțin mai mică decât acum,
# tot open space"). Toate celelalte locuri (lumea, Nether, Ender, Limbo) sunt generate la
# infinit; aici fiecare zid, turn, butoi și ladă stă la locul lui, identic la fiecare intrare.
#
# ⚠️ REVIZUITĂ în aceeași zi, la cererea lui Răzvan: „vreau podeaua să fie aia de dinainte, nu să
# folosești de la Textura; vreau să nu fie deloc statui, doar Barrels și Crates băgate". Deci:
#   • PODEAUA e cea veche, `castle_bg.png`, desenată de shaderul din `ground.gd::set_prison` — harta
#     nu mai pune pavaj, iarbă sau poteci peste ea;
#   • DECORUL e numai butoaie și lăzi. Fără statui, coloane, morminte, fântână, copaci, bănci.
#   • Zidurile, turnurile, scara și arcadele cu uși au rămas: ele fac din curte un castel.
#
# O construiește `prison.gd::enter()` în `World`, centrată pe POARTA prin care ai intrat (deci
# poarta e mereu în mijlocul curții), și o șterge la ieșire. Cât ești în Limbo e doar ascunsă.
#
# Arta zidurilor și a lăzilor: `harta/castle/Castel Textura/` (setul Cainos „Top Down Basic"), pe
# dale de 32 px, pusă aici la SCARA 2 — omulețul din set (21×48 px) iese ~96 px, cât personajele
# noastre (polițistul are 87). `TEXTURE_FILTER_NEAREST` pe tot: pixel art crocant.
#
# 🔑 Cum se citește curtea (convenția setului): e o GROAPĂ privită de sus, din față. Zidul de NORD
# își arată fața de cărămidă (se uită spre tine), cele de est/vest/sud se văd doar ca o buză
# subțire de piatră. Dincolo de ziduri podeaua se stinge spre negru (`castel_intuneric.gd`).
#
# Curtea: pătrat de 78×78 dale de 64 px (4992 px); discul vechi avea raza 3000, deci ~12% mai
# mică. Șase turnuri (4 în colțuri, 2 la mijlocul zidurilor laterale), scara în zidul de nord.
#
# Marginea (unde se oprește player-ul) o dă `rect_joc()`, citit de `prison.gd` și dat lui
# `ground.gd::set_margine_dreptunghi`. Tot acolo se uită și spawner-ul, deci inamicii nu se nasc
# în ziduri.

const S := 2.0                  # scara artei (px de lume pe px de textură)
const T := 64.0                 # o dală în lume (32 px de textură × S)
const N := 39                   # jumătate din latura curții, în dale
const FATA_ZID := 136.0         # înălțimea feței zidului de nord, px de textură (46 + 18×5) — ~4 oameni
const STRAJA := 6               # câte dale de podea se mai văd dincolo de ziduri
const STINGERE := 5             # pe câte dale se stinge podeaua de acolo spre negru
const SEMINTA := 0x5143         # „SJ" — aceeași sămânță = aceleași lăzi și butoaie la fiecare intrare

const DIR := "res://harta/castle/Castel Textura/"

# --- bucăți din atlase (px de textură) ---
const LESPEDE_NIT := Rect2(160, 0, 96, 96)      # lespezi cu nituri: acoperișul turnurilor (Stone Ground)

const ZID_FATA := Rect2(32, 192, 128, 64)       # fața zidului: creneluri 27 px, rânduri de 18, soclu 19
const FEREASTRA := Rect2(196, 214, 24, 24)
const BUZA_V_ST := Rect2(288, 32, 10, 96)
const BUZA_V_DR := Rect2(344, 32, 8, 96)
const BUZA_O := Rect2(384, 32, 96, 8)
const TURN_SUS := Rect2(32, 32, 96, 64)         # parapetul turnului (gol la mijloc)
const TURN_CAP := Rect2(32, 96, 96, 18)
const ZID_FARA_CAP := Rect2(32, 210, 128, 46)   # fața zidului fără creneluri (sub capacul turnului)

const SCARA := Rect2(32, 32, 64, 96)            # Struct
const ARCADA := Rect2(408, 27, 80, 64)
const USA := Rect2(29, 103, 37, 50)             # din atlasul FĂRĂ umbră (stă într-o arcadă)

# Singurul decor: lăzi și butoaie — fiecare e o SCENĂ, nu cod (varianta „with Shadow", cu umbra
# deja desenată). Sunt scene tocmai ca să poți regla HITBOX-ul DE MÂNĂ, în editor, exact ca la
# monument, tufă, EGT sau albă: deschizi `castel_lada.tscn` / `castel_butoi.tscn`, apuci
# `CollisionShape2D` cu mouse-ul în viewport și-l tragi peste desen până stă bine. Ce vezi acolo e
# fix ce blochează în joc — nu mai există nicio cifră de hitbox în fișierul ăsta.
# Din scene vine și bucata de atlas desenată (`region_rect`), și scara ×2, deci și arta se schimbă
# de acolo. Desenul, ca reper: lada ~78×92 px de lume, butoiul ~62×72; cutiile pornesc de la 44×20,
# așezate cu marginea de jos pe baza desenului.
const LADA_SCENA := preload("res://castel_lada.tscn")
const BUTOI_SCENA := preload("res://castel_butoi.tscn")

var _tx_piatra: Texture2D
var _tx_zid: Texture2D
var _tx_struct: Texture2D
var _tx_props_curat: Texture2D

var _plat: Node2D              # tot ce e lipit de pământ (ziduri, buze, întuneric), sub personaje
var _rng := RandomNumberGenerator.new()

# Unde are voie player-ul, în coordonate de LUME. Zidul de nord oprește la baza feței, celelalte
# la buză; câțiva pixeli de joc ca picioarele să nu intre în piatră.
func rect_joc() -> Rect2:
	var a := global_position + Vector2(-N * T + 20.0, -N * T + 14.0)
	var b := global_position + Vector2(N * T - 20.0, N * T - 10.0)
	return Rect2(a, b - a)

func construieste() -> void:
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = SEMINTA
	_tx_piatra = load(DIR + "TX Tileset Stone Ground.png")
	_tx_zid = load(DIR + "TX Tileset Wall.png")
	_tx_struct = load(DIR + "TX Struct.png")
	_tx_props_curat = load(DIR + "TX Props.png")

	_plat = Node2D.new()
	_plat.name = "Pamant"
	_plat.z_index = -9           # peste podeaua shaderului (-10), sub tot ce se sortează pe Y
	add_child(_plat)

	_intuneric()
	_ziduri()
	_turnuri()
	_lazi_si_butoaie()

# Negrul de dincolo de ziduri: podeaua se mai vede câteva dale, apoi se stinge, apoi negru plin
# (ca groapa din Nether/Ender, doar că pătrată — e o cetate, nu o insulă).
func _intuneric() -> void:
	var fata := FATA_ZID * S
	var r := Rect2(-N * T - STRAJA * T, -N * T - fata - STRAJA * T,
		2 * N * T + 2 * STRAJA * T, 2 * N * T + fata + 2 * STRAJA * T)
	var n := Node2D.new()
	n.set_script(preload("res://castel_intuneric.gd"))
	n.set("interior", r.grow(-STINGERE * T))
	n.set("exterior", r)
	_plat.add_child(n)

# ---------- zidurile ----------
func _ziduri() -> void:
	var fata := FATA_ZID * S
	var sus := -N * T - fata
	# Fața zidului de nord: creneluri 27 px, rânduri de cărămidă de 18 px repetate, soclu 19 px.
	_np(_plat, _tx_zid, ZID_FATA, Rect2(-N * T, sus, 2 * N * T, fata), [0, 27, 0, 19])
	# Buza de sus a zidului (spre drumul de strajă).
	_np(_plat, _tx_zid, BUZA_O, Rect2(-N * T, sus - 8 * S, 2 * N * T, 8 * S))
	# Ferestre de-a lungul zidului, din 4 în 4 dale, ocolind scara, arcadele și turnurile.
	for i in range(-30, 31, 4):
		if absi(i) <= 3 or absi(absi(i) - 13) <= 2:
			continue
		_bucata(_plat, _tx_zid, FEREASTRA, Vector2(i * T - 12 * S, sus + (FATA_ZID * 0.5 - 8) * S), false)
	# Buzele laterale și cea de jos: groapa curții văzută de sus.
	_np(_plat, _tx_zid, BUZA_V_ST, Rect2(-N * T - 10 * S, sus - 8 * S, 10 * S, 2 * N * T + fata + 8 * S))
	_np(_plat, _tx_zid, BUZA_V_DR, Rect2(N * T, sus - 8 * S, 8 * S, 2 * N * T + fata + 8 * S))
	_np(_plat, _tx_zid, BUZA_O, Rect2(-N * T - 10 * S, N * T, 2 * N * T + 18 * S, 8 * S))

	# Scara din mijlocul zidului de nord: urcă pe drumul de strajă (decor — nu se urcă). Treptele
	# din mijloc se repetă, ca scara să ajungă exact până sus, oricât de înalt ar fi zidul.
	_np(_plat, _tx_struct, SCARA, Rect2(-SCARA.size.x * S * 0.5, sus, SCARA.size.x * S, fata), [0, 12, 0, 12])
	# Două arcade cu uși de lemn, simetrice.
	for x in [-13.0, 13.0]:
		var p := Vector2(x * T - ARCADA.size.x * S * 0.5, -N * T - ARCADA.size.y * S)
		var gol := ColorRect.new()
		gol.color = Color(0.05, 0.04, 0.05)
		gol.position = p + Vector2(20, 34) * S
		gol.size = Vector2(40, 30) * S
		gol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plat.add_child(gol)
		var usa := _bucata(_plat, _tx_props_curat, USA, p + Vector2(22, 18) * S, false)
		usa.scale = Vector2(S * 0.97, S * 0.92)
		_bucata(_plat, _tx_struct, ARCADA, p, false)

# ---------- turnurile ----------
func _turnuri() -> void:
	# Colțurile de nord: turnuri mari care ies 6 dale în curte.
	_turn(Vector2(-N + 3.5, -N + 6), 7, 6, 154.0, Rect2(-N * T, -N * T, 7 * T, 6 * T))
	_turn(Vector2(N - 3.5, -N + 6), 7, 6, 154.0, Rect2((N - 7) * T, -N * T, 7 * T, 6 * T))
	# Colțurile de sud: stau pe drumul de strajă și intră în curte cu vârful — treci PE DUPĂ ele.
	_turn(Vector2(-N + 3.5, N + 3.5), 7, 5, 100.0, Rect2(-N * T, (N - 2) * T, 7 * T, 2 * T))
	_turn(Vector2(N - 3.5, N + 3.5), 7, 5, 100.0, Rect2((N - 7) * T, (N - 2) * T, 7 * T, 2 * T))
	# Mijlocul zidurilor de vest și est: capătul aleilor laterale.
	_turn(Vector2(-N + 2.5, 4), 5, 4, 90.0, Rect2(-N * T, 0, 5 * T, 4 * T))
	_turn(Vector2(N - 2.5, 4), 5, 4, 90.0, Rect2((N - 5) * T, 0, 5 * T, 4 * T))

# Un turn privit din față: parapet (gol la mijloc, cu lespezi înăuntru), creneluri, fața de
# cărămidă. `baza` e mijlocul muchiei de jos a feței, în dale; tot de acolo se sortează pe Y.
# `solid` e ce ocupă turnul pe jos (în dale, relativ la centrul hărții).
func _turn(baza: Vector2, lat: int, adanc: int, fata_px: float, solid: Rect2) -> void:
	var t := Node2D.new()
	t.position = baza * T
	add_child(t)
	var w := lat * 32.0
	var d := adanc * 32.0
	var total := (d + TURN_CAP.size.y + fata_px) * S
	var x0 := -w * S * 0.5
	var interior := _np(t, _tx_piatra, LESPEDE_NIT, Rect2(x0 + 6 * S, -total + 6 * S, (w - 12) * S, (d - 6) * S))
	interior.modulate = Color(0.85, 0.85, 0.88)
	_np(t, _tx_zid, TURN_SUS, Rect2(x0, -total, w * S, d * S), [8, 8, 8, 0])
	_np(t, _tx_zid, TURN_CAP, Rect2(x0, -total + d * S, w * S, TURN_CAP.size.y * S), [8, 0, 8, 0])
	# Fața: aceeași cărămidă ca zidul de nord (fără crenelurile lui — turnul și-a pus capacul
	# deasupra), tivită pe laterale cu buza de piatră. Fața proprie a turnului din atlas are ramă
	# și, repetată, lăsa o cusătură verticală la fiecare 152 px.
	_np(t, _tx_zid, ZID_FARA_CAP, Rect2(x0, -fata_px * S, w * S, fata_px * S), [0, 9, 0, 19])
	_np(t, _tx_zid, BUZA_V_DR, Rect2(x0, -fata_px * S, 8 * S, fata_px * S))
	_np(t, _tx_zid, BUZA_V_ST, Rect2(-x0 - 10 * S, -fata_px * S, 10 * S, fata_px * S))
	# o fereastră îngustă în mijlocul feței
	_bucata(t, _tx_zid, FEREASTRA, Vector2(-12 * S, -fata_px * S * 0.62), false)
	_solid(solid)

# ---------- lăzi și butoaie ----------
# Singurul decor din curte. Stau în pâlcuri, ca provizii lăsate de garnizoană: de-a lungul
# zidurilor și câteva în curte. Mijlocul (poarta + ~12 dale în jur) rămâne gol — acolo începe
# lupta cu Sir John.
func _lazi_si_butoaie() -> void:
	# Nord: între turnuri, arcade și scară.
	for x in [-26.0, -19.0, -7.0, 7.0, 19.0, 26.0]:
		_gramada(Vector2(x, -N + 1.6), 3 + _rng.randi() % 3)
	# Sud: lângă buza de jos, între turnurile din colțuri.
	for x in [-24.0, -14.0, -4.5, 4.5, 14.0, 24.0]:
		_gramada(Vector2(x, N - 1.8), 2 + _rng.randi() % 4)
	# Vest/est: ocolind turnurile de la mijloc (care stau între dalele −1 și 4).
	for semn in [-1.0, 1.0]:
		for y in [-26.0, -15.0, 13.0, 25.0]:
			_gramada(Vector2(semn * (N - 1.8), y), 2 + _rng.randi() % 3)
	# În curte: patru depozite mari, în sferturi, și câteva pâlcuri mici pe drum spre ele.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			_gramada(Vector2(22 * sx, 22 * sy), 5)
			_gramada(Vector2(22 * sx + 2.4, 22 * sy + 1.8), 3)
			_gramada(Vector2(13 * sx, 26 * sy), 2)
			_gramada(Vector2(26 * sx, 12 * sy), 2)

# Un pâlc de `cate` lăzi/butoaie strânse unul lângă altul, ca lăsate de cineva, nu aliniate.
# Ce e fiecare (ladă sau butoi) iese din sămânța fixă, deci la fel de fiecare dată.
func _gramada(c: Vector2, cate: int) -> void:
	var loc := [Vector2(0, 0), Vector2(1.1, 0.2), Vector2(-0.9, 0.6), Vector2(0.4, 1.2), Vector2(-0.3, -0.9)]
	for i in mini(cate, loc.size()):
		var e_lada := _rng.randf() < 0.5
		var n := (LADA_SCENA if e_lada else BUTOI_SCENA).instantiate()
		n.position = (c + loc[i] * 1.1) * T
		add_child(n)

# ---------- unelte ----------
# O suprafață repetată dintr-o bucată de atlas. `m` = marginile nine-patch [st, sus, dr, jos]
# (px de textură): ele rămân întregi, mijlocul se repetă.
func _np(parinte: Node, tex: Texture2D, reg: Rect2, r: Rect2, m: Array = [0, 0, 0, 0]) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = tex
	n.region_rect = reg
	n.patch_margin_left = m[0]
	n.patch_margin_top = m[1]
	n.patch_margin_right = m[2]
	n.patch_margin_bottom = m[3]
	n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	n.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.position = r.position
	n.scale = Vector2(S, S)
	n.size = r.size / S
	parinte.add_child(n)
	return n

# O bucată de atlas pusă cu colțul din stânga-sus în `poz` (sau cu mijlocul, dacă `centrat`).
func _bucata(parinte: Node, tex: Texture2D, reg: Rect2, poz: Vector2, centrat: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = reg
	s.centered = centrat
	s.position = poz
	s.scale = Vector2(S, S)
	parinte.add_child(s)
	return s

# Un bloc solid fără desen (turnurile își au desenul separat). `r` în px de lume.
func _solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	col.shape = sh
	col.position = r.get_center()
	body.add_child(col)
	add_child(body)
