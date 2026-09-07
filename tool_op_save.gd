extends Node2D

# UNEALTĂ: cele trei lucruri cerute pe 2026-09-07 — proiectilele de la OP START, deblocările
# pe care le deschide OP-ul, și pagina SAVE din Settings (UNLOCK ALL + DELETE SAVE FILE).
#
# Partea 1 (joc): pune un player și trei inamici falși în jurul lui, trage o salvă și MĂSOARĂ
# direcțiile gloanțelor. Înainte de 2026-09-07 toate cele 10 plecau paralel spre aceeași țintă;
# acum e o salvă + 9 proiectile bonus, ca la Gunslinger, deci direcțiile trebuie să fie DIFERITE.
#
# Partea 2 (meniu): pozele panoului OP START, ale paginii SAVE și ale armelor cu OP pornit.
#
# ⚠️ SALVAREA ADEVĂRATĂ. Unealta cheamă și `Unlocks.deblocheaza_tot()`, și `sterge_salvarea()`,
# adică fix cele două funcții care scriu/șterg `user://scores.save`. De-aia:
#   · își pune deoparte `unlocked`, `coins`, `op_start` și le aduce înapoi la sfârșit;
#   · ștergerea se probează pe o COPIE făcută de ea în `user://scores.save.tool`, pusă la loc
#     imediat după probă.
# Verifică oricum md5-ul fișierului după rulare — asta e regula pentru orice unealtă care atinge
# GameSettings (vezi CLAUDE.md).

const MENU := preload("res://menu.tscn")
const PLAYER := preload("res://player.tscn")
const POZE := "user://opsave_%s.png"
const COPIE := "user://scores.save.tool"

var _menu: Node
var _erori := 0

func _ready() -> void:
	var v_unlocked: Dictionary = GameSettings.unlocked.duplicate()
	var v_coins: int = GameSettings.coins
	var v_op: bool = GameSettings.op_start
	var v_arma: String = GameSettings.weapon_type
	var v_car: String = GameSettings.character

	await _parte_proiectile()
	await _parte_meniu()
	_parte_stergere()

	GameSettings.unlocked = v_unlocked
	GameSettings.coins = v_coins
	GameSettings.op_start = v_op
	GameSettings.weapon_type = v_arma
	GameSettings.character = v_car
	GameSettings._save()
	print("\n%s" % ("✔ TOTUL BINE" if _erori == 0 else "✘ %d probleme" % _erori))
	get_tree().quit(1 if _erori > 0 else 0)

func _zi(ok: bool, text: String) -> void:
	if not ok:
		_erori += 1
	print("  %s %s" % ["✔" if ok else "✘", text])

# ---------- 1. proiectilele de la OP START ----------
func _parte_proiectile() -> void:
	print("\n[1] proiectilele de la OP START")
	GameSettings.op_start = true
	GameSettings.weapon_type = "pistol"
	var p: Node2D = PLAYER.instantiate()
	add_child(p)
	await get_tree().create_timer(0.3).timeout

	_zi(p.bullet_count == 1, "bullet_count = %d (trebuie 1: nu mai sunt gloanțe paralele)" % p.bullet_count)
	_zi(p.stacked_armory_stacks == GameSettings.OP_PROJECTILES - 1,
		"proiectile bonus = %d (trebuie %d)" % [p.stacked_armory_stacks, GameSettings.OP_PROJECTILES - 1])
	_zi(p.projectiles_total() == GameSettings.OP_PROJECTILES,
		"TOTAL afișat = %d (trebuie %d, cât scrie pe panoul OP START)"
			% [p.projectiles_total(), GameSettings.OP_PROJECTILES])

	# trei inamici falși, în trei colțuri diferite, ca proiectilele bonus să aibă unde pleca
	for unghi in [0.0, TAU / 3.0, 2.0 * TAU / 3.0]:
		var e := Node2D.new()
		e.add_to_group("enemy")
		e.global_position = p.global_position + Vector2.RIGHT.rotated(unghi) * 200.0
		add_child(e)
	await get_tree().process_frame

	p._fire()
	await get_tree().process_frame
	var directii := {}
	var gloante := 0
	for c in get_children():
		if c.has_method("set_direction"):
			gloante += 1
			directii[snappedf(c.direction.angle(), 0.01)] = true
	_zi(gloante == GameSettings.OP_PROJECTILES,
		"o salvă = %d gloanțe (trebuie %d)" % [gloante, GameSettings.OP_PROJECTILES])
	_zi(directii.size() >= 3,
		"pleacă în %d direcții diferite (înainte era 1: toate din față)" % directii.size())
	for c in get_children():
		if c != p:
			c.queue_free()
	p.queue_free()
	await get_tree().process_frame

# ---------- 2. meniul: OP deschide tot, pagina SAVE ----------
func _parte_meniu() -> void:
	print("\n[2] meniul")
	_menu = MENU.instantiate()
	add_child(_menu)
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	# a) cu OP STINS și salvare goală, totul e încuiat, ca înainte
	GameSettings.op_start = false
	GameSettings.unlocked = {}
	_zi(not Unlocks.e_deblocat("scythe"), "OP stins: coasa e încuiată")
	await _poza("weapon", "arme_op_stins")

	# b) cu OP PORNIT se poate alege orice, fără să se scrie nimic în salvare
	GameSettings.op_start = true
	_zi(Unlocks.e_deblocat("scythe") and Unlocks.e_deblocat("jordan"),
		"OP pornit: și coasa, și Jordan sunt deschise")
	_zi(GameSettings.unlocked.is_empty(), "OP pornit NU scrie în salvare (unlocked e tot gol)")
	_menu._on_weapon_chosen("scythe")
	_menu._on_character_chosen("jordan")
	_zi(GameSettings.weapon_type == "scythe" and GameSettings.character == "jordan",
		"cu OP pornit chiar se pot ALEGE (arma=%s caracter=%s)"
			% [GameSettings.weapon_type, GameSettings.character])
	await _poza("weapon", "arme_op_pornit")
	await _poza("opstart", "panou_op")

	# c) stins la loc: lacătele revin, iar alegerea încuiată cade înapoi pe pistol/grasu
	GameSettings.op_start = false
	_menu._show("weapon")
	_menu._show("character")
	_zi(GameSettings.weapon_type == "pistol" and GameSettings.character == "grasu",
		"OP stins din nou: alegerea cade înapoi (arma=%s caracter=%s)"
			% [GameSettings.weapon_type, GameSettings.character])

	# d) pagina SAVE din Settings
	var s = _menu._settings_ui
	_zi(s.arata_salvarea, "meniul principal cere pagina SAVE")
	s.arata_pagina("save")
	await _poza("settings", "pagina_save")

	# UNLOCK ALL: scrie în salvare, deci butonul se stinge după el
	s._on_unlock_all()
	_zi(Unlocks.tot_deblocat(), "UNLOCK ALL: totul e câștigat, nu doar acoperit de OP")
	_zi(s._unlock_btn.disabled, "butonul s-a stins după ce n-a mai avut ce debloca")
	await _poza("settings", "pagina_save_deblocat")

	# DELETE SAVE FILE: prima apăsare doar armează
	s._on_delete_save()
	_zi(s._sterg_sigur and s._delete_btn.text == "CONFIRM",
		"prima apăsare pe DELETE doar armează (scrie „%s\")" % s._delete_btn.text)
	await _poza("settings", "pagina_save_armat")
	s._dezarmeaza_stergerea()
	_zi(not s._sterg_sigur and s._delete_btn.text == "DELETE SAVE FILE",
		"se dezarmează singur după câteva secunde")
	_menu.queue_free()
	await get_tree().process_frame

# ---------- 3. ștergerea salvării ----------
# Se probează pe o COPIE: fișierul adevărat se dă deoparte înainte și se pune la loc după.
func _parte_stergere() -> void:
	print("\n[3] DELETE SAVE FILE")
	var cale := ProjectSettings.globalize_path(GameSettings.SAVE_PATH)
	if FileAccess.file_exists(GameSettings.SAVE_PATH):
		DirAccess.copy_absolute(GameSettings.SAVE_PATH, COPIE)
	GameSettings.coins = 999
	GameSettings.unlocked = {"scythe": true}
	GameSettings._save()

	GameSettings.sterge_salvarea()
	_zi(not FileAccess.file_exists(GameSettings.SAVE_PATH), "fișierul chiar s-a dus (%s)" % cale)
	_zi(GameSettings.coins == 0 and GameSettings.unlocked.is_empty() \
		and GameSettings.character == "grasu" and not GameSettings.op_start,
		"și memoria e goală (monede=%d, deblocări=%d, caracter=%s, op=%s)"
			% [GameSettings.coins, GameSettings.unlocked.size(), GameSettings.character,
				GameSettings.op_start])
	# ⚠️ Asta e proba care contează: `_save()` scrie TOT ce e în RAM. Dacă memoria n-ar fi fost
	# golită, primul salvat de după ștergere ar fi readus monedele și deblocările vechi.
	GameSettings._save()
	var f := FileAccess.open(GameSettings.SAVE_PATH, FileAccess.READ)
	var d = f.get_var() if f != null else {}
	_zi(int(d.get("coins", -1)) == 0 and Dictionary(d.get("unlocked", {})).is_empty(),
		"primul _save() de după ștergere nu învie nimic (monede=%s)" % d.get("coins", "?"))

	if FileAccess.file_exists(COPIE):
		DirAccess.copy_absolute(COPIE, GameSettings.SAVE_PATH)
		DirAccess.remove_absolute(COPIE)
		GameSettings._load()
		print("  · salvarea adevărată pusă la loc (monede=%d)" % GameSettings.coins)

func _poza(pagina: String, nume: String) -> void:
	_menu._show(pagina)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(POZE % nume))
	print("  poza: ", POZE % nume)
