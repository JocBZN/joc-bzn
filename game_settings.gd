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
		f.store_var({"scores": scores, "coins": coins, "upgrades": upgrades})

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
	elif data is Array:
		scores = data  # format vechi (doar scoruri) → rămâne compatibil
