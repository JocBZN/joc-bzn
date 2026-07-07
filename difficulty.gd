extends Node

# ---------------------------------------------------------------------------
# "Creierul" dificultății. E un SINGLETON (autoload) — există o singură dată,
# global, și orice script poate citi din el: Difficulty.stage(), etc.
# Cu cât trece timpul, cu atât crește "treapta" (stage) și tot ce depinde de ea.
# ---------------------------------------------------------------------------

# Timpul scurs de la începutul rundei (secunde). Spawner-ul îl resetează la joc nou.
var time: float = 0.0

# Val-ul (wave) curent, setat de spawner. ACESTA e acum motorul principal al dificultății:
# fiecare val e mai greu ca precedentul.
var wave: int = 1

func _process(delta: float) -> void:
	time += delta

# --- Multiplicatori care cresc cu VALUL (modifică numerele ca să reglezi) ---
# (wave - 1) ca valul 1 = dificultate de bază (multiplicatori = 1.0).

func enemy_hp_mult() -> float:
	return 1.0 + (wave - 1) * 0.45   # +45% viață pe val

func enemy_speed_mult() -> float:
	return 1.0 + (wave - 1) * 0.06   # +6% viteză pe val

func spawn_mult() -> float:
	return 1.0 + (wave - 1) * 0.30   # apar cu 30% mai des pe val

func xp_mult() -> float:
	return 2.0 * (1.0 + (wave - 1) * 0.35)   # +100% XP de bază, crește cu valul

# XP2 (rar) e deblocat de la valul 3 în sus
func xp2_unlocked() -> bool:
	return wave >= 3
