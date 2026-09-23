extends Node2D

# UNEALTĂ: cum arată paginile CHOOSE WEAPON / CHOOSE CHARACTER cu lucruri ÎNCUIATE.
#
# Face șase poze (arme/caractere încuiate, fișa unui lucru încuiat, arme/caractere deblocate) și
# tipărește ce zice `unlocks.gd` la fiecare id, ca să se vadă că meniul și logica spun același lucru.
# Probează și că un click pe ceva încuiat NU alege nimic.
#
# ⚠️ SALVAREA ADEVĂRATĂ: `Unlocks.deblocheaza` cheamă `GameSettings._save()`, iar alegerea unui
# CARACTER deblocat la fel. De-aia unealta nu cheamă niciuna din alea: pune direct
# `GameSettings.unlocked` în RAM și îl aduce înapoi cum era la sfârșit. `scores.save` rămâne intact
# (verificat cu md5 după rulare).

const MENU := preload("res://menu.tscn")
const POZE := "user://deblocari_%s.png"

var _menu: Node

func _ready() -> void:
	var vechi: Dictionary = GameSettings.unlocked.duplicate()

	_menu = MENU.instantiate()
	add_child(_menu)
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	print("--- ce zice unlocks.gd ---")
	for id in ["pistol", "mage", "sword", "scythe", "knife", "cross", "grasu", "spellman", "jordan", "liu", "nerd"]:
		print("  %-9s deblocat=%s  cerinta=\"%s\"" % [id, Unlocks.e_deblocat(id), Unlocks.cerinta(id)])

	GameSettings.unlocked = {}
	await _poza("weapon", "arme_incuiate")
	await _poza("character", "caractere_incuiate")

	# ...și cum arată FIȘA unui lucru încuiat: intri pe el ca și cum ai trece cu mouse-ul.
	_menu._preview_arma("scythe")
	await _poza("weapon", "fisa_arma_incuiata")
	_menu._preview_arma("")
	_menu._preview_caracter("jordan")
	await _poza("character", "fisa_caracter_incuiat")
	_menu._preview_caracter("")

	# Proba că un click pe ceva încuiat NU alege: rămâne ce era.
	_menu._on_weapon_chosen("scythe")
	_menu._on_character_chosen("jordan")
	print("dupa click pe incuiate: arma=%s caracter=%s (trebuie pistol/grasu)"
		% [GameSettings.weapon_type, GameSettings.character])

	GameSettings.unlocked = {"mage": true, "sword": true, "scythe": true, "knife": true, "cross": true,
		"spellman": true, "jordan": true, "liu": true, "nerd": true}
	await _poza("weapon", "arme_deblocate")
	await _poza("character", "caractere_deblocate")

	GameSettings.unlocked = vechi   # înapoi cum era; nu s-a salvat nimic pe disc
	get_tree().quit()

func _poza(pagina: String, nume: String) -> void:
	_menu._show(pagina)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(POZE % nume))
	print("poza: ", POZE % nume)
