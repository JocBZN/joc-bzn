extends Node

# Setări globale alese din meniu + leaderboard local. Autoload "GameSettings" — există o
# singură dată și se păstrează între scene (meniu → joc → game over → meniu).

var weapon_path: String = "res://bullet.tscn"  # arma de start (aleasă la Choose Weapon)
var character: String = "grasu"                 # personajul ales (deocamdată unul singur)

const SAVE_PATH := "user://scores.save"
var scores: Array = []  # listă de {"time": float, "level": int}, cele mai bune primele

func _ready() -> void:
	_load_scores()

# Adaugă un scor nou și păstrează top 10 (cel mai lung timp = primul).
func add_score(time_sec: float, level: int) -> void:
	scores.append({"time": time_sec, "level": level})
	scores.sort_custom(func(a, b): return a["time"] > b["time"])
	if scores.size() > 10:
		scores.resize(10)
	_save_scores()

func _save_scores() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_var(scores)

func _load_scores() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f != null:
		var data = f.get_var()
		if data is Array:
			scores = data
