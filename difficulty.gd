extends Node

# ---------------------------------------------------------------------------
# "Creierul" dificultății. E un SINGLETON (autoload) — există o singură dată,
# global, și orice script poate citi din el: Difficulty.stage(), etc.
# Cu cât trece timpul, cu atât crește "treapta" (stage) și tot ce depinde de ea.
# ---------------------------------------------------------------------------

# Timpul scurs de la începutul rundei (secunde). Spawner-ul îl resetează la joc nou.
var time: float = 0.0

# La fiecare atâtea secunde crește o treaptă de dificultate. (Micșorează = mai greu mai repede.)
var stage_seconds: float = 30.0

# De la ce treaptă începe să pice XP-ul rar (XP2). 3 treapte * 30s = după 90 de secunde.
var xp2_from_stage: int = 3

func _process(delta: float) -> void:
	time += delta

# Treapta curentă: 0, 1, 2, ... (crește cu timpul)
func stage() -> int:
	return int(time / stage_seconds)

# --- Multiplicatori care cresc cu dificultatea (modifică numerele ca să reglezi) ---

func enemy_hp_mult() -> float:
	return 1.0 + stage() * 0.5     # +50% viață pe treaptă

func enemy_speed_mult() -> float:
	return 1.0 + stage() * 0.1     # +10% viteză pe treaptă

func spawn_mult() -> float:
	return 1.0 + stage() * 0.3     # apar cu 30% mai des pe treaptă

func xp_mult() -> float:
	return 2.0 * (1.0 + stage() * 0.5)   # +100% XP (dublat) față de bază, și crește cu dificultatea

# XP2 (rar) e deblocat abia când dificultatea a urcat destul
func xp2_unlocked() -> bool:
	return stage() >= xp2_from_stage
