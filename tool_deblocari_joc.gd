extends Node2D

# UNEALTĂ: probează că deblocările CHIAR se declanșează din joc, nu doar că meniul le desenează.
#
# Pune un player și un HUD adevărat (nu imitații), împinge pe rând statusurile peste praguri și se
# uită dacă `unlocks.gd` a deschis ce trebuie. Ultima probă lasă pancarta pe ecran și o fotografiază.
#
# ⚠️ `Unlocks.deblocheaza` scrie în `user://scores.save` (cheamă `GameSettings._save()`). Unealta își
# pune deoparte `GameSettings.unlocked`, iar la sfârșit îl aduce înapoi ȘI salvează, ca fișierul să
# rămână cum era. Verifică md5-ul după rulare, ca la orice unealtă care atinge GameSettings.

const PLAYER := preload("res://player.tscn")
const HUD_GD := preload("res://hud.gd")

var _p: Node2D
var _hud: CanvasLayer

func _ready() -> void:
	var vechi: Dictionary = GameSettings.unlocked.duplicate()
	GameSettings.unlocked = {}
	GameSettings.reset_run()

	_hud = CanvasLayer.new()
	_hud.set_script(HUD_GD)
	add_child(_hud)
	_p = PLAYER.instantiate()
	add_child(_p)
	await get_tree().create_timer(0.3).timeout

	# --- cele trei care se prind pe STATUSURI (ceasul din player.gd::_process) ---
	_p.luck = 25.0
	await _asteapta("mage")
	_p.luck = 0.0

	_p.bullet_damage = 120
	await _asteapta("sword")

	_p.crit_chance = 1.1
	await _asteapta("knife")

	# --- cele trei care se prind pe EVENIMENTE ---
	Unlocks.item_luat("iarba")
	print("  dupa un item oarecare: spellman=%s (trebuie false)" % Unlocks.e_deblocat("spellman"))
	Unlocks.item_luat(Unlocks.ITEM_SPELLMAN)
	print("  spellman dupa Tome of Knowledge: %s" % Unlocks.e_deblocat("spellman"))

	Unlocks.cufar_deschis()
	Unlocks.cufar_deschis()
	print("  jordan dupa 2 cufere: %s (trebuie false)" % Unlocks.e_deblocat("jordan"))
	Unlocks.cufar_deschis()
	print("  jordan dupa 3 cufere: %s" % Unlocks.e_deblocat("jordan"))

	# ...și că a treia rundă nu adună cufere din rundele trecute
	GameSettings.reset_run()
	print("  run_chests dupa reset_run: %d (trebuie 0)" % GameSettings.run_chests)

	Unlocks.celesto_invins()
	print("  scythe dupa Celesto: %s" % Unlocks.e_deblocat("scythe"))

	# pancarta aurie a ultimei deblocări e încă pe ecran
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("user://deblocari_pancarta.png"))

	GameSettings.unlocked = vechi
	GameSettings._save()   # fișierul înapoi cum era
	get_tree().quit()

# Așteaptă cel mult o secundă ca ceasul din `player.gd` să prindă pragul.
func _asteapta(id: String) -> void:
	var t := 0.0
	while t < 1.0 and not Unlocks.e_deblocat(id):
		await get_tree().process_frame
		t += get_process_delta_time()
	print("  %-7s deblocat dupa %.2fs: %s" % [id, t, Unlocks.e_deblocat(id)])
