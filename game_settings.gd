extends Node

# Setări globale + salvare pe device (leaderboard, monede, meta-progresie). Autoload "GameSettings".

var weapon_type: String = "pistol"  # arma aleasă: "pistol" / "mage" / "sword" / "scythe"
var character: String = "grasu"

const SAVE_PATH := "user://scores.save"

var scores: Array = []          # {"time": float, "level": int, "kills": int}, cele mai bune primele
var coins: int = 0              # monede permanente (meta-progresie)
var upgrades: Dictionary = {}   # id upgrade -> nivel deținut
var run_coins: int = 0          # monede strânse în runda curentă (băgate la bancă la game over)
var run_kills: int = 0          # inamici uciși în runda curentă
# Chei de cufăr strânse în runda curentă. Cad de la inamici (0.5% — vezi `enemy.gd`) și se
# consumă câte una la fiecare cufăr deschis (`chest.gd`). NU se păstrează între runde: sunt
# resursă de rundă, ca monedele necunoscute încă, nu meta-progresie.
var run_keys: int = 0
var run_spawn: Vector2 = Vector2.ZERO  # unde a început runda (lumea e infinită, startul e aleator)

# --- sunet (reglat din meniul Settings) --- 0.0 = mut, 1.0 = volum normal.
# audio.gd le citește când redă un sunet / muzica, deci schimbarea se aude imediat.
var music_volume: float = 0.7
var sfx_volume: float = 1.0

# --- grafică (pagina GRAPHICS din Settings) ---
# Toate patru se salvează și se aplică la pornire (`aplica_grafica`).
# `vignette` și `glow` le desenează `atmosphere.gd`, care e doar ÎN JOC — de aia, când le
# schimbi din meniul principal, se aplică abia când începi runda. Din meniul de pauză se
# văd imediat, fiindcă atunci nodul Atmosphere există.
var fullscreen: bool = false
var vsync: bool = true
var vignette: bool = true   # marginile întunecate care duc ochiul spre centru
var glow: bool = true       # bloom-ul subtil de pe zonele luminoase

# --- limba (butonul cu steag din meniul principal) ---
# Codurile sunt cele din `i18n.gd`: „en", „zh", „de", „es", „ru", „fr", „ja", „pl", „tr".
# Implicit „en", limba în care e scris jocul. Se aplică prin TranslationServer, deci schimbarea
# se vede pe loc, fără repornire.
var language: String = "en"

# --- OP START (comutatorul din colțul meniului) ---
# Runda pornește cu statusuri de final, ca să se poată ajunge REPEDE la ce e de testat (Nether,
# Ender, Celesto) fără 20 de minute de joc. Cifrele stau aici, nu în `player.gd`, fiindcă le
# citesc amândoi: meniul le AFIȘEAZĂ, player-ul le APLICĂ — scrise în două locuri, ar fi ajuns
# să mintă una pe alta după prima reglare.
const OP_DAMAGE := 100
const OP_ATTACK_SPEED := 2.5     # atacuri pe SECUNDĂ; `player.gd` îl întoarce în `fire_interval`
const OP_PROJECTILES := 10
var op_start: bool = false       # se salvează: dacă-l lași pornit, e pornit și data viitoare

# --- taste (remapabile din Settings) ---
# Acțiunile astea le creăm NOI, din cod (nu în project.godot), tocmai ca să le putem schimba din
# meniu. Fiecare are taste implicite; dacă jucătorul alege alta, o reținem în `keybinds` și
# înlocuiește tot. `player.gd` citește move_*; `interact` e citit de interact_ui.gd (invocă statuia).
const KEY_ACTIONS := {
	"move_up":    {"label": "Up",       "keys": [KEY_W, KEY_UP]},
	"move_down":  {"label": "Down",     "keys": [KEY_S, KEY_DOWN]},
	"move_left":  {"label": "Left",     "keys": [KEY_A, KEY_LEFT]},
	"move_right": {"label": "Right",    "keys": [KEY_D, KEY_RIGHT]},
	"interact":   {"label": "Interact", "keys": [KEY_E]},
}
var keybinds: Dictionary = {}   # action -> physical_keycode ales de jucător (doar cele schimbate)

# Upgrade-urile permanente din meniu (ecranul UPGRADES): efect pe nivel, cost de bază, nivel maxim.
const META := [
	{"id": "hp",       "name": "Max HP",    "per": "+15 HP",    "cost": 40, "max": 10},
	{"id": "damage",   "name": "Damage",    "per": "+3 dmg",    "cost": 50, "max": 10},
	{"id": "speed",    "name": "Speed",     "per": "+15 spd",   "cost": 40, "max": 8},
	{"id": "firerate", "name": "Fire rate", "per": "-4% pause", "cost": 60, "max": 8},
	{"id": "xp",       "name": "XP gain",   "per": "+8% XP",    "cost": 50, "max": 8},
	{"id": "regen",    "name": "Regen",     "per": "+1 HP/sec", "cost": 70, "max": 5},
]

func _ready() -> void:
	# implicit pentru fullscreen = cum pornește proiectul; `_load()` îl suprascrie dacă
	# jucătorul a ales altceva. Așa nu forțăm fereastra dacă nu s-a atins nimeni de setare.
	var mod := DisplayServer.window_get_mode()
	fullscreen = mod == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mod == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	_load()
	_setup_actions()   # după _load, ca să folosim tastele salvate dacă există
	aplica_grafica()

# --- taste ---
# Creează acțiunile de mișcare în InputMap și le pune tastele (cele salvate sau cele implicite).
func _setup_actions() -> void:
	for action in KEY_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if keybinds.has(action):
			_bind(action, [int(keybinds[action])])   # tasta aleasă de jucător
		else:
			_bind(action, KEY_ACTIONS[action]["keys"])   # implicit (WASD + săgeată)

# Pune pe o acțiune exact tastele date (șterge ce era înainte).
func _bind(action: String, keycodes: Array) -> void:
	InputMap.action_erase_events(action)
	for kc in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = kc   # physical = poziția tastei, merge la fel pe orice layout
		InputMap.action_add_event(action, ev)

# Cheamă asta din Settings când jucătorul apasă o tastă nouă pentru o direcție.
func rebind(action: String, keycode: int) -> void:
	keybinds[action] = keycode
	_bind(action, [keycode])
	_save()

# Numele tastei curente pentru o acțiune (ex. "W", "Left"), pentru afișare în meniu.
func key_name(action: String) -> String:
	var kc: int = int(keybinds[action]) if keybinds.has(action) else KEY_ACTIONS[action]["keys"][0]
	return OS.get_keycode_string(kc)

# --- sunet ---
func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	Audio.refresh_music_volume()   # muzica ce cântă acum se ajustează pe loc
	_save()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_save()   # se aplică la următorul efect redat

# --- grafică ---
func set_fullscreen(on: bool) -> void:
	fullscreen = on
	aplica_grafica()
	_save()

func set_vsync(on: bool) -> void:
	vsync = on
	aplica_grafica()
	_save()

func set_vignette(on: bool) -> void:
	vignette = on
	_refresh_atmosfera()
	_save()

func set_glow(on: bool) -> void:
	glow = on
	_refresh_atmosfera()
	_save()

# --- OP start ---
# Se citește o singură dată, în `player.gd::_ready()`, deci pornirea/oprirea din meniu se vede
# abia la runda următoare — nu în cea care rulează deja.
func set_op_start(on: bool) -> void:
	op_start = on
	_save()

# --- limbă ---
# Doar reține și salvează alegerea; cine schimbă efectiv locale-ul e `I18n.schimba_limba()`.
func set_language(cod: String) -> void:
	language = cod
	_save()

# Pune fereastra și vsync-ul pe ce zic setările. Nu atingem fereastra dacă e deja cum trebuie
# (`window_set_mode` cu aceeași valoare tot clipește pe unele drivere).
func aplica_grafica() -> void:
	var mod := DisplayServer.window_get_mode()
	var e_fullscreen := mod == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mod == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != e_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
			else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync \
		else DisplayServer.VSYNC_DISABLED)

# Nodul Atmosphere există doar în joc; în meniu pur și simplu nu e nimic de anunțat.
func _refresh_atmosfera() -> void:
	var a := get_tree().get_first_node_in_group("atmosphere")
	if a != null and a.has_method("apply_settings"):
		a.apply_settings()

# --- meta-progresie ---
func level_of(id: String) -> int:
	return int(upgrades.get(id, 0))

func max_of(id: String) -> int:
	for u in META:
		if u["id"] == id:
			return int(u["max"])
	return 0

func cost_of(id: String) -> int:
	for u in META:
		if u["id"] == id:
			return int(u["cost"]) * (level_of(id) + 1)  # costul crește cu nivelul deținut
	return 999999

func can_buy(id: String) -> bool:
	return level_of(id) < max_of(id) and coins >= cost_of(id)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	coins -= cost_of(id)
	upgrades[id] = level_of(id) + 1
	_save()
	return true

# --- monede din rundă ---
func reset_run() -> void:
	run_coins = 0
	run_kills = 0
	run_keys = 0

func add_run_coins(n: int) -> void:
	run_coins += n

func add_kill() -> void:
	run_kills += 1

func add_key(n: int = 1) -> void:
	run_keys += n

# Consumă o cheie pentru un cufăr. `false` = n-ai niciuna, deci cufărul rămâne încuiat.
# Verificarea și scăderea stau ÎMPREUNĂ, într-un singur loc: dacă cine cheamă ar întreba
# întâi „am cheie?" și abia apoi ar scădea, două cufere deschise în același cadru ar putea
# trece amândouă cu o singură cheie.
func foloseste_cheie() -> bool:
	if run_keys <= 0:
		return false
	run_keys -= 1
	return true

func bank_run_coins() -> void:
	coins += run_coins
	run_coins = 0
	_save()

# --- leaderboard ---
func add_score(time_sec: float, level: int, kills: int = 0) -> void:
	scores.append({"time": time_sec, "level": level, "kills": kills})
	scores.sort_custom(func(a, b): return a["time"] > b["time"])
	if scores.size() > 10:
		scores.resize(10)
	_save()

# --- salvare / încărcare ---
func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_var({
			"scores": scores, "coins": coins, "upgrades": upgrades,
			"music_volume": music_volume, "sfx_volume": sfx_volume, "keybinds": keybinds,
			"fullscreen": fullscreen, "vsync": vsync, "vignette": vignette, "glow": glow,
			"language": language, "op_start": op_start,
		})

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = f.get_var()
	if data is Dictionary:
		scores = data.get("scores", [])
		coins = int(data.get("coins", 0))
		upgrades = data.get("upgrades", {})
		music_volume = float(data.get("music_volume", music_volume))
		sfx_volume = float(data.get("sfx_volume", sfx_volume))
		keybinds = data.get("keybinds", {})
		# `fullscreen` are ca implicit ce-a citit `_ready()` din fereastra reală, nu `false`
		fullscreen = bool(data.get("fullscreen", fullscreen))
		vsync = bool(data.get("vsync", vsync))
		vignette = bool(data.get("vignette", vignette))
		glow = bool(data.get("glow", glow))
		language = String(data.get("language", language))
		op_start = bool(data.get("op_start", op_start))
	elif data is Array:
		scores = data  # format vechi (doar scoruri) → rămâne compatibil
