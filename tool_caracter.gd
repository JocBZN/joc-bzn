extends Node

# UNEALTA care verifica CARACTERELE (`player.gd::CARACTERE` + pagina CHOOSE CHARACTER).
#
#   godot --headless --path <proj> res://tool_caracter.tscn
#
# Verifica patru lucruri, fiindca fiecare se strica IN TACERE:
#
#   1. ARTA. Fiecare caracter are toate cele 16 animatii pe care le cere `player.gd::_update_anim`
#      (8 directii + `idle_` x 8). Daca lipseste una, jocul nu crapa: `AnimatedSprite2D.play()`
#      cu un nume inexistent doar nu face nimic, si personajul INGHEATA cand se intoarce intr-acolo.
#
#   2. TALPILE. Distanta de la mijlocul panzei pana la talpa trebuie sa fie ACEEASI la toate
#      directiile ale unui caracter (altfel salta cand se intoarce) SI intre caractere (altfel
#      unul pluteste si celalalt intra in pamant, si se vede doar comparand cu umbra).
#
#   3. XP-ul. Pragurile chiar ies mai mici la Spellman, si exact cu cat scrie in tabelul din
#      `player.gd`. Se masoara RULAND `_level_up` de-adevaratelea, nu recalculand formula aici —
#      o formula copiata ar fi trecut testul si cu jocul stricat.
#
#   4. CHEILE. Sansa lui Jordan chiar ajunge la inamici: se CERE unui inamic adevarat, prin
#      `enemy.gd::_sansa_cheie()`. Firul player -> inamic e singurul loc unde bonusul asta poate
#      sa se rupa, si s-ar rupe mut: nu crapa nimic, doar cad chei ca la toata lumea.
#
#   5. DAMAGE-UL. Bonusul lui Liu Xiang (+1% pe nivel) se masoara pe un player ADEVARAT, prin
#      `damage_mult()` — adica exact functia pe care o citeste fiecare glont. Se verifica si ca
#      se ADUNA cu bonusul sabiei (amandoua sunt "+1% damage / nivel", din doua surse diferite).
#
#   6. DEBLOCAREA. 100 damage intr-o runda il deblocheaza CU ADEVARAT, prin
#      `Unlocks.verifica_statusuri(p)` — aceeasi functie pe care o cheama `player.gd::_process`.
#      Si ca deblocarea lui NU inghite pancarta sabiei: amandoua cer acelasi prag, deci pica in
#      acelasi cadru, iar `hud.announce` scrie peste pancarta dinainte.
#
# ⚠️ Liu Xiang e INCUIAT intr-o salvare obisnuita, iar `_aplica_caracter` cade inapoi pe The G
# pentru un caracter necastigat — deci probele de mai sus l-ar fi masurat pe The G si ar fi trecut
# toate. De-asta unealta aprinde `op_start` in RAM cat tine masuratoarea si-l stinge inainte de
# orice scriere pe disc.
# ⚠️ NU moare nimeni si nu se scrie nimic in `user://scores.save`: `GameSettings.character` se
# schimba doar in RAM si se pune la loc la sfarsit. Tipareste si ce-a ramas in fisier, ca sa se
# vada. (Capcana din CLAUDE.md: un test care atinge GameSettings poate ajunge in salvarea reala.)

const PLAYER := preload("res://player.gd")
const ENEMY := preload("res://enemy.gd")
const DIRECTII := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]

# Cat salt vertical e voie fiecarui caracter, in pixeli DE SPRITE (player-ul e la `scale = 2` in
# `main.tscn`, deci pe ecran se dubleaza).
#
# ⚠️ Nu e un prag rotund, ales din burta: e o DATORIE scrisa pe fata. Un caracter trecut prin
# `tool_aliniaza_talpi.gd` iese pe 0 — de-asta implicitul, pentru orice caracter nou, e 0.
#
# `grasu` are 5 fiindca ASA A VENIT, de dinainte de caractere: cele patru poze de stat pe loc
# (`grasu directii/rotations/*.png`) sunt desenate cu talpa cu pana la 5px mai sus decat cadrele
# lui de mers, deci The G se ridica vreo 10px pe ecran cand se opreste din fugit. Se repara
# intr-o singura rulare a uneltei de aliniere, dar aia MUTA personajul vechi sub picioarele lui
# Razvan si nimeni n-a cerut-o — deci deocamdata e scrisa aici, nu ascunsa.
const SALT_MAXIM := {
	"grasu": 5.0,
	"spellman": 0.0,
	"jordan": 0.0,
}
const SALT_IMPLICIT := 0.0

func _salt_voie(id: String) -> float:
	return float(SALT_MAXIM.get(id, SALT_IMPLICIT))

var _erori := 0
var _caracter_initial := ""
# Ce am imprumutat din `GameSettings` si trebuie pus inapoi INAINTE de orice `_save()`.
# `unlocked` se DUPLICA: e un Dictionary, deci o referinta ar fi fost acelasi obiect pe care
# `Unlocks.deblocheaza` il modifica sub noi, si "copia" ar fi fost la fel de stricata.
var _op_initial := false
var _unlocked_initial := {}
var _arma_initiala := ""

func _ready() -> void:
	_caracter_initial = GameSettings.character
	_op_initial = GameSettings.op_start
	_unlocked_initial = GameSettings.unlocked.duplicate()
	_arma_initiala = GameSettings.weapon_type
	print("(caracterul salvat, inainte de test: `%s`)" % _caracter_initial)
	# Cat tin masuratorile, TOTUL e deblocat — altfel `_aplica_caracter` cade pe The G pentru
	# orice caracter necastigat si probele l-ar masura pe el, trecand senine. Numai in RAM:
	# `op_start` e un comutator care nu scrie nimic de la sine (vezi `unlocks.gd`), iar inainte
	# de fiecare `_save()` al uneltei se pune la loc.
	GameSettings.op_start = true

	print("\n--- [1] arta: cele 16 animatii ---")
	var talpi := {}
	for id in PLAYER.CARACTERE:
		talpi[id] = _verifica_arta(id)

	print("\n--- [2] talpile, intre caractere ---")
	# Comparatie CAP LA CAP, pe aceeasi animatie (`south`, fuga spre camera — poza in care se
	# vede player-ul cel mai des). Nu se compara "cea mai de jos talpa a fiecaruia": aia amesteca
	# datoria veche a lui The G (`SALT_MAXIM`) cu potriveala dintre caractere, si atunci proba ar
	# spune "difera" fara sa spuna de ce. Aici, daca cifrele nu-s egale, un caracter chiar sta pe
	# alt pamant decat celalalt.
	var talpa_sud := {}
	for id in PLAYER.CARACTERE:
		var v := _talpa_animatiei(id, "south")
		if v > -9000.0:
			talpa_sud[id] = v
			print("  %-10s pe `south`: centru->talpa %.1f" % [id, v])
	if talpa_sud.size() < PLAYER.CARACTERE.size():
		_cer(false, "s-au putut masura talpile la toate caracterele")
	else:
		var v2: Array = talpa_sud.values()
		var mn: float = v2.min()
		var mx: float = v2.max()
		_cer(is_equal_approx(mn, mx),
			"toate caracterele calca la aceeasi inaltime (%.1f..%.1f)" % [mn, mx])

	print("\n--- [3] pragul de XP, masurat ruland `_level_up` ---")
	await _verifica_xp()

	print("\n--- [4] sansa de chei, ceruta de un inamic adevarat ---")
	await _verifica_chei()

	print("\n--- [5] damage-ul lui Liu Xiang, masurat pe un player adevarat ---")
	await _verifica_damage()

	print("\n--- [6] deblocarea: 100 damage intr-o runda ---")
	await _verifica_deblocarea()

	print("\n--- [7] pagina CHOOSE CHARACTER ---")
	await _verifica_meniul()

	GameSettings.character = _caracter_initial
	_gata()


func _verifica_arta(id: String) -> Array:
	var c: Dictionary = PLAYER.CARACTERE[id]
	var cale := String(c["frames"])
	if not ResourceLoader.exists(cale):
		_cer(false, "%s: lipseste `%s`" % [id, cale])
		return []
	var sf: SpriteFrames = load(cale)
	if sf == null:
		_cer(false, "%s: `%s` nu e SpriteFrames" % [id, cale])
		return []
	var lipsa := []
	for d in DIRECTII:
		if not sf.has_animation(d):
			lipsa.append(d)
		if not sf.has_animation("idle_" + d):
			lipsa.append("idle_" + d)
	_cer(lipsa.is_empty(), "%s: are toate cele 16 animatii%s"
		% [id, "" if lipsa.is_empty() else "  LIPSESC: " + str(lipsa)])

	# toate directiile de MERS trebuie sa aiba acelasi numar de cadre: `_update_anim` duce
	# `frame` + `frame_progress` de la o directie la alta cand te intorci din mers.
	var cadre := {}
	for d in DIRECTII:
		if sf.has_animation(d):
			cadre[sf.get_frame_count(d)] = true
	_cer(cadre.size() == 1, "%s: toate directiile de mers au acelasi numar de cadre (%s)"
		% [id, str(cadre.keys())])

	# ⚠️ Talpa unei DIRECTII e cea mai de jos linie opaca din TOATE cadrele ei, nu din cadrul 0:
	# in interiorul unei directii cadrele difera intre ele fiindca asa e leganatul mersului, iar
	# aia e intentia desenatorului. Exact ce masoara si `tool_aliniaza_talpi.gd`. Masurata pe
	# cadrul 0, proba asta "pica" si pe arta perfect aliniata (m-a prins pe 2026-09-02).
	var fata := []
	for d in DIRECTII:
		for nume in [d, "idle_" + d]:
			if not sf.has_animation(nume) or sf.get_frame_count(nume) == 0:
				continue
			var jos := -9999.0
			for i in sf.get_frame_count(nume):
				var tex: Texture2D = sf.get_frame_texture(nume, i)
				if tex != null:
					jos = maxf(jos, _centru_talpa(tex.get_image()))
			if jos > -9000.0:
				fata.append(jos)
	if fata.is_empty():
		return []
	var mn: float = fata.min()
	var mx: float = fata.max()
	# Voia e pe caracter, nu una singura pentru toti: vezi `SALT_MAXIM`.
	var voie := _salt_voie(id)
	_cer(mx - mn <= voie,
		"%s: nu salta la intoarcere (centru->talpa %.1f..%.1f = salt %.1f, voie %.1f)"
		% [id, mn, mx, mx - mn, voie])
	return [mn, mx]


# Talpa unei animatii anume: cea mai de jos linie opaca din toate cadrele ei.
func _talpa_animatiei(id: String, nume: String) -> float:
	var c: Dictionary = PLAYER.CARACTERE.get(id, {})
	var cale := String(c.get("frames", ""))
	if not ResourceLoader.exists(cale):
		return -9999.0
	var sf: SpriteFrames = load(cale)
	if sf == null or not sf.has_animation(nume):
		return -9999.0
	var jos := -9999.0
	for i in sf.get_frame_count(nume):
		var tex: Texture2D = sf.get_frame_texture(nume, i)
		if tex != null:
			jos = maxf(jos, _centru_talpa(tex.get_image()))
	return jos


# Cati pixeli sub MIJLOCUL panzei cade talpa. Asta ajunge pe ecran: `AnimatedSprite2D` centreaza
# textura, deci numarul asta e cat sta personajul sub punctul lui de pozitie.
func _centru_talpa(img: Image) -> float:
	if img == null:
		return -9999.0
	var jos := -1
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				jos = y
				break
		if jos >= 0:
			break
	if jos < 0:
		return -9999.0
	return float(jos + 1) - float(img.get_height()) * 0.5


# Pragurile ADEVARATE: instantiem player-ul cu fiecare caracter si ii dam niveluri.
const ASTEPTAT := {
	"grasu":    {1: 20, 5: 39, 10: 94, 15: 230, 20: 571},
	"spellman": {1: 20, 5: 29, 10: 51, 15: 92,  20: 171},
	# Jordan n-are bonus de XP, deci trebuie sa iasa CIFRA CU CIFRA ca The G. Nu e o dublare
	# inutila a randului de sus: daca cineva pune din greseala un `xp_pe_nivel` si pe el, aici se
	# vede imediat.
	"jordan":   {1: 20, 5: 39, 10: 94, 15: 230, 20: 571},
	# La fel si Liu Xiang: bonusul lui e pe damage, nu pe XP.
	"liu":      {1: 20, 5: 39, 10: 94, 15: 230, 20: 571},
}

func _verifica_xp() -> void:
	var praguri := {}
	for id in PLAYER.CARACTERE:
		praguri[id] = await _masoara_praguri(id)
	print("  nivel   " + "".join(PLAYER.CARACTERE.keys().map(func(k): return "%-10s" % k)))
	for L in [1, 5, 10, 15, 20]:
		var rand := "  %-8d" % L
		for id in praguri:
			rand += "%-10d" % int(praguri[id].get(L, -1))
		print(rand)
	for id in praguri:
		var ok := true
		var rele := []
		for L in ASTEPTAT.get(id, {}):
			if int(praguri[id].get(L, -1)) != int(ASTEPTAT[id][L]):
				ok = false
				rele.append("nivel %d: %d in loc de %d" % [L, int(praguri[id].get(L, -1)), int(ASTEPTAT[id][L])])
		_cer(ok, "%s: pragurile sunt cele din tabelul lui `player.gd`%s"
			% [id, "" if ok else "  " + str(rele)])
	if praguri.has("grasu") and praguri.has("spellman"):
		_cer(int(praguri["spellman"][20]) < int(praguri["grasu"][20]) * 0.35,
			"spellman are la nivelul 20 sub 35%% din pragul lui The G (%d vs %d)"
			% [int(praguri["spellman"][20]), int(praguri["grasu"][20])])
		_cer(int(praguri["spellman"][1]) == int(praguri["grasu"][1]),
			"la nivelul 1 pornesc de la acelasi prag (bonusul se ADUNA pe parcurs, nu e din start)")

func _masoara_praguri(id: String) -> Dictionary:
	GameSettings.character = id
	var p: Node = load("res://player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	_cer(p.caracter == id, "%s: player-ul chiar l-a luat pe el (`caracter` = `%s`)" % [id, p.caracter])
	var iesire := {1: p.xp_to_next}
	for L in range(2, 21):
		p._level_up(false)   # fara sunet: 20 de jingle-uri suprapuse n-ajuta pe nimeni
		iesire[L] = p.xp_to_next
	p.queue_free()
	await get_tree().process_frame
	return iesire


# Pagina reala din meniu, construita de-adevaratelea. Verifica si ca lista de acolo si tabelul
# din `player.gd` vorbesc despre aceleasi personaje — doua liste, doua locuri de uitat.
func _verifica_meniul() -> void:
	# Pagina se construieste cu lacatele ADEVARATE (`op_start` inapoi cum era): altfel Liu Xiang
	# ar fi aparut deblocat si proba de mai jos n-ar fi masurat nimic.
	GameSettings.op_start = _op_initial
	var m: Node = load("res://menu.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame

	var id_meniu := []
	for c in m.CHARACTERS:
		id_meniu.append(String(c["id"]))
	var id_cod := PLAYER.CARACTERE.keys()
	id_meniu.sort()
	id_cod.sort()
	_cer(id_meniu == id_cod, "meniul si `CARACTERE` au aceleasi personaje (%s / %s)" % [str(id_meniu), str(id_cod)])

	_cer(m._character_buttons.size() == m.CHARACTERS.size(),
		"pagina are cate un rand de fiecare personaj (%d)" % m._character_buttons.size())
	_cer(not m._character_detail.is_empty(), "fisa din dreapta exista")

	# portretele: decupajul trebuie sa fie o fereastra REALA, nu una goala sau cat toata panza
	for c in m.CHARACTERS:
		var t = m._portret(String(c["icon"]))
		var bun: bool = t is AtlasTexture and t.region.size.x > 8 and t.region.size.y > 8
		_cer(bun, "%s: portretul e decupat pe silueta (%s)"
			% [String(c["id"]), str(t.region.size) if t is AtlasTexture else "necuprins"])

	# textul bonusului, facut din cifra reala
	_cer(m._bonus_caracter("grasu") == "NO BONUS STATS",
		"The G scrie `NO BONUS STATS` (scrie `%s`)" % m._bonus_caracter("grasu"))
	var s: String = m._bonus_caracter("spellman")
	_cer(s.contains("5") and s.to_upper().contains("XP"),
		"Spellman isi scrie bonusul din cifra din cod (`%s`)" % s)
	var l: String = m._bonus_caracter("liu")
	_cer(l.contains("1") and l.to_upper().contains("DAMAGE"),
		"Liu Xiang isi scrie bonusul din cifra din cod (`%s`)" % l)

	# Lacatul lui: e singurul personaj necastigat in salvarea obisnuita, iar cerinta care se vede
	# in fisa trebuie sa fie chiar cea din `unlocks.gd`, nu un text scris a doua oara in meniu.
	_cer(Unlocks.CERINTE.has("liu"), "Liu Xiang are o cerinta de deblocare in `unlocks.gd`")
	_cer(Unlocks.cerinta("liu") == Unlocks.cerinta("sword"),
		"cerinta lui e aceeasi cu a sabiei (`%s`)" % Unlocks.cerinta("liu"))
	_cer(Unlocks.nume("liu") == "LIU XIANG",
		"pancarta de deblocare ii stie numele din `menu.gd` (`%s`)" % Unlocks.nume("liu"))

	# Alegerea chiar ajunge in GameSettings. ⚠️ `_on_character_chosen` SALVEAZA pe disc, deci
	# punem la loc IMEDIAT, nu abia in `_gata`: daca unealta se opreste intre timp (o eroare, un
	# Ctrl+C), altfel ii ramane lui Razvan alt personaj ales in salvarea REALA. M-a prins pe
	# 2026-09-02 — o rulare cazuta la mijloc lasase `spellman` in fisier.
	m._on_character_chosen("spellman")
	var s_ales := GameSettings.character
	GameSettings.character = _caracter_initial
	GameSettings._save()
	_cer(s_ales == "spellman", "clic pe un personaj il si alege")
	m.queue_free()
	await get_tree().process_frame


func _cer(bun: bool, ce: String) -> void:
	if bun:
		print("  ok  %s" % ce)
	else:
		_erori += 1
		print("  XX  %s" % ce)

func _gata() -> void:
	# ⚠️ ce a ramas pe disc: `_on_character_chosen` SALVEAZA, si tot asa `Unlocks.deblocheaza`
	# din proba [6]. Punem la loc TOT ce-am imprumutat si salvam inapoi, apoi aratam rezultatul.
	GameSettings.character = _caracter_initial
	GameSettings.op_start = _op_initial
	GameSettings.unlocked = _unlocked_initial.duplicate()
	GameSettings.weapon_type = _arma_initiala
	GameSettings._save()
	var f := FileAccess.open("user://scores.save", FileAccess.READ)
	var scris := "?"
	var lacate := "?"
	if f != null:
		var d = f.get_var()
		if d is Dictionary:
			scris = String(d.get("character", "(lipseste)"))
			lacate = str(d.get("unlocked", "(lipseste)"))
	print("\n(caracterul ramas in salvare: `%s` — trebuie sa fie `%s`)" % [scris, _caracter_initial])
	print("(deblocarile ramase in salvare: %s)" % lacate)
	if scris != _caracter_initial:
		_erori += 1
		print("  XX  testul a lasat alt caracter in salvarea reala")
	if lacate != str(_unlocked_initial):
		_erori += 1
		print("  XX  testul a lasat alte deblocari in salvarea reala (erau %s)" % str(_unlocked_initial))
	if _erori == 0:
		print("\nTOTUL E BINE")
	else:
		print("\n%d PROBLEME" % _erori)
	get_tree().quit()


# Sansa de cheie NU se citeste din tabel si nu se recalculeaza aici: se CERE unui inamic
# adevarat, prin `enemy.gd::_sansa_cheie()`, adica exact functia care hotaraste la fiecare
# moarte. O verificare care ar fi comparat `CARACTERE` cu ea insasi ar fi trecut si cu firul
# rupt intre player si inamic.
func _verifica_chei() -> void:
	for id in PLAYER.CARACTERE:
		GameSettings.character = id
		var p: Node = load("res://player.tscn").instantiate()
		add_child(p)
		var e: Node = load("res://enemy.tscn").instantiate()
		add_child(e)
		await get_tree().process_frame
		var acum := float(e._sansa_cheie())
		var asteptat := float(PLAYER.CARACTERE[id].get("sansa_cheie", ENEMY.KEY_CHANCE))
		_cer(is_equal_approx(acum, asteptat),
			"%s: inamicul foloseste %.4f (%.2f%%), asteptat %.4f" % [id, acum, acum * 100.0, asteptat])
		if id == "jordan":
			_cer(acum > ENEMY.KEY_CHANCE,
				"jordan chiar scoate mai multe chei decat implicitul (%.4f > %.4f, de %.0fx)"
				% [acum, ENEMY.KEY_CHANCE, acum / ENEMY.KEY_CHANCE])
		e.queue_free()
		p.queue_free()
		await get_tree().process_frame
	# si invers: fara niciun player in scena, inamicul cade pe rata lui, nu pe zero
	var e2: Node = load("res://enemy.tscn").instantiate()
	add_child(e2)
	await get_tree().process_frame
	_cer(is_equal_approx(float(e2._sansa_cheie()), ENEMY.KEY_CHANCE),
		"fara player in scena, inamicul ramane pe KEY_CHANCE (%.4f)" % float(e2._sansa_cheie()))
	e2.queue_free()
	await get_tree().process_frame


# Bonusul de damage, CERUT lui `damage_mult()` — adica exact functia pe care o citeste fiecare
# glont la fiecare lovitura. Nu se recalculeaza formula aici: una copiata ar fi trecut proba si
# cu firul rupt intre `CARACTERE` si player.
#
# Se masoara DIFERENTA fata de nivelul 1, nu valoarea bruta: `damage_mult()` porneste de la
# `1.0 + cig_bonus`, iar `cig_bonus` poate veni din upgrade-urile permanente ale lui Razvan.
# Proba trebuie sa masoare bonusul, nu salvarea de pe masina asta.
func _verifica_damage() -> void:
	var la_nivelul_1 := {}
	for id in PLAYER.CARACTERE:
		var asteptat := float(PLAYER.CARACTERE[id].get("dmg_pe_nivel", 0.0))
		var m := await _masoara_damage(id, "pistol")
		if m.is_empty():
			continue
		la_nivelul_1[id] = m[1]
		var ok := true
		var rele := []
		for L in [1, 5, 10, 20]:
			var crestere: float = m[L] - m[1]
			var trebuie: float = (L - 1) * asteptat
			if absf(crestere - trebuie) > 0.0001:
				ok = false
				rele.append("nivel %d: +%.4f in loc de +%.4f" % [L, crestere, trebuie])
		_cer(ok, "%s: damage-ul creste cu %.0f%%/nivel%s"
			% [id, asteptat * 100.0, "" if ok else "  " + str(rele)])

	# Cat de mult e "+1%/nivel" fata de nimic, cap la cap, cu aceeasi arma.
	if la_nivelul_1.has("liu") and la_nivelul_1.has("grasu"):
		var d: float = la_nivelul_1["liu"] - la_nivelul_1["grasu"]
		_cer(absf(d - 0.01) < 0.0001,
			"liu are la nivelul 1 exact +1%% fata de The G (+%.4f)" % d)

	# Se ADUNA cu bonusul sabiei: amandoua sunt "+1% damage / nivel", dar una vine din arma si
	# cealalta din caracter. Daca cineva le-ar scrie vreodata in acelasi loc, aici se vede.
	var cu_sabie := await _masoara_damage("liu", "sword")
	var fara := await _masoara_damage("grasu", "sword")
	if not cu_sabie.is_empty() and not fara.is_empty():
		var c20: float = cu_sabie[20] - cu_sabie[1]
		var f20: float = fara[20] - fara[1]
		_cer(absf(c20 - 0.38) < 0.0001 and absf(f20 - 0.19) < 0.0001,
			"liu cu Cursed Sword urca cu 2%%/nivel, The G cu 1%% (+%.2f vs +%.2f pana la nivelul 20)"
			% [c20, f20])


func _masoara_damage(id: String, arma: String) -> Dictionary:
	GameSettings.character = id
	GameSettings.weapon_type = arma
	var p: Node = load("res://player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	if p.caracter != id:
		_cer(false, "%s: player-ul a pornit ca `%s` — masuratoarea ar fi fost a altcuiva" % [id, p.caracter])
		p.queue_free()
		await get_tree().process_frame
		return {}
	var iesire := {1: float(p.damage_mult())}
	for L in range(2, 21):
		p._level_up(false)
		iesire[L] = float(p.damage_mult())
	p.queue_free()
	await get_tree().process_frame
	GameSettings.weapon_type = _arma_initiala
	return iesire


# HUD de carton: `hud.announce` e singurul lucru pe care `Unlocks` il cere de la HUD, deci atat
# ii dam — si tine minte ce a primit, ca sa se poata NUMARA pancartele. Un HUD adevarat ar fi
# adus cu el toata scena de joc; grupa "hud" e tot ce conteaza pentru proba.
const HUD_FALS := """
extends Node
var primite: Array[String] = []
func announce(text: String, sub: String = \"\", culoare: Color = Color.WHITE) -> void:
	primite.append(sub)
"""

# Deblocarea, ceruta functiei ADEVARATE (`Unlocks.verifica_statusuri`), aceeasi pe care o cheama
# `player.gd::_process` de doua ori pe secunda.
#
# ⚠️ `deblocheaza()` SCRIE pe disc. Punem `unlocked` la loc IMEDIAT dupa proba, nu abia in
# `_gata()`: o rulare cazuta la mijloc i-ar fi lasat lui Razvan un personaj castigat pe degeaba.
func _verifica_deblocarea() -> void:
	var hud := Node.new()
	var s := GDScript.new()
	s.source_code = HUD_FALS
	s.reload()
	hud.set_script(s)
	hud.add_to_group("hud")
	add_child(hud)

	GameSettings.unlocked = {}     # doar in RAM; nimic nu s-a scris inca
	GameSettings.character = "liu"
	var p: Node = load("res://player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame

	# sub prag: nimic nu se deblocheaza
	p.bullet_damage = 10
	Unlocks.verifica_statusuri(p)
	_cer(not Unlocks.e_castigat("liu"), "sub 100 damage, Liu Xiang ramane incuiat")

	# peste prag: se deblocheaza el SI sabia, fiindca amandoua cer acelasi lucru
	p.bullet_damage = int(ceil(100.0 / p.damage_mult()))
	var damage_vazut := int(round(p.bullet_damage * p.damage_mult()))
	Unlocks.verifica_statusuri(p)
	_cer(Unlocks.e_castigat("liu"), "la %d damage, Liu Xiang se deblocheaza" % damage_vazut)
	_cer(Unlocks.e_castigat("sword"), "acelasi prag deblocheaza si Cursed Sword (%d)" % damage_vazut)

	# Pancartele: una peste alta s-ar fi vazut doar ultima. Coada le scoate pe rand, deci dupa
	# doua pancarte intregi HUD-ul trebuie sa fi primit AMANDOUA numele.
	await get_tree().create_timer(Unlocks.PANCARTA * 2.0 + 0.3).timeout
	_cer(hud.primite.size() == 2,
		"amandoua deblocarile ajung pe ecran, una dupa alta (%s)" % str(hud.primite))

	p.queue_free()
	hud.queue_free()
	await get_tree().process_frame
	# INAPOI pe disc, pe loc.
	GameSettings.unlocked = _unlocked_initial.duplicate()
	GameSettings.character = _caracter_initial
	GameSettings.op_start = _op_initial
	GameSettings._save()
	GameSettings.op_start = true   # restul probelor au iar nevoie de tot deblocat
