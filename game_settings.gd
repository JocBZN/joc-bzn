extends Node

# Setări globale + salvare pe device (leaderboard, monede, meta-progresie). Autoload "GameSettings".

var weapon_type: String = "pistol"  # arma aleasă: "pistol" / "mage" / "extinguisher"
var character: String = "grasu"

const SAVE_PATH := "user://scores.save"

var scores: Array = []          # {"time": float, "level": int, "kills": int}, cele mai bune primele
var coins: int = 0              # monede permanente (meta-progresie)
var upgrades: Dictionary = {}   # id upgrade -> nivel deținut
var run_coins: int = 0          # monede strânse în runda curentă (băgate la bancă la game over)
var run_kills: int = 0          # inamici uciși în runda curentă
var run_spawn: Vector2 = Vector2.ZERO  # unde a început runda (lumea e infinită, startul e aleator)

# --- sunet (reglat din meniul Settings) --- 0.0 = mut, 1.0 = volum normal.
# audio.gd le citește când redă un sunet / muzica, deci schimbarea se aude imediat.
var music_volume: float = 0.7
var sfx_volume: float = 1.0

# --- taste (remapabile din Settings) ---
# Acțiunile de mișcare le creăm NOI, din cod (nu în project.godot), tocmai ca să le putem
# schimba din meniu. Fiecare are taste implicite (WASD + săgeți); dacă jucătorul alege alta,
# o reținem în `keybinds` și înlocuiește tot. `player.gd` citește exact aceste acțiuni.
const MOVE_ACTIONS := {
	"move_up":    {"label": "Up",    "keys": [KEY_W, KEY_UP]},
	"move_down":  {"label": "Down",  "keys": [KEY_S, KEY_DOWN]},
	"move_left":  {"label": "Left",  "keys": [KEY_A, KEY_LEFT]},
	"move_right": {"label": "Right", "keys": [KEY_D, KEY_RIGHT]},
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
	_load()
	_setup_actions()   # după _load, ca să folosim tastele salvate dacă există

# --- taste ---
# Creează acțiunile de mișcare în InputMap și le pune tastele (cele salvate sau cele implicite).
func _setup_actions() -> void:
	for action in MOVE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if keybinds.has(action):
			_bind(action, [int(keybinds[action])])   # tasta aleasă de jucător
		else:
			_bind(action, MOVE_ACTIONS[action]["keys"])   # implicit (WASD + săgeată)

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
	var kc: int = int(keybinds[action]) if keybinds.has(action) else MOVE_ACTIONS[action]["keys"][0]
	return OS.get_keycode_string(kc)

# --- sunet ---
func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	Audio.refresh_music_volume()   # muzica ce cântă acum se ajustează pe loc
	_save()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_save()   # se aplică la următorul efect redat

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

func add_run_coins(n: int) -> void:
	run_coins += n

func add_kill() -> void:
	run_kills += 1

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
	elif data is Array:
		scores = data  # format vechi (doar scoruri) → rămâne compatibil
