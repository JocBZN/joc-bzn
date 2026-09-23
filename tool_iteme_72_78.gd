extends Node2D

# UNEALTĂ de verificare pentru cele ȘAPTE ITEME NOI de pe 2026-09-23 (nu face parte din joc):
#
#   "<godot.exe>" --path <proiect> res://tool_iteme_72_78.tscn
#
# Se rulează ca SCENĂ (are nevoie de autoload-uri: I18n, GameSettings, Difficulty, Unlocks, Fx) și
# în FEREASTRĂ, nu headless: partea [5] face poze cu ecranul real de level up, iar headless
# randează negru.
#
# Ce verifică, în ordine:
#   [1] cele 7 iteme sunt în `levelup.UPGRADES`, cu iconița/raritatea/textul cerute, iconițele
#       chiar se încarcă, id-urile nu se repetă, „unic" doar unde trebuie;
#   [2] efectele, aplicate pe un player ADEVĂRAT prin `levelup._apply` (nu citite din sursă),
#       inclusiv stivuirea și podeaua de dificultate;
#   [3] busola lui Third Eye: `portals.cel_mai_apropiat` chiar întoarce cel mai apropiat portal
#       (comparat cu o căutare pe brânci), se schimbă la vârsta Ender, tace după `opreste()`,
#       iar HUD-ul aprinde săgeata doar cu itemul luat și o stinge în dimensiuni;
#   [4] traducerile: cele 14 chei noi există, au 8 traduceri nevide, iar numele/descrierea
#       ÎNCAP pe cartonaș în toate cele 9 limbi (numele se taie, descrierea se rupe la 2 rânduri);
#   [5] poza: trei pagini de level up desenate de codul adevărat, cu cele 7 cartonașe.

const NOI := ["sunglasses", "third_eye", "studio_mic", "diamond_watch", "sunscreen", "museum_piece", "skateboard"]
const ASTEPTAT := {
	"sunglasses":    {"icon": "upgrade_72.png", "rar": "rare",      "desc": "Reflect 25% of damage taken"},
	"third_eye":     {"icon": "upgrade_73.png", "rar": "epic",      "desc": "Reveal the closest portal"},
	"studio_mic":    {"icon": "upgrade_74.png", "rar": "rare",      "desc": "-10% Difficulty"},
	"diamond_watch": {"icon": "upgrade_75.png", "rar": "legendary", "desc": "75% less XP to level up"},
	"sunscreen":     {"icon": "upgrade_76.png", "rar": "common",    "desc": "+10 Max HP, +1 HP/sec"},
	"museum_piece":  {"icon": "upgrade_77.png", "rar": "rare",      "desc": "-10% Move speed +25% Crit chance"},
	"skateboard":    {"icon": "upgrade_78.png", "rar": "rare",      "desc": "+30 Movement Speed"},
}
const NUME := {
	"sunglasses": "Sunglasses", "third_eye": "Third Eye", "studio_mic": "Studio Mic",
	"diamond_watch": "Diamond Watch", "sunscreen": "Sunscreen", "museum_piece": "Museum Piece",
	"skateboard": "Skateboard",
}
# Singurul „unic" dintre ele: Third Eye e un COMUTATOR, a doua luare n-ar face nimic.
const UNICE := ["third_eye"]

var _err := 0
var _lvl: CanvasLayer = null
var _p: Node = null
var _world: Node2D = null
var _portals: Node2D = null

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

# Compararea numerelor cu virgulă: „egal" înseamnă „mai aproape de atât decât o miime".
func _cam(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps

func _ready() -> void:
	await get_tree().process_frame
	print("\n========== ITEMELE NOI (2026-09-23) ==========")
	Difficulty.reset_run()
	_lvl = CanvasLayer.new()
	_lvl.set_script(load("res://levelup.gd"))
	add_child(_lvl)
	await get_tree().process_frame

	_sectiunea_1()
	_fa_lumea()
	_sectiunea_2()
	await _sectiunea_3()
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
	print("\n--- [1] cele 7 iteme în listă ---")
	var vazute := {}
	var iconite := {}
	for u in _lvl.UPGRADES:
		if vazute.has(u["id"]):
			_fail("id repetat în UPGRADES: %s" % u["id"])
		vazute[u["id"]] = true
		if iconite.has(u["icon"]):
			_fail("iconiță folosită de două ori: %s (%s și %s)" % [u["icon"], iconite[u["icon"]], u["id"]])
		iconite[u["icon"]] = u["id"]
	_ok("%d iteme în pool, niciun id și nicio iconiță repetate" % _lvl.UPGRADES.size())

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
		_cer(u.get("unic", false) == UNICE.has(id), "%s: „unic” = %s" % [id, str(UNICE.has(id))])

# O lume de mentit: `World` cu player-ul și cu generatorul de portaluri, exact ca în `main.tscn`
# (`hud.gd::_portals_node` caută nodul „Portals" în PĂRINTELE player-ului).
# Player-ului îi oprim ceasul de tragere și `_process`: n-avem inamici, iar noi doar citim
# statusuri. Generatorului îi oprim `_process`: altfel ar construi 49 de chunk-uri de portaluri
# adevărate, de care n-avem nevoie — busola întreabă geometria, nu nodurile.
func _fa_lumea() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_p = load("res://player.tscn").instantiate()
	_world.add_child(_p)
	if _p.get("fire_timer") != null:
		_p.fire_timer.stop()
	_p.set_process(false)
	_p.set_physics_process(false)

	_portals = Node2D.new()
	_portals.name = "Portals"
	_portals.set_script(load("res://portals.gd"))
	_world.add_child(_portals)
	_portals.set_process(false)

# Aplică un item pe player prin drumul ADEVĂRAT din joc (`levelup._apply`), nu scriind în variabile.
func _ia(id: String) -> void:
	_lvl._apply(id, _p)

# ---------------------------------------------------------------------------
# [2] Efectele, pe player adevărat
# ---------------------------------------------------------------------------
func _sectiunea_2() -> void:
	print("\n--- [2] efectele ---")

	# --- SUNGLASSES: +25% reflexie, în același rezervor ca Old Reliable și Vodka ---
	var r0: float = _p.reflect_pct
	_ia("sunglasses")
	_cer(_cam(_p.reflect_pct, r0 + 0.25), "sunglasses: reflect_pct %.2f → %.2f" % [r0, _p.reflect_pct])
	_ia("sunglasses")
	_cer(_cam(_p.reflect_pct, r0 + 0.50), "sunglasses: se stivuiește (%.2f)" % _p.reflect_pct)
	_ia("old_reliable")
	_cer(_cam(_p.reflect_pct, r0 + 0.65), "sunglasses: se adună cu Old Reliable (%.2f)" % _p.reflect_pct)

	# --- THIRD EYE: comutator ---
	_cer(not bool(_p.third_eye), "third_eye: stins înainte de item")
	_ia("third_eye")
	_cer(bool(_p.third_eye), "third_eye: aprins după item")
	_ia("third_eye")
	_cer(bool(_p.third_eye), "third_eye: a doua luare nu strică nimic")

	# --- STUDIO MIC: -10% dificultate, înmulțit, cu podea ---
	Difficulty.reset_run()
	_ia("studio_mic")
	_cer(_cam(Difficulty.trade_penalty, 0.90), "studio_mic: trade_penalty 1.00 → %.4f" % Difficulty.trade_penalty)
	_ia("studio_mic")
	_cer(_cam(Difficulty.trade_penalty, 0.81), "studio_mic: se stivuiește înmulțit (%.4f)" % Difficulty.trade_penalty)
	# chiar ȘTERGE o carte de vrăjitorii: ×0,81 × 1,10 × 1,10 = ×0,98
	_ia("tome_witchcraft")
	_ia("tome_witchcraft")
	_cer(_cam(Difficulty.trade_penalty, 0.9801, 0.0005), "studio_mic: anulează cărțile de vrăjitorii (%.4f)" % Difficulty.trade_penalty)
	# podeaua: 40 de microfoane n-au voie să treacă de MIN_TRADE
	Difficulty.reset_run()
	for i in 40:
		_ia("studio_mic")
	_cer(_cam(Difficulty.trade_penalty, Difficulty.MIN_TRADE), "studio_mic: se oprește la podea (%.2f, MIN_TRADE %.2f)" % [Difficulty.trade_penalty, Difficulty.MIN_TRADE])
	# și inamicii chiar simt: viața lor la aceeași secundă scade cu exact atât
	Difficulty.reset_run()
	var hp_normal := Difficulty.enemy_hp_mult()
	var spawn_normal := Difficulty.spawn_mult()
	var xp_normal := Difficulty.xp_mult()
	_ia("studio_mic")
	_cer(_cam(Difficulty.enemy_hp_mult(), hp_normal * 0.90, 0.0005), "studio_mic: viața inamicilor ×0.90 (%.3f → %.3f)" % [hp_normal, Difficulty.enemy_hp_mult()])
	_cer(_cam(Difficulty.spawn_mult(), spawn_normal * 0.90, 0.0005), "studio_mic: câți apar ×0.90 (%.3f → %.3f)" % [spawn_normal, Difficulty.spawn_mult()])
	# ...dar XP-ul NU: `xp_mult` nu trece prin `trade_penalty`
	_cer(_cam(Difficulty.xp_mult(), xp_normal, 0.0005), "studio_mic: nu-ți taie XP-ul (%.3f)" % xp_normal)
	Difficulty.reset_run()

	# --- DIAMOND WATCH: 75% mai puțin XP până la nivel ---
	_p.xp_to_next = 200
	_ia("diamond_watch")
	_cer(_p.xp_to_next == 50, "diamond_watch: 200 → %d XP până la nivel" % _p.xp_to_next)
	_ia("diamond_watch")
	_cer(_p.xp_to_next == 12, "diamond_watch: se stivuiește (→ %d)" % _p.xp_to_next)
	_p.xp_to_next = 6
	_ia("diamond_watch")
	_cer(_p.xp_to_next == 5, "diamond_watch: podeaua de 5 XP ține (→ %d)" % _p.xp_to_next)

	# --- SUNSCREEN: +10 max HP (și te vindecă), +1 regen ---
	_p.hp = 1
	var max0: int = _p.max_hp
	var reg0: int = _p.hp_regen
	_ia("sunscreen")
	_cer(_p.max_hp == max0 + 10, "sunscreen: max HP %d → %d" % [max0, _p.max_hp])
	_cer(_p.hp_regen == reg0 + 1, "sunscreen: regen %d → %d/s" % [reg0, _p.hp_regen])
	_cer(_p.hp == 11, "sunscreen: te vindecă pe loc cu cele 10 (hp %d)" % _p.hp)
	_ia("sunscreen")
	_cer(_p.hp_regen == reg0 + 2, "sunscreen: regenul se adună (%d/s)" % _p.hp_regen)

	# --- MUSEUM PIECE: -10% viteză, +25% crit ---
	var sp0: float = _p.speed
	var cc0: float = _p.crit_chance
	_ia("museum_piece")
	_cer(_cam(_p.speed, sp0 * 0.90, 0.01), "museum_piece: viteza %.0f → %.0f" % [sp0, _p.speed])
	_cer(_cam(_p.crit_chance, cc0 + 0.25), "museum_piece: crit %.0f%% → %.0f%%" % [cc0 * 100.0, _p.crit_chance * 100.0])
	_ia("museum_piece")
	_cer(_cam(_p.speed, sp0 * 0.81, 0.01), "museum_piece: viteza e procent pe valoarea curentă (%.0f)" % _p.speed)
	_cer(_cam(_p.crit_chance, cc0 + 0.50), "museum_piece: criticul se adună (%.0f%%)" % (_p.crit_chance * 100.0))

	# --- SKATEBOARD: +30 viteză, valoare fixă ---
	var sp1: float = _p.speed
	_ia("skateboard")
	_cer(_cam(_p.speed, sp1 + 30.0, 0.01), "skateboard: viteza %.0f → %.0f" % [sp1, _p.speed])
	_ia("skateboard")
	_cer(_cam(_p.speed, sp1 + 60.0, 0.01), "skateboard: se stivuiește fix (%.0f)" % _p.speed)

# ---------------------------------------------------------------------------
# [3] Busola lui Third Eye
# ---------------------------------------------------------------------------
# Căutarea pe brânci, ca să avem cu ce compara: aceeași rază, dar întrebăm direct generatorul,
# fără cache și fără scurtături. Dacă `cel_mai_apropiat` minte, aici se vede.
func _brut(de_la: Vector2, ender: bool) -> Vector2:
	var cs: int = _portals.chunk_size
	var pc := Vector2i(floori(de_la.x / float(cs)), floori(de_la.y / float(cs)))
	var r: int = _portals.SCAN_CHUNKS
	var best := Vector2.INF
	var best_d := INF
	for cx in range(pc.x - r, pc.x + r + 1):
		for cy in range(pc.y - r, pc.y + r + 1):
			var key := Vector2i(cx, cy)
			var p: Vector2 = _portals.chunk_fantana_pos(key) if ender else _portals.chunk_portal_pos(key)
			if p == Vector2.INF:
				continue
			var d := de_la.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = p
	return best

const LOCURI := [Vector2(0, 0), Vector2(4000, -2500), Vector2(-12345, 6789), Vector2(99000, 99000)]

func _sectiunea_3() -> void:
	print("\n--- [3] busola spre cel mai apropiat portal ---")

	# 3a. întoarce chiar CEL MAI APROPIAT portal, în mai multe locuri din lume
	var gasite := 0
	for loc in LOCURI:
		var a: Vector2 = _portals.cel_mai_apropiat(loc)
		var b := _brut(loc, false)
		_cer(a == b, "portal lângă %s: %s (căutarea pe brânci dă %s)" % [str(loc), str(a), str(b)])
		if a != Vector2.INF:
			gasite += 1
	_cer(gasite >= 3, "%d din %d locuri au un portal în rază (raza: %d chunk-uri)" % [gasite, LOCURI.size(), _portals.SCAN_CHUNKS])

	# 3b. a doua chemare vine din cache, dar dă ACELAȘI răspuns
	for loc in LOCURI:
		_cer(_portals.cel_mai_apropiat(loc) == _brut(loc, false), "cache: același răspuns la a doua chemare (%s)" % str(loc))

	# 3c. HUD-ul: săgeata apare doar cu itemul luat, arată spre ținta găsită, și se stinge
	#     în dimensiuni (acolo Nether/Ender au busola lor).
	var hud := CanvasLayer.new()
	hud.set_script(load("res://hud.gd"))
	add_child(hud)
	await get_tree().process_frame
	_p.global_position = Vector2.ZERO
	var tinta: Vector2 = _portals.cel_mai_apropiat(_p.global_position)

	_p.third_eye = false
	hud._update_third_eye(_p, 1.0)
	_cer(not hud._te_arrow.visible, "HUD: fără item, săgeata nu apare")

	_p.third_eye = true
	hud._update_third_eye(_p, 1.0)
	_cer(hud._te_tinta == tinta, "HUD: ținta e portalul găsit de generator (%s)" % str(hud._te_tinta))
	if tinta != Vector2.INF:
		# aceeași socoteală ca în HUD: pe ecran → n-are rost săgeata; în afara lui → apare
		var vp := get_viewport().get_visible_rect().size
		var scr: Vector2 = get_viewport().get_canvas_transform() * tinta
		var m: float = hud.TE_MARGIN
		var pe_ecran := scr.x > m and scr.x < vp.x - m and scr.y > m and scr.y < vp.y - m
		_cer(hud._te_arrow.visible == not pe_ecran, "HUD: săgeata %s (portalul e %s ecran)" % ["se vede" if hud._te_arrow.visible else "e stinsă", "pe" if pe_ecran else "în afara"])
		if not pe_ecran:
			_cer(hud._te_dist.text == "%d" % int(_p.global_position.distance_to(tinta)), "HUD: scrie distanța (%s px)" % hud._te_dist.text)
			# săgeata stă ÎN chenar, nu pe lângă ecran
			var c: Vector2 = hud._te_arrow.position + Vector2(hud.TE_ARROW, hud.TE_ARROW) * 0.5
			_cer(c.x >= m - 1.0 and c.x <= vp.x - m + 1.0 and c.y >= m - 1.0 and c.y <= vp.y - m + 1.0, "HUD: săgeata stă pe chenar (%s, ecran %s)" % [str(c.round()), str(vp)])
			# și o poză: verificările de mai sus spun unde STĂ săgeata, poza spune că chiar se VEDE
			# (glifa „▲" desenată, violetul peste fundal, cifra distanței sub ea).
			await RenderingServer.frame_post_draw
			await get_tree().create_timer(0.2).timeout
			var cale := "user://third_eye_busola.png"
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(cale))
			print("  poza busolei: %s" % ProjectSettings.globalize_path(cale))

	# într-o dimensiune se stinge: prefacem că suntem în Nether
	var s := GDScript.new()
	s.source_code = "extends Node\nvar active := true\n"
	s.reload()
	var fals := Node.new()
	fals.set_script(s)
	fals.add_to_group("nether")
	add_child(fals)
	hud._update_third_eye(_p, 1.0)
	_cer(not hud._te_arrow.visible, "HUD: în Nether săgeata se stinge (busola de acolo are prioritate)")
	fals.free()

	# 3d. vârsta ENDER: aceleași chunk-uri, alte locuri — și cache-ul se golește odată cu ele
	_portals.treci_pe_ender()
	_cer(_portals._cache_busola.is_empty(), "trecerea pe Ender golește cache-ul busolei")
	var dif := 0
	for loc in LOCURI:
		var a: Vector2 = _portals.cel_mai_apropiat(loc)
		_cer(a == _brut(loc, true), "fântână lângă %s: %s" % [str(loc), str(a)])
		if a != _brut(loc, false):
			dif += 1
	_cer(dif >= 3, "fântânile Ender sunt în ALTE locuri decât portalurile (%d din %d)" % [dif, LOCURI.size()])

	# 3e. după Celesto generatorul tace, deci și busola
	_portals.opreste()
	var tac := true
	for loc in LOCURI:
		if _portals.cel_mai_apropiat(loc) != Vector2.INF:
			tac = false
	_cer(tac, "după `opreste()` busola nu mai arată nimic")
	hud._update_third_eye(_p, 1.0)
	_cer(not hud._te_arrow.visible, "HUD: fără portaluri, săgeata e stinsă")
	hud.queue_free()
	await get_tree().process_frame

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
	["sunglasses", "third_eye", "studio_mic"],
	["diamond_watch", "sunscreen", "museum_piece"],
	["skateboard", "sunglasses", "diamond_watch"],
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
	_cer(probleme == 0, "cele 7 iteme încap pe cartonaș în toate cele %d limbi" % I18n.LIMBI.size())

# ---------------------------------------------------------------------------
# [5] Poza: cele 7 cartonașe, desenate de ecranul adevărat de level up
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
		var cale := "user://iteme_72_78_%d.png" % (nr + 1)
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
