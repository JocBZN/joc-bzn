extends Node

# UNEALTA care verifica CARACTERELE (`player.gd::CARACTERE` + pagina CHOOSE CHARACTER).
#
#   godot --headless --path <proj> res://tool_caracter.tscn
#
# Verifica trei lucruri, fiindca fiecare se strica IN TACERE:
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
# ⚠️ NU moare nimeni si nu se scrie nimic in `user://scores.save`: `GameSettings.character` se
# schimba doar in RAM si se pune la loc la sfarsit. Tipareste si ce-a ramas in fisier, ca sa se
# vada. (Capcana din CLAUDE.md: un test care atinge GameSettings poate ajunge in salvarea reala.)

const PLAYER := preload("res://player.gd")
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
}
const SALT_IMPLICIT := 0.0

func _salt_voie(id: String) -> float:
	return float(SALT_MAXIM.get(id, SALT_IMPLICIT))

var _erori := 0
var _caracter_initial := ""

func _ready() -> void:
	_caracter_initial = GameSettings.character
	print("(caracterul salvat, inainte de test: `%s`)" % _caracter_initial)

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

	print("\n--- [4] pagina CHOOSE CHARACTER ---")
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

	# alegerea chiar ajunge in GameSettings
	m._on_character_chosen("spellman")
	_cer(GameSettings.character == "spellman", "clic pe un personaj il si alege")
	m.queue_free()
	await get_tree().process_frame


func _cer(bun: bool, ce: String) -> void:
	if bun:
		print("  ok  %s" % ce)
	else:
		_erori += 1
		print("  XX  %s" % ce)

func _gata() -> void:
	# ⚠️ ce a ramas pe disc: `_on_character_chosen` SALVEAZA, deci testul chiar a scris in
	# `scores.save`. Punem la loc ce era si salvam inapoi, apoi aratam rezultatul.
	GameSettings.character = _caracter_initial
	GameSettings._save()
	var f := FileAccess.open("user://scores.save", FileAccess.READ)
	var scris := "?"
	if f != null:
		var d = f.get_var()
		if d is Dictionary:
			scris = String(d.get("character", "(lipseste)"))
	print("\n(caracterul ramas in salvare: `%s` — trebuie sa fie `%s`)" % [scris, _caracter_initial])
	if scris != _caracter_initial:
		_erori += 1
		print("  XX  testul a lasat alt caracter in salvarea reala")
	if _erori == 0:
		print("\nTOTUL E BINE")
	else:
		print("\n%d PROBLEME" % _erori)
	get_tree().quit()
