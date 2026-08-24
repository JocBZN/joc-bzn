extends Control

# ---------------------------------------------------------------------------
# O BARĂ DE STATUS ÎMBRĂCATĂ ÎN RAMA DE ARAMĂ A JOCULUI
# ---------------------------------------------------------------------------
# Cărămida din care sunt făcute TOATE cele trei bare de pe ecran: viața playerului și XP-ul
# (`hud.gd`) și viața boss-ului (`boss_bar.gd`). Înainte fiecare era un `ProgressBar` cu un
# `StyleBoxFlat` colorat — dreptunghiuri plate, desenate din cod. Acum toate trei ies din
# aceeași planșă de rame ca meniul principal, pauza, cazinoul, Alba-Neagra și level up-ul
# (`harta/EGT/Border EGT.png`), deci HUD-ul vorbește aceeași limbă vizuală cu restul jocului.
#
# CUM E CONSTRUITĂ, de jos în sus:
#   1. `_rama`  — chenarul, un nine-patch din planșă. Interiorul lui e deja închis la culoare,
#                 deci ȚINE LOC DE FUNDAL: nu mai desenăm noi unul.
#   2. `_clip`  — o cutie trasă spre interior cu grosimea ramei (`inset`), cu `clip_contents`
#                 pornit. Tot ce se mișcă stă înăuntrul ei, deci nimic nu poate să iasă peste
#                 aramă, oricât de plină ar fi bara.
#   3. `_urma`  — bara „fantomă" care rămâne în urmă când pierzi (vezi `URMA_VITEZA`).
#   4. `_umplere` — umplerea propriu-zisă, în TREI benzi (luciu sus, culoarea de bază la mijloc,
#                 umbră jos). Nu e un degrade lin: la pixel art trei benzi arată corect, un
#                 degrade neted ar fi arătat ca o bară de Windows lipită peste artă.
#   5. `_trepte` — crestături subțiri peste umplere, ca să se vadă din ochi „cât mai am".
#   6. `_licar` — o dungă de lumină care mătură bara (doar unde o cere cine o folosește).
#   7. `_fulger` — foaia albă care clipește la lovitură / vindecare.
#   8. `_text`  — cifrele, deasupra tuturor.
#
# ⚠️ Ordinea copiilor ESTE desenarea. Dacă adaugi ceva, adaugă-l în locul lui, nu la sfârșit.
#
# NU are `_ready()`: cine o folosește o construiește singur cu `construieste(...)`, fiindcă
# celula din planșă, zoom-ul și culorile diferă de la o bară la alta.

const SHEET := "res://harta/EGT/Border EGT.png"
const CELULA := 64          # cât are o celulă din planșă

# Planșa se citește o SINGURĂ dată pentru tot jocul, oricâte bare s-ar face din ea.
static var _foaie: Image = null

# --- paleta, aceeași cu a meniurilor (vezi `casino.gd`) ---
const ACCENT := Color8(198, 118, 80)        # arama aprinsă
const OS_ALB := Color8(232, 224, 214)       # alb-os, pentru cifre

# ⚠️ CÂT DE APRINS ARE VOIE SĂ FIE HUD-UL
# De când HUD-ul a urcat peste vinietă (vezi `hud.gd`), nimic nu-l mai stinge — iar la culoarea
# plină arama și roșul ies mai tari decât jocul de sub ele („mi se pare ca sunt mult mai
# luminoase decat jocu in sine", Răzvan, 2026-08-24). `UMBRA` le trage înapoi în tonul lumii.
# Se schimbă AICI o dată și se mută la toate trei barele, la insigna de nivel și la numele
# boss-ului. 1.0 = aprins la maximum, mai mic = mai stins.
const UMBRA := Color(0.68, 0.68, 0.68)

# Cât de repede coboară urma spre valoarea reală (fracțiune din bară pe secundă).
const URMA_VITEZA := 0.70

var _rama: NinePatchRect
var _clip: Control
var _urma: ColorRect
var _umplere: Control
var _trepte: Control
var _licar: TextureRect
var _fulger: ColorRect
var _text: Label

var _val := 1.0             # 0..1, unde ar trebui să fie bara ACUM
var _urma_val := 1.0        # 0..1, unde a ajuns fantoma (coboară încet spre `_val`)
var _cate_trepte := 0
var _licar_t := 0.0
var _licar_pornit := false
var _lat_veche := -1.0      # ca să reașezăm crestăturile doar când chiar se schimbă lățimea

# Construiește bara. `celula` = ce chenar din planșă (coloană, rând, de la 0). `zoom` = cu cât se
# scalează celula înainte să devină textură — poate fi și 0.5, pentru bare subțiri (vezi `chenar`);
# nine-patch-ul întinde doar mijlocul laturii, nu grosimea ei. `margine` = câți pixeli DE PLANȘĂ
# din colț NU se întind (cât ține ornamentul); se scalează și el cu zoom. `inset` = grosimea ramei,
# adică de cât trebuie trasă înăuntru zona care se mișcă.
func construieste(celula: Vector2i, zoom: float, margine: int, inset: int, culoare: Color, urma_culoare: Color) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = UMBRA

	_rama = NinePatchRect.new()
	_rama.texture = chenar(celula, zoom)
	_rama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := int(roundf(margine * zoom))
	_rama.patch_margin_left = m
	_rama.patch_margin_right = m
	_rama.patch_margin_top = m
	_rama.patch_margin_bottom = m
	_rama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rama)

	var g := float(inset) * zoom
	_clip = Control.new()
	_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.offset_left = g
	_clip.offset_top = g
	_clip.offset_right = -g
	_clip.offset_bottom = -g
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)

	_urma = ColorRect.new()
	_urma.color = urma_culoare
	_urma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_urma)

	_umplere = Control.new()
	_umplere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_umplere)
	# cele trei benzi: luciu sus (mai deschis), baza, umbră jos (mai închis)
	_banda(_umplere, culoare, 0.0, 1.0)
	_banda(_umplere, culoare.lightened(0.30), 0.0, 0.34)
	_banda(_umplere, culoare.darkened(0.38), 0.76, 1.0)

	_trepte = Control.new()
	_trepte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trepte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_trepte)

	_licar = TextureRect.new()
	_licar.texture = _textura_licar()
	_licar.stretch_mode = TextureRect.STRETCH_SCALE
	_licar.visible = false
	_licar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_licar)

	_fulger = ColorRect.new()
	_fulger.color = Color(1, 1, 1, 0)
	_fulger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fulger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_fulger)

	_text = Label.new()
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_color_override("font_color", OS_ALB)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_text.add_theme_constant_override("outline_size", 4)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)

# O bandă orizontală din umplere, dată în fracțiuni din înălțime (0 = sus, 1 = jos).
func _banda(parinte: Control, culoare: Color, sus: float, jos: float) -> void:
	var c := ColorRect.new()
	c.color = culoare
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = sus
	c.anchor_bottom = jos
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parinte.add_child(c)

# ---------------------------------------------------------------------------
# CE CHEAMĂ CINE O FOLOSEȘTE
# ---------------------------------------------------------------------------
# Unde e bara acum, 0..1. Fantoma coboară singură spre valoarea asta (vezi `_process`), dar dacă
# valoarea URCĂ (te-ai vindecat, ai luat XP) o duce imediat cu ea — n-are ce să rămână în urmă.
func set_fractie(f: float) -> void:
	_val = clampf(f, 0.0, 1.0)
	if _urma_val < _val:
		_urma_val = _val

# Duce fantoma exact pe valoare, fără alunecare. De chemat la reset (boss nou, rundă nouă).
func sari_urma() -> void:
	_urma_val = _val

func set_text(t: String) -> void:
	_text.text = t

# Mărimea cifrelor de pe bară. `contur` scade odată cu ea: pe o bară subțire un contur de 4px
# ar fi mai gros decât liniile literei și cifrele ar ieși o pată neagră.
func set_font(marime: int, contur: int = 4) -> void:
	_text.add_theme_font_size_override("font_size", marime)
	_text.add_theme_constant_override("outline_size", contur)

# Câte crestături se desenează peste bară. 0 = niciuna.
func set_trepte(cate: int) -> void:
	if cate == _cate_trepte:
		return
	_cate_trepte = cate
	_lat_veche = -1.0   # forțează reașezarea la următorul cadru

# Dunga de lumină care mătură bara (o folosește XP-ul).
func porneste_licarirea() -> void:
	_licar_pornit = true

# Un clipit colorat peste toată bara: alb la lovitură, verde la vindecare, auriu la level up.
func fulgera(culoare: Color, durata: float = 0.28) -> void:
	_fulger.color = culoare
	var t := create_tween()
	t.tween_property(_fulger, "color:a", 0.0, durata).from(culoare.a)

# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	var lat := _clip.size.x
	var inalt := _clip.size.y
	if lat <= 0.0:
		return

	# fantoma coboară încet spre valoarea reală — de-aia se vede cât ai mușcat dintr-o lovitură
	if _urma_val > _val:
		_urma_val = maxf(_val, _urma_val - URMA_VITEZA * delta)

	_urma.position = Vector2.ZERO
	_urma.size = Vector2(lat * _urma_val, inalt)
	_umplere.position = Vector2.ZERO
	_umplere.size = Vector2(lat * _val, inalt)

	if not is_equal_approx(lat, _lat_veche):
		_lat_veche = lat
		_aseaza_trepte(lat, inalt)

	if _licar_pornit:
		_misca_licarul(delta, lat, inalt)

# Crestăturile: linii verticale subțiri, întunecate, la distanțe egale. Nu se desenează peste
# capete (prima și ultima ar sta lipite de ramă), de-aia bucla începe de la 1.
func _aseaza_trepte(lat: float, inalt: float) -> void:
	for c in _trepte.get_children():
		c.queue_free()
	if _cate_trepte <= 1:
		return
	var pas := lat / float(_cate_trepte)
	for i in range(1, _cate_trepte):
		var l := ColorRect.new()
		l.color = Color(0, 0, 0, 0.34)
		l.position = Vector2(roundf(i * pas), 0.0)
		l.size = Vector2(1.0, inalt)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_trepte.add_child(l)

# Dunga de lumină pleacă din stânga, trece peste PARTEA PLINĂ și se stinge. Apoi așteaptă
# `LICAR_PAUZA` secunde și o ia de la capăt — dacă ar mătura fără pauză ar deveni zgomot.
const LICAR_LAT := 54.0
const LICAR_PAUZA := 2.4
const LICAR_DURATA := 0.85

func _misca_licarul(delta: float, lat: float, inalt: float) -> void:
	_licar_t += delta
	var ciclu := LICAR_DURATA + LICAR_PAUZA
	if _licar_t > ciclu:
		_licar_t -= ciclu
	var plin := lat * _val
	if _licar_t > LICAR_DURATA or plin < LICAR_LAT * 0.5:
		_licar.visible = false
		return
	_licar.visible = true
	var p := _licar_t / LICAR_DURATA
	_licar.position = Vector2(-LICAR_LAT + p * (plin + LICAR_LAT), 0.0)
	_licar.size = Vector2(LICAR_LAT, inalt)

# ---------------------------------------------------------------------------
# Textura dungii de lumină: transparent → alb slab → transparent, pe orizontală.
func _textura_licar() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.26))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 4
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	return t

# Decupează o celulă din planșă și o scalează cu `zoom` (vecinul cel mai apropiat, deci rămâne
# pixel art curat). `NinePatchRect` vrea o textură întreagă — un `AtlasTexture` nu e de încredere
# aici, de-aia se face textură nouă, exact ca la `casino.gd`.
#
# `zoom` are voie să fie și SUBUNITAR (0.5): așa se face o ramă pentru o bară subțire. Nu e un
# moft — nine-patch-ul nu poate desena o ramă mai scundă decât suma marginilor ei, deci o bară
# de 19px nu încape într-un chenar cu colțuri de 12px. Micșorând CELULA, se micșorează și
# ornamentul, deci rama rămâne întreagă, doar mai fină. (Alternativa — să declari colțuri mai
# mici decât sunt — întinde jumătate de ornament pe toată lățimea barei.)
static func chenar(celula: Vector2i, zoom: float) -> ImageTexture:
	if _foaie == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_foaie = tex.get_image()
	var bucata := _foaie.get_region(Rect2i(celula.x * CELULA, celula.y * CELULA, CELULA, CELULA))
	# ⚠️ La MICȘORARE nu se folosește „vecinul cel mai apropiat": el aruncă un pixel din doi, iar
	# rama asta e făcută din linii de 1px — la jumătate ieșea o mâzgă maro, cu colțurile rupte și
	# nesimetrice (probat pe 2026-08-24, se vede doar în captură). `shrink_x2` face MEDIA pe
	# blocuri de 2×2: liniile subțiri se păstrează ca linii mai stinse, iar niturile rămân nituri.
	# Doar la MĂRIRE rămâne nearest — acolo el e cel corect (pixel art curat, fără interpolare).
	if is_equal_approx(zoom, 0.5):
		bucata.shrink_x2()
	elif zoom > 1.0:
		bucata.resize(int(CELULA * zoom), int(CELULA * zoom), Image.INTERPOLATE_NEAREST)
	elif not is_equal_approx(zoom, 1.0):
		var lat := maxi(int(roundf(CELULA * zoom)), 8)
		bucata.resize(lat, lat, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(bucata)

# Dă un ton ramei (viața sub 30% pulsează roșu). `Color.WHITE` = culoarea ei normală.
func set_ton_rama(c: Color) -> void:
	_rama.modulate = c
