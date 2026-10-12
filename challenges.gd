extends Node

# CHALLENGE-URILE (cerute de Răzvan pe 2026-10-12). Autoload „Challenges".
#
# „Cand dai start la un run vreau sa te bage in alt meniu in care sa selectezi cum vrei sa joci sa
# fie Normal si apoi sub el o sectiune challenges [...] Si primesti un checkmark cand termini un
# challenge."
#
# START din meniu nu mai pornește direct runda: deschide pagina CHOOSE MODE (`menu.gd::_build_mod`),
# cu NORMAL sus și cele trei challenge-uri dedesubt. Alegi unul → runda pornește cu el.
#
# Un singur challenge pe rundă (nu se combină). `activ` = "" înseamnă Normal.
#
# Unde se aplică fiecare (căutați `Challenges.` în cod):
#   speedrunner — `player.gd::_aplica_challenge` (+10 noroc), `difficulty.gd::run_length()` (lumea
#                 normală 10:00 → 8:00), `nether.gd` / `ender.gd` / `prison.gd::_durata()`
#                 (7:00 → 5:00, 6:00 → 4:00, 5:00 → 3:00). Limbo (1:00) NU e o lume, rămâne cum e.
#   dual_wield  — `player.gd::_aplica_challenge`: două arme random (CHOOSE WEAPON e ignorat), −10
#                 damage fix (dar nu sub 1 — Răzvan a ales asta, fiindcă Mage pornește cu 10), −50%
#                 attack speed.
#   randomizer  — `levelup.gd::open`: nu mai apare ecranul de alegere, primești pe loc un item la
#                 întâmplare, cu ȘANSE EGALE pentru toate (raritatea și norocul nu mai contează).
#
# BIFA: o primești când îl bați pe Sir John cu challenge-ul activ (`victory.gd`). Se ține în
# salvare (`GameSettings.challenges_done`). Runda cu challenge NU intră în leaderboard
# (`GameSettings.add_score` iese din prima) — ales de Răzvan.

const LISTA := [
	{"id": "speedrunner", "nume": "Speedrunner",
		"desc": "Start with 10 Luck, -2 minutes in each world."},
	{"id": "dual_wield", "nume": "Dual Wield",
		"desc": "Start with 2 random weapons, -10 Damage, -50% Attack Speed."},
	{"id": "randomizer", "nume": "Randomizer",
		"desc": "You no longer choose upgrades, rarity no longer matters."},
]

# --- cifrele (schimbă-le doar aici; descrierile de mai sus trebuie schimbate odată cu ele) ---
const SPEEDRUN_LUCK := 10.0       # noroc la start
const SPEEDRUN_MINUS := 120.0     # secunde tăiate din cronometrul FIECĂREI lumi
const DUAL_DAMAGE := 10           # damage scăzut (fix), dar nu sub `DUAL_DAMAGE_MIN`
const DUAL_DAMAGE_MIN := 1
const DUAL_ATTACK_SPEED := 0.5    # attack speed-ul se ÎNMULȚEȘTE cu asta (−50%)

# Challenge-ul rundei de acum. NU se salvează: îl alegi din nou la fiecare START. Supraviețuiește
# însă unui RETRY din Game Over (autoload-ul nu se golește la schimbarea scenei).
var activ := ""

func e_activ(id: String) -> bool:
	return activ == id

func normal() -> bool:
	return activ == ""

# Cât se taie din cronometrul fiecărei lumi, în secunde (0 în afară de Speedrunner).
func secunde_minus() -> float:
	return SPEEDRUN_MINUS if activ == "speedrunner" else 0.0

func nume(id: String) -> String:
	for c in LISTA:
		if c["id"] == id:
			return String(c["nume"])
	return ""

func terminat(id: String) -> bool:
	return bool(GameSettings.challenges_done.get(id, false))

# Cheamă-l când runda e CÂȘTIGATĂ (Sir John a căzut). Întoarce true dacă abia acum s-a bifat.
func marcheaza_terminat() -> bool:
	if activ == "" or terminat(activ):
		return false
	GameSettings.challenges_done[activ] = true
	GameSettings._save()
	return true
