extends Node2D

# UNEALTĂ de verificare pentru cele PATRU ITEME NOI de pe 2026-09-04 (nu face parte din joc):
#
#   "<godot.exe>" --path <proiect> res://tool_iteme_noi.tscn
#
# Se rulează ca SCENĂ (are nevoie de autoload-uri: I18n, GameSettings, Difficulty, Fx) și în
# FEREASTRĂ, nu headless: partea [5] face poze cu ecranul real de level up, iar headless
# randează negru.
#
# Ce verifică, în ordine:
#   [1] cele 4 iteme sunt în `levelup.UPGRADES`, cu iconița/raritatea/textul cerute, iconițele
#       chiar se încarcă, id-urile nu se repetă;
#   [2] efectele, aplicate pe un player ADEVĂRAT prin `levelup._apply` (nu citite din sursă);
#   [3] Broken Glasses statistic: 40.000 de salve, cât de des chiar dă proiectilul bonus;
#   [4] traducerile: cele 8 chei noi există, au 8 traduceri nevide, iar numele/descrierea
#       ÎNCAP pe cartonaș în toate cele 9 limbi (numele se taie, descrierea se rupe la 2 rânduri);
#   [5] poza: două pagini de level up desenate de codul adevărat, cu cele 4 cartonașe.

const NOI := ["medkit", "broken_glasses", "poisoned_water", "submission"]
const ASTEPTAT := {
	"medkit":         {"icon": "upgrade_69.png", "rar": "legendary", "desc": "+10 HP/sec, +10 Max HP"},
	"broken_glasses": {"icon": "upgrade_68.png", "rar": "common",    "desc": "25% chance to fire +1 projectile"},
	"poisoned_water": {"icon": "upgrade_70.png", "rar": "uncommon",  "desc": "+5% Difficulty, +5% Attack Speed"},
	"submission":     {"icon": "upgrade_71.png", "rar": "rare",      "desc": "Crits heal you 6 HP"},
}
const NUME := {
	"medkit": "Medkit", "broken_glasses": "Broken Glasses",
	"poisoned_water": "Poisoned Water", "submission": "Submission",
}

var _err := 0
var _lvl: CanvasLayer = null
var _p: Node = null

func _ok(m: String) -> void:
	print("  [OK]  ", m)

func _fail(m: String) -> void:
	_err += 1
	print("  [NU]  ", m)

func _cer(cond: bool, m: String) -> void:
	if cond:
		_ok(m)
	else:
		_fail(m)

func _ready() -> void:
	await get_tree().process_frame
	print("\n========== ITEMELE NOI (2026-09-04) ==========")
	_lvl = CanvasLayer.new()
	_lvl.set_script(load("res://levelup.gd"))
	add_child(_lvl)
	await get_tree().process_frame

	_sectiunea_1()
	_fa_player()
	_sectiunea_2()
	_sectiunea_3()
	await _sectiunea_4()
	await _sectiunea_5()

	print("\n==============================================")
	if _err == 0:
		print("=== TOTUL E BINE ===")
	else:
		print("=== %d PROBLEME ===" % _err)
	get_tree().quit(1 if _err > 0 else 0)

# ---------------------------------------------------------------------------
# [1] Itemele sunt în listă, cu ce s-a cerut
# ---------------------------------------------------------------------------
func _sectiunea_1() -> void:
	print("\n--- [1] cele 4 iteme în listă ---")
	var vazute := {}
	for u in _lvl.UPGRADES:
		if vazute.has(u["id"]):
			_fail("id repetat în UPGRADES: %s" % u["id"])
		vazute[u["id"]] = true
	_ok("%d iteme în pool, niciun id repetat" % _lvl.UPGRADES.size())

	for id in NOI:
		var u = _lvl.item_dupa_id(id)
		if u == null:
			_fail("%s: nu e în UPGRADES" % id)
			continue
		var a: Dictionary = ASTEPTAT[id]
		_cer(u["nume"] == NUME[id], "%s: nume „%s”" % [id, u["nume"]])
		_cer(u["icon"] == a["icon"], "%s: iconița %s" % [id, u["icon"]])
		_cer(u["rar"] == a["rar"], "%s: raritatea %s" % [id, u["rar"]])
		_cer(u["desc"] == a["desc"], "%s: textul „%s”" % [id, u["desc"]])
		var tex = load(_lvl.icon_path(u))
		_cer(tex != null, "%s: iconița se încarcă (%s)" % [id, a["icon"]])
		# nu e „unic": toate patru se pot lua de câte ori apar
		_cer(not u.get("unic", false), "%s: se poate lua de mai multe ori" % id)

# Un player ADEVĂRAT (player.tscn), ca efectele să treacă prin exact codul din joc.
# Îi oprim ceasul de tragere și `_process`: n-avem lume în jur, iar noi doar citim statusuri.
func _fa_player() -> void:
	_p = load("res://player.tscn").instantiate()
	add_child(_p)
	if _p.get("fire_timer") != null:
		_p.fire_timer.stop()
	_p.set_process(false)
	_p.set_physics_process(false)

# Aplică un item pe player prin drumul ADEVĂRAT din joc (`levelup._apply`), nu scriind în variabile.
func _ia(id: String) -> void:
	_lvl._apply(id, _p)

# ---------------------------------------------------------------------------
# [2] Efectele, pe player adevărat
# ---------------------------------------------------------------------------
func _sectiunea_2() -> void:
	print("\n--- [2] efectele ---")

	# --- MEDKIT: +10 regen, +10 max HP, iar regenerarea NU trece de maxim ---
	var regen0: int = _p.hp_regen
	var max0: int = _p.max_hp
	_p.hp = max0 - 50
	var hp0: int = _p.hp
	_ia("medkit")
	_cer(_p.hp_regen == regen0 + 10, "Medkit: HP regen %d → %d" % [regen0, _p.hp_regen])
	_cer(_p.max_hp == max0 + 10, "Medkit: Max HP %d → %d" % [max0, _p.max_hp])
	_cer(_p.hp == hp0 + 10, "Medkit: te și vindecă pe loc, %d → %d" % [hp0, _p.hp])
	_ia("medkit")
	_cer(_p.hp_regen == regen0 + 20, "Medkit ×2: regenerarea se adună (%d/s)" % _p.hp_regen)
	# regula cerută: „recovery nu în plus față de max HP"
	_p.hp = _p.max_hp - 3
	_p._regen()
	_cer(_p.hp == _p.max_hp, "Medkit: regenerarea se oprește la maxim (%d/%d), nu-l depășește" % [_p.hp, _p.max_hp])
	_p._regen()
	_cer(_p.hp == _p.max_hp, "Medkit: încă un tic de regenerare tot nu trece de maxim")

	# --- BROKEN GLASSES: contorul crește, șansa rămâne 25% ---
	_cer(_p.broken_glasses_stacks == 0, "Broken Glasses: pornește de la 0 proiectile bonus")
	_ia("broken_glasses")
	_cer(_p.broken_glasses_stacks == 1, "Broken Glasses: +1 proiectil bonus")
	_cer(is_equal_approx(_p.broken_glasses_chance, 0.25), "Broken Glasses: șansa e 25%")
	_ia("broken_glasses")
	_cer(_p.broken_glasses_stacks == 2, "Broken Glasses ×2: 2 proiectile când se declanșează (șansa tot 25%)")
	_cer(is_equal_approx(_p.broken_glasses_chance, 0.25), "Broken Glasses ×2: șansa NU crește")

	# --- POISONED WATER: dificultatea în sus, cadența în jos ---
	Difficulty.reset_run()
	var interval0: float = _p.fire_interval
	_ia("poisoned_water")
	_cer(is_equal_approx(Difficulty.trade_penalty, 1.05), "Poisoned Water: dificultatea ×%.4f" % Difficulty.trade_penalty)
	_cer(is_equal_approx(_p.fire_interval, interval0 * 0.95), "Poisoned Water: pauza dintre trageri %.4f → %.4f (+5%% cadență)" % [interval0, _p.fire_interval])
	_ia("poisoned_water")
	_cer(is_equal_approx(Difficulty.trade_penalty, 1.1025), "Poisoned Water ×2: se ÎNMULȚEȘTE (×%.4f), nu se adună" % Difficulty.trade_penalty)
	# același canal ca Tome of Witchcraft — se compun între ele
	_ia("tome_witchcraft")
	_cer(is_equal_approx(Difficulty.trade_penalty, 1.1025 * 1.10), "Poisoned Water + Tome of Witchcraft: același canal, ×%.4f" % Difficulty.trade_penalty)
	Difficulty.reset_run()

	# --- SUBMISSION: 6 HP pe critic, în același rezervor cu Bloody Situation ---
	_cer(_p.bloody_heal_hp == 0, "Submission: fără item, criticul nu vindecă nimic")
	_p.hp = _p.max_hp - 50
	var h0: int = _p.hp
	_p.bloody_heal()
	_cer(_p.hp == h0, "Submission: `bloody_heal()` fără item nu face nimic")
	_ia("submission")
	_cer(_p.bloody_heal_hp == 6, "Submission: criticul vindecă 6 HP")
	_p.bloody_heal()
	_cer(_p.hp == h0 + 6, "Submission: un critic te-a vindecat %d → %d" % [h0, _p.hp])
	_ia("bloody_situation")
	_cer(_p.bloody_heal_hp == 8, "Submission + Bloody Situation: 6 + 2 = %d HP pe critic" % _p.bloody_heal_hp)
	_ia("submission")
	_cer(_p.bloody_heal_hp == 14, "Submission ×2: se stivuiește (%d HP pe critic)" % _p.bloody_heal_hp)
	# nici vindecarea la critic nu trece de maxim
	_p.hp = _p.max_hp - 3
	_p.bloody_heal()
	_cer(_p.hp == _p.max_hp, "Submission: vindecarea la critic se oprește la maxim (%d/%d)" % [_p.hp, _p.max_hp])

# ---------------------------------------------------------------------------
# [3] Broken Glasses statistic + regresie pe Bloody Situation
# ---------------------------------------------------------------------------
# Un player nou, curat: cel de la [2] are deja itemele lipite pe el.
func _player_nou() -> Node:
	var p = load("res://player.tscn").instantiate()
	add_child(p)
	if p.get("fire_timer") != null:
		p.fire_timer.stop()
	p.set_process(false)
	p.set_physics_process(false)
	p.luck = 0.0
	return p

const SALVE := 40000

func _sectiunea_3() -> void:
	print("\n--- [3] cât de des chiar dă proiectilul bonus ---")
	var p := _player_nou()
	# Norocul intră în ȘANSĂ (`luck_bonus`), deci îl scoatem din ecuație ca să măsurăm itemul.
	_cer(is_zero_approx(p.luck_bonus()), "sonda pornește cu 0 noroc (altfel șansa ar fi mai mare)")

	# doar ochelarii: 25% din salve trebuie să aibă +1
	_lvl._apply("broken_glasses", p)
	var cu_bonus := 0
	for i in SALVE:
		if p.proiectile_bonus_pe_sansa() > 0:
			cu_bonus += 1
	var pct := 100.0 * cu_bonus / float(SALVE)
	_cer(absf(pct - 25.0) < 1.0, "doar Broken Glasses: %.2f%% din %d salve au proiectil bonus (țintă 25%%)" % [pct, SALVE])

	# ochelarii + ceasul: două zaruri SEPARATE — 12,5% din salve dau amândouă (+2)
	_lvl._apply("broken_watch", p)
	var doi := 0
	var vreunul := 0
	var total := 0
	for i in SALVE:
		var b: int = p.proiectile_bonus_pe_sansa()
		total += b
		if b > 0:
			vreunul += 1
		if b == 2:
			doi += 1
	var pct_doi := 100.0 * doi / float(SALVE)
	var pct_vreunul := 100.0 * vreunul / float(SALVE)
	var mediu := total / float(SALVE)
	_cer(absf(pct_doi - 12.5) < 1.0, "Glasses + Watch: %.2f%% din salve le declanșează pe AMÂNDOUĂ (țintă 12,5%%)" % pct_doi)
	_cer(absf(pct_vreunul - 62.5) < 1.0, "Glasses + Watch: %.2f%% au măcar unul (țintă 62,5%%)" % pct_vreunul)
	_cer(absf(mediu - 0.75) < 0.03, "Glasses + Watch: %.3f proiectile bonus pe salvă în medie (țintă 0,75)" % mediu)

	# și bursturile de sabie/coasă trec prin ACEEAȘI socoteală
	var extra_max := 0
	for i in 2000:
		extra_max = maxi(extra_max, p._extra_attacks())
	_cer(extra_max == 2, "sabie/coasă: bursturile folosesc aceeași socoteală (max %d atacuri extra)" % extra_max)
	p.queue_free()

	# regresie: Bloody Situation SINGUR vindecă tot 2 HP, ca înainte de 2026-09-04
	var p2 := _player_nou()
	_lvl._apply("bloody_situation", p2)
	p2.hp = p2.max_hp - 20
	var h: int = p2.hp
	p2.bloody_heal()
	_cer(p2.hp == h + 2, "regresie: Bloody Situation singur vindecă tot 2 HP (%d → %d)" % [h, p2.hp])
	_lvl._apply("bloody_situation", p2)
	p2.hp = p2.max_hp - 20
	h = p2.hp
	p2.bloody_heal()
	_cer(p2.hp == h + 4, "regresie: Bloody Situation ×2 vindecă 4 HP (%d → %d)" % [h, p2.hp])
	p2.queue_free()

# ---------------------------------------------------------------------------
# [4] Traducerile + textul încape pe cartonaș, în toate cele 9 limbi
# ---------------------------------------------------------------------------
# Pune pe ecran EXACT itemele cerute, prin codul adevărat (`_show_choices`): îi îngustăm
# temporar pool-ul la cele 3 iteme, deci tragerea n-are ce altceva să scoată.
func _arata(ids: Array) -> void:
	var pool := []
	for id in ids:
		pool.append(_lvl.item_dupa_id(id))
	var vechi = _lvl.UPGRADES
	_lvl.UPGRADES = pool
	_lvl._show_choices()
	_lvl.UPGRADES = vechi
	_lvl.visible = true
	await get_tree().process_frame
	await get_tree().process_frame

const PAGINI := [
	["medkit", "broken_glasses", "poisoned_water"],
	["submission", "medkit", "poisoned_water"],
]

func _sectiunea_4() -> void:
	print("\n--- [4] traducerile ---")
	var chei := []
	for id in NOI:
		chei.append(NUME[id])
		chei.append(ASTEPTAT[id]["desc"])
	for cheie in chei:
		if not I18n.TRAD.has(cheie):
			_fail("lipsește din I18n.TRAD: „%s”" % cheie)
			continue
		var trad: Array = I18n.TRAD[cheie]
		if trad.size() != I18n.ORDINE.size():
			_fail("„%s”: %d traduceri, trebuie %d" % [cheie, trad.size(), I18n.ORDINE.size()])
			continue
		var goale := 0
		for t in trad:
			if String(t).strip_edges().is_empty():
				goale += 1
		_cer(goale == 0, "„%s”: %d traduceri, niciuna goală" % [cheie, trad.size()])

	print("\n--- [4b] textul încape pe cartonaș, în toate limbile ---")
	var locala_veche := TranslationServer.get_locale()
	var probleme := 0
	for limba in I18n.LIMBI:
		TranslationServer.set_locale(limba["cod"])
		for pagina in PAGINI:
			await _arata(pagina)
			for i in 3:
				var id: String = _lvl._current[i]["id"]
				if not NOI.has(id):
					continue
				# NUMELE: `clip_text = true` îl TAIE dacă nu încape — nu se vede că lipsește ceva.
				var nl: Label = _lvl._name_labels[i]
				var font := nl.get_theme_font("font")
				var fs := nl.get_theme_font_size("font_size")
				var text_tradus := nl.tr(nl.text)
				var latime := font.get_string_size(text_tradus, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if latime > nl.size.x:
					probleme += 1
					_fail("%s / %s: numele „%s” se taie (%.0f px, loc %.0f)" % [id, limba["cod"], text_tradus, latime, nl.size.x])
				# DESCRIEREA: se rupe singură, dar `max_lines_visible = 2` taie rândul al treilea.
				var dl: Label = _lvl._desc_labels[i]
				if dl.get_line_count() > dl.max_lines_visible:
					probleme += 1
					_fail("%s / %s: descrierea are %d rânduri, încap %d" % [id, limba["cod"], dl.get_line_count(), dl.max_lines_visible])
	TranslationServer.set_locale(locala_veche)
	_cer(probleme == 0, "cele 4 iteme încap pe cartonaș în toate cele %d limbi" % I18n.LIMBI.size())

# ---------------------------------------------------------------------------
# [5] Poza: cele 4 cartonașe, desenate de ecranul adevărat de level up
# ---------------------------------------------------------------------------
# Rulează în FEREASTRĂ (fără --headless), altfel iese neagră.
func _sectiunea_5() -> void:
	print("\n--- [5] poza ---")
	TranslationServer.set_locale("en")
	for nr in PAGINI.size():
		await _arata(PAGINI[nr])
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(0.3).timeout
		var img := get_viewport().get_texture().get_image()
		var cale := "user://iteme_noi_%d.png" % (nr + 1)
		img.save_png(ProjectSettings.globalize_path(cale))
		var nume := []
		for u in _lvl._current:
			nume.append(u["nume"])
		print("  poza %d (%s): %s" % [nr + 1, ", ".join(nume), ProjectSettings.globalize_path(cale)])
		# dovadă că nu e o poză goală: cartonașele au chiar iconițele cerute
		for i in 3:
			var id: String = _lvl._current[i]["id"]
			if NOI.has(id):
				var t: Texture2D = _lvl._icons[i].texture
				_cer(t != null and t.get_width() > 0, "%s: iconița e pe cartonaș (%dx%d)" % [id, t.get_width() if t != null else 0, t.get_height() if t != null else 0])
	TranslationServer.set_locale(GameSettings.language)
