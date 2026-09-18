extends Node2D

# HARTA CASTELULUI LUI SIR JOHN — singura hartă FĂCUTĂ DE MÂNĂ din joc (cerută pe 2026-09-18:
# „fă dimensiunea lui Sir John predeterminată, să arate ca un castel, puțin mai mică decât acum,
# tot open space"). Toate celelalte locuri (lumea, Nether, Ender, Limbo) sunt generate la
# infinit; aici fiecare zid, turn, statuie și copac stă la locul lui, identic la fiecare intrare.
#
# O construiește `prison.gd::enter()` în `World`, centrată pe POARTA prin care ai intrat (deci
# poarta e mereu în mijlocul pieței), și o șterge la ieșire. Cât ești în Limbo e doar ascunsă.
#
# Arta: `harta/castle/Castel Textura/` (setul Cainos „Top Down Basic"), desenată pe dale de 32 px
# și pusă aici la SCARA 2, fiindcă omulețul din set (21×48 px) iese ~96 px, adică exact cât
# personajele noastre (polițistul are 87). Totul e cu `TEXTURE_FILTER_NEAREST`: pixel art crocant.
#
# 🔑 Cum se citește curtea (convenția setului): e o GROAPĂ privită de sus, din față. Zidul de NORD
# își arată fața de cărămidă (se uită spre tine), cele de est/vest/sud se văd doar ca o buză
# subțire de piatră. Deasupra zidurilor e drumul de strajă (lespezi), apoi întuneric.
#
# Cum e împărțită (în dale de 64 px, 0 = poarta):
#   • curtea: pătrat de 78×78 dale (4992 px); discul vechi avea raza 3000, deci ~12% mai mică;
#   • brâu de lespezi de 6 dale lângă ziduri + piață cu nituri de 24×24 în mijloc;
#   • patru alei de 6 dale spre cele patru ziduri, mărginite de coloane;
#   • patru grădini: NV fântâna, NE cimitirul cavalerilor, SV livada, SE curtea de depozit;
#   • patru turnuri în colțuri, două la mijlocul zidurilor laterale, scara din zidul de nord.
#
# ⚠️ Toate dreptunghiurile de pavaj pornesc din multipli de 3 dale: o lespede mare are 3×3 dale,
# iar NinePatchRect-ul o repetă din colțul LUI — dacă un dreptunghi pornește din alt loc, rosturile
# nu se mai potrivesc cu ale vecinului.
#
# Marginea (unde se oprește player-ul) o dă `rect_joc()`, citit de `prison.gd` și dat lui
# `ground.gd::set_margine_dreptunghi`. Tot acolo se uită și spawner-ul, deci inamicii nu se nasc
# în ziduri.

const S := 2.0                  # scara artei (px de lume pe px de textură)
const T := 64.0                 # o dală în lume (32 px de textură × S)
const N := 39                   # jumătate din latura curții, în dale
const FATA_ZID := 136.0         # înălțimea feței zidului de nord, px de textură (46 + 18×5) — ~4 oameni
const STRAJA := 6               # câte dale de drum de strajă se văd dincolo de ziduri
const STINGERE := 5             # pe câte dale se stinge drumul de strajă spre negru
const SEMINTA := 0x5143         # „SJ" — aceeași sămânță = aceleași pietre și flori la fiecare intrare

const DIR := "res://harta/castle/Castel Textura/"

# --- bucăți din atlase (px de textură) ---
const LESPEDE := Rect2(0, 0, 96, 96)            # lespede mare cu ramă (Stone Ground)
const LESPEDE_NIT := Rect2(160, 0, 96, 96)      # lespede cu nituri în colțuri (piața)
const IARBA := Rect2(0, 0, 128, 128)            # 4×4 dale de iarbă simplă (Grass)
const DRUM_ORIZ := Rect2(128, 128, 128, 64)     # potecă de pietre, orizontală
const DRUM_VERT := Rect2(64, 128, 64, 128)      # potecă de pietre, verticală
const DRUM_CRUCE := Rect2(0, 128, 64, 64)       # 2×2 dale numai pietre: încrucișarea potecilor

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

# Props (varianta „with Shadow" — umbra e deja desenată)
const LADA := Rect2(160, 18, 39, 46)
const CUFAR := Rect2(96, 30, 37, 31)
const TABLITA := Rect2(227, 91, 37, 66)
const BANCA := Rect2(292, 19, 63, 41)
const STATUIE := Rect2(445, 21, 38, 72)
const USA := Rect2(29, 103, 37, 50)             # din atlasul FĂRĂ umbră (stă într-o arcadă)
const ALTAR := Rect2(288, 87, 67, 36)
const SOCLU := Rect2(453, 118, 28, 37)
const INDICATOR_DR := Rect2(99, 160, 29, 32)
const INDICATOR_ST := Rect2(96, 224, 30, 32)
const BUTOI := Rect2(162, 153, 31, 36)
const MORMANT_ROTUND := Rect2(227, 183, 31, 38)
const SICRIU := Rect2(288, 158, 35, 57)
const COLOANA := Rect2(352, 174, 44, 77)
const COLOANA_RUPTA := Rect2(416, 194, 35, 57)
const VAZA := Rect2(165, 217, 23, 34)
const MORMANT_SCULPTAT := Rect2(225, 239, 35, 41)
const MORMANT_MIC := Rect2(289, 251, 32, 29)
const FANTANA := Rect2(353, 269, 97, 72)
const OALA := Rect2(164, 288, 28, 27)
const CRUCE := Rect2(227, 303, 34, 40)
const INEL_RUPT := Rect2(420, 359, 58, 49)
const VAZA2 := Rect2(165, 348, 23, 32)
const STANCA := Rect2(3, 430, 60, 42)
const PIETRE := [Rect2(10, 492, 12, 10), Rect2(40, 490, 17, 14), Rect2(68, 487, 25, 19),
	Rect2(100, 487, 25, 19), Rect2(130, 484, 29, 22), Rect2(231, 489, 18, 16), Rect2(263, 488, 19, 16),
	Rect2(289, 486, 31, 19)]

# Plants (tot „with Shadow")
const COPACI := [Rect2(24, 14, 113, 139), Rect2(161, 17, 95, 136), Rect2(295, 31, 83, 120)]
const TUFE := [Rect2(216, 185, 50, 44), Rect2(282, 186, 41, 47), Rect2(156, 190, 41, 33),
	Rect2(346, 190, 43, 37), Rect2(98, 195, 29, 27)]
const SMOCURI := [Rect2(8, 394, 17, 9), Rect2(41, 394, 16, 10), Rect2(73, 394, 15, 10),
	Rect2(102, 394, 15, 11), Rect2(9, 426, 12, 10), Rect2(43, 427, 13, 9), Rect2(74, 427, 13, 9),
	Rect2(104, 428, 14, 7)]

var _tx_piatra: Texture2D
var _tx_iarba: Texture2D
var _tx_zid: Texture2D
var _tx_struct: Texture2D
var _tx_props: Texture2D
var _tx_props_curat: Texture2D
var _tx_plante: Texture2D

var _plat: Node2D              # tot ce e lipit de pământ (pavaj, ziduri, buze), sub personaje
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
	_tx_iarba = load(DIR + "TX Tileset Grass.png")
	_tx_zid = load(DIR + "TX Tileset Wall.png")
	_tx_struct = load(DIR + "TX Struct.png")
	_tx_props = load(DIR + "Extra/TX Props with Shadow.png")
	_tx_props_curat = load(DIR + "TX Props.png")
	_tx_plante = load(DIR + "Extra/TX Plant with Shadow.png")

	_plat = Node2D.new()
	_plat.name = "Pamant"
	_plat.z_index = -9           # peste podeaua shaderului (-10), sub tot ce se sortează pe Y
	add_child(_plat)

	_podea()
	_ziduri()
	_turnuri()
	_piata_si_alei()
	_gradina_fantana(Vector2(-22, -22))
	_gradina_cimitir(Vector2(22, -22))
	_gradina_livada(Vector2(-22, 22))
	_gradina_depozit(Vector2(22, 22))
	_langa_ziduri()
	_presara()

# ---------- podeaua ----------
func _podea() -> void:
	var fata := FATA_ZID * S
	# Drumul de strajă: lespezi peste tot în jurul curții, puțin mai închise (e „sus", în bătaia vântului).
	var ext := Rect2(-N * T - STRAJA * T, -N * T - fata - STRAJA * T,
		2 * N * T + 2 * STRAJA * T, 2 * N * T + fata + 2 * STRAJA * T)
	var s := _np(_plat, _tx_piatra, LESPEDE, ext)
	s.modulate = Color(0.78, 0.78, 0.80)
	# Curtea: iarbă, peste ea pavajul.
	_np(_plat, _tx_iarba, IARBA, _dale(-N, -N, 2 * N, 2 * N))
	# Brâul de lângă ziduri (6 dale).
	_np(_plat, _tx_piatra, LESPEDE, _dale(-N, -N, 2 * N, 6))
	_np(_plat, _tx_piatra, LESPEDE, _dale(-N, N - 6, 2 * N, 6))
	_np(_plat, _tx_piatra, LESPEDE, _dale(-N, -N + 6, 6, 2 * N - 12))
	_np(_plat, _tx_piatra, LESPEDE, _dale(N - 6, -N + 6, 6, 2 * N - 12))
	# Aleile (6 dale late) — din brâu până în piață.
	_np(_plat, _tx_piatra, LESPEDE, _dale(-3, -N + 6, 6, N - 18))
	_np(_plat, _tx_piatra, LESPEDE, _dale(-3, 12, 6, N - 18))
	_np(_plat, _tx_piatra, LESPEDE, _dale(-N + 6, -3, N - 18, 6))
	_np(_plat, _tx_piatra, LESPEDE, _dale(12, -3, N - 18, 6))
	# Piața din mijloc, cu nituri — acolo stă poarta.
	_np(_plat, _tx_piatra, LESPEDE_NIT, _dale(-12, -12, 24, 24))
	_intuneric()

# Negrul de dincolo de drumul de strajă: o bandă care se stinge, apoi negru plin (ca groapa din
# Nether/Ender, doar că pătrată — e o cetate, nu o insulă).
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

# ---------- piața și aleile ----------
func _piata_si_alei() -> void:
	# Patru statui de cavaleri în colțurile pieței, cu vaze la picioare.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			_prop(_tx_props, STATUIE, Vector2(10.5 * sx, 10.5 * sy), 52, 24, sx > 0)
			_prop(_tx_props, VAZA, Vector2(10.5 * sx - 1.3 * sx, 10.5 * sy + 0.4))
	# Colonade pe marginile aleilor, din 5 în 5 dale; una din patru e surpată.
	for d in [15, 20, 25, 30]:
		for semn in [-1, 1]:
			for lat in [-3.6, 3.6]:
				_coloana(Vector2(lat, d * semn))
				_coloana(Vector2(d * semn, lat))
	# Indicatoare la intrarea aleilor în piață.
	_prop(_tx_props, INDICATOR_DR, Vector2(4.6, -13.2))
	_prop(_tx_props, INDICATOR_ST, Vector2(-4.6, 13.8))
	# Scara din zidul de nord, păzită de două statui.
	_prop(_tx_props, STATUIE, Vector2(-2.9, -N + 1.4), 52, 24)
	_prop(_tx_props, STATUIE, Vector2(2.9, -N + 1.4), 52, 24, true)

func _coloana(p: Vector2) -> void:
	var rupta := _rng.randf() < 0.25
	_prop(_tx_props, COLOANA_RUPTA if rupta else COLOANA, p, 44, 22)

# Cele două poteci de pietre care taie grădina în cruce. Grădina e sfertul de iarbă dintre brâu,
# alei și piață: 30×30 dale.
func _poteci(c: Vector2) -> void:
	var gx0 := -33 if c.x < 0 else 3
	var gy0 := -33 if c.y < 0 else 3
	_np(_plat, _tx_iarba, DRUM_ORIZ, _dale(gx0, c.y - 1, 30, 2))
	_np(_plat, _tx_iarba, DRUM_VERT, _dale(c.x - 1, gy0, 2, 30))
	# poteca verticală are iarbă pe margini și acoperea pietrele celei orizontale — le punem la loc
	_np(_plat, _tx_iarba, DRUM_CRUCE, _dale(c.x - 1, c.y - 1, 2, 2))

# NV: fântâna, cu bănci și tufe.
func _gradina_fantana(c: Vector2) -> void:
	_poteci(c)
	_prop(_tx_props, FANTANA, c + Vector2(0, 1.1), 170, 70)
	_prop(_tx_props, BANCA, c + Vector2(-5.5, -3.0), 110, 24)
	_prop(_tx_props, BANCA, c + Vector2(5.5, -3.0), 110, 24)
	_prop(_tx_props, BANCA, c + Vector2(-5.5, 4.5), 110, 24)
	_prop(_tx_props, BANCA, c + Vector2(5.5, 4.5), 110, 24)
	for o in [Vector2(-9, -9), Vector2(9, -9), Vector2(-9, 9), Vector2(9, 9), Vector2(-3.5, -8),
			Vector2(3.5, 8.5), Vector2(-9.5, 2.5), Vector2(9.5, -3)]:
		_prop(_tx_plante, TUFE[_rng.randi() % TUFE.size()], c + o)
	for o in [Vector2(-3, 2.6), Vector2(3, 2.6)]:
		_prop(_tx_props, SOCLU, c + o, 36, 18)

# NE: cimitirul cavalerilor — morminte în rânduri, sarcofagul la mijloc.
func _gradina_cimitir(c: Vector2) -> void:
	_poteci(c)
	var morminte := [MORMANT_ROTUND, MORMANT_SCULPTAT, MORMANT_MIC, CRUCE]
	for ox in [-10.0, -7.0, -4.0, 4.0, 7.0, 10.0]:
		for oy in [-10.0, -6.5, 4.5, 8.0, 11.5]:
			if _rng.randf() < 0.15:
				continue
			var m: Rect2 = morminte[_rng.randi() % morminte.size()]
			_prop(_tx_props, m, c + Vector2(ox, oy), 40, 18)
	_prop(_tx_props, ALTAR, c + Vector2(0, -2.6), 120, 30)
	_prop(_tx_props, SICRIU, c + Vector2(-3.5, 3.2), 50, 24)
	_prop(_tx_props, TABLITA, c + Vector2(3.5, 3.4), 50, 22)
	_prop(_tx_props, STATUIE, c + Vector2(0, -12.5), 52, 24)
	for o in [Vector2(-12, -2.5), Vector2(12, 2.5), Vector2(-12.5, 12.5), Vector2(12.5, -12.5)]:
		_prop(_tx_plante, TUFE[_rng.randi() % TUFE.size()], c + o)

# SV: livada — copaci în careu, tufe printre ei.
func _gradina_livada(c: Vector2) -> void:
	_poteci(c)
	for ox in [-11.0, -5.0, 5.0, 11.0]:
		for oy in [-10.0, -4.0, 5.0, 11.0]:
			if absf(ox) == 5.0 and absf(oy) <= 5.0:
				continue   # un luminiș la încrucișarea potecilor
			var r: Rect2 = COPACI[_rng.randi() % COPACI.size()]
			_prop(_tx_plante, r, c + Vector2(ox + _rng.randf_range(-0.6, 0.6), oy), 40, 20)
	_prop(_tx_props, BANCA, c + Vector2(0, -3.0), 110, 24)
	_prop(_tx_props, BUTOI, c + Vector2(2.6, 3.0), 44, 20)
	for i in 10:
		var o := Vector2(_rng.randf_range(-13, 13), _rng.randf_range(-13, 13))
		if absf(o.x) < 2.0 or absf(o.y) < 2.0:
			continue
		_prop(_tx_plante, TUFE[_rng.randi() % TUFE.size()], c + o)

# SE: curtea de depozit și antrenament — lăzi, butoaie, cufere, piatra de exercițiu.
func _gradina_depozit(c: Vector2) -> void:
	_poteci(c)
	_prop(_tx_props, INEL_RUPT, c + Vector2(0, 0.9), 100, 40)
	_gramada(c + Vector2(-8, -8), [LADA, LADA, BUTOI, LADA, OALA])
	_gramada(c + Vector2(8, -8), [BUTOI, BUTOI, BUTOI, VAZA2, BUTOI])
	_gramada(c + Vector2(-8, 8), [LADA, CUFAR, LADA, BUTOI, VAZA])
	_gramada(c + Vector2(8, 8), [CUFAR, OALA, LADA, LADA, BUTOI])
	_prop(_tx_props, STANCA, c + Vector2(-11, 1), 100, 36)
	_prop(_tx_props, COLOANA_RUPTA, c + Vector2(11, -2.5), 44, 22)
	_prop(_tx_props, INDICATOR_DR, c + Vector2(-2.6, -11))

# Un pâlc de obiecte strânse unul lângă altul, ca lăsate de cineva, nu aliniate.
func _gramada(c: Vector2, ce: Array) -> void:
	var loc := [Vector2(0, 0), Vector2(1.1, 0.2), Vector2(-0.9, 0.6), Vector2(0.4, 1.2), Vector2(-0.3, -0.9)]
	for i in ce.size():
		_prop(_tx_props, ce[i], c + loc[i] * 1.1, 44, 20)

# ---------- lângă ziduri ----------
func _langa_ziduri() -> void:
	# Nord: provizii între turnuri și arcade.
	_gramada(Vector2(-24, -N + 2.2), [BUTOI, LADA, BUTOI, LADA, OALA])
	_gramada(Vector2(24, -N + 2.2), [LADA, BUTOI, LADA, VAZA, BUTOI])
	_gramada(Vector2(-7.5, -N + 1.8), [VAZA, OALA, VAZA2])
	_gramada(Vector2(7.5, -N + 1.8), [OALA, VAZA2, VAZA])
	# Sud: bănci de gardă și butoaie.
	for x in [-24.0, -12.0, 12.0, 24.0]:
		_prop(_tx_props, BANCA, Vector2(x, N - 1.6), 110, 24)
	_gramada(Vector2(-5.5, N - 2.4), [BUTOI, LADA, BUTOI])
	_gramada(Vector2(5.5, N - 2.4), [LADA, BUTOI, OALA])
	# Vest/est: pietre cu inscripții lângă turnurile de la mijloc.
	for semn in [-1.0, 1.0]:
		_prop(_tx_props, TABLITA, Vector2(semn * (N - 2.5), -4.5), 50, 22)
		_prop(_tx_props, TABLITA, Vector2(semn * (N - 2.5), 8.0), 50, 22)
		_prop(_tx_props, SOCLU, Vector2(semn * (N - 2.2), -20), 36, 18)
		_prop(_tx_props, SOCLU, Vector2(semn * (N - 2.2), 20), 36, 18)

# ---------- mărunțișuri pe jos ----------
# Pietricele, smocuri de iarbă și flori — lipite de pământ (nu se sortează, nu opresc pe nimeni).
func _presara() -> void:
	for i in 140:
		var p := Vector2(_rng.randf_range(-N + 1, N - 1), _rng.randf_range(-N + 1, N - 1))
		if p.length() < 4.0:
			continue
		if _e_pavat(p):
			if _rng.randf() < 0.55:
				_bucata(_plat, _tx_props, PIETRE[_rng.randi() % PIETRE.size()], p * T, true)
		else:
			_bucata(_plat, _tx_plante, SMOCURI[_rng.randi() % SMOCURI.size()], p * T, true)
	# flori: dalele de iarbă cu flori din același atlas (coloanele 4-7), puse peste iarba simplă
	for i in 90:
		var p := Vector2(_rng.randi_range(-N, N - 1), _rng.randi_range(-N, N - 1))
		if _e_pavat(p + Vector2(0.5, 0.5)):
			continue
		var cel := Rect2(128 + (_rng.randi() % 4) * 32, (_rng.randi() % 4) * 32, 32, 32)
		_bucata(_plat, _tx_iarba, cel, p * T, false)

func _e_pavat(p: Vector2) -> bool:
	var ax := absf(p.x)
	var ay := absf(p.y)
	return ax >= N - 6 or ay >= N - 6 or (ax < 12 and ay < 12) or ax < 3 or ay < 3

# ---------- unelte ----------
func _dale(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * T, y * T, w * T, h * T)

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

# Un obiect în picioare, sortat pe Y după baza lui. `p` în dale. Dacă primește `lat` > 0, e și
# SOLID: o cutie de lat × adanc px pe jos, la bază (ca trunchiul copacilor din `props.gd`).
func _prop(tex: Texture2D, reg: Rect2, p: Vector2, lat: float = 0.0, adanc: float = 0.0, oglinda: bool = false) -> Node2D:
	var n: Node2D
	if lat > 0.0:
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(lat, adanc)
		col.shape = sh
		col.position = Vector2(0, -adanc * 0.5)
		body.add_child(col)
		n = body
	else:
		n = Node2D.new()
	n.position = p * T
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = reg
	s.centered = false
	s.flip_h = oglinda
	# umbra desenată cade spre dreapta-jos, deci baza obiectului e cu ~3 px deasupra marginii de jos
	s.offset = Vector2(-reg.size.x * 0.5, -reg.size.y + 3.0)
	s.scale = Vector2(S, S)
	n.add_child(s)
	add_child(n)
	return n

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
