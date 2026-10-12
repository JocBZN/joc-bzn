extends Node
# ACHIEVEMENT-URILE DE PE STEAM (autoload "Achievements"). Adăugat 2026-10-12.
#
# Răzvan le-a făcut în Steamworks; aici sunt CÂND se dau. Numele din `LISTA` sunt „API Name"-urile
# din Steamworks, scrise EXACT ca acolo (litere mari/mici, spații) — dacă unul nu se potrivește,
# `steam_lb.gd` scrie în log „achievement necunoscut pe Steam: …" la pornire.
#
# Unde se declanșează fiecare (fiecare loc cheamă o singură funcție de aici):
#   · `unlocks.gd::deblocheaza_tot`   → `buton_unlock_all()`  (Easy Way Out)
#   · `unlocks.gd::deblocheaza`       → `verifica_deblocari()` (Collector, Arsenal, True Master)
#   · `game_settings.gd::add_kill`    → `kill()`               (Hunter … The Devil, kill-uri TOTALE)
#   · `celesto.gd::_die`              → `da("Cosmic Terror")`
#   · `final_boss.gd::_die` (Sir John)→ `da("Dead Chiverly")`
#   · `casino.gd::_arata_rezultat`    → `da("Lucky Strike")` la 3 câștiguri la rând la ruletă
#   · `alba_menu.gd::_ia_premiul`     → `da("Sixth Sense")` când iei premiul Legendary
#   · `player.gd::_process` (0.5 s)   → `verifica_runda(p)`    (Royal Flush + cele 3 de după timer)
#   · `settings_ui.gd::_on_delete_save` → `amnezie()`
#
# 💾 Ce s-a câștigat se ține și în salvare (`GameSettings.achievements`), nu doar pe Steam: dacă
# joci cu Steam închis, achievement-ul nu se pierde — se trimite data viitoare când Steam e pornit
# (`steam_lb.gd::_trimite_achievements_salvate`).

const LISTA := [
	"Easy Way Out", "True Master",
	"Hunter", "Predator", "Demon", "The Devil",
	"Cosmic Terror", "Dead Chiverly",
	"Lucky Strike", "Sixth Sense",
	"Resistant", "Made of steel", "Unbeatable",
	"Amnesia", "Collector", "Arsenal", "Royal Flush",
]

# Kill-uri TOTALE, adunate din toate rundele (`GameSettings.total_kills`).
const KILLS := {"Hunter": 1000, "Predator": 10000, "Demon": 100000, "The Devil": 1000000}
# Câte secunde ai rezistat DUPĂ ce s-a terminat cronometrul rundei (Final Swarm) — `Difficulty.overtime()`.
const DUPA_TIMER := {"Resistant": 60.0, "Made of steel": 300.0, "Unbeatable": 600.0}
const LUCK_ROYAL := 100.0      # noroc într-o rundă (`player.luck_total()`, cifra din panou)
const RULETA_LA_RAND := 3      # câștiguri la rând la ruletă pentru Lucky Strike

func are(api: String) -> bool:
	return bool(GameSettings.achievements.get(api, false))

# Dă achievement-ul: îl ține minte în salvare și îl trimite pe Steam. De câte ori vrei — a doua
# oară iese pe loc, fără să scrie nimic.
func da(api: String) -> void:
	if are(api):
		return
	GameSettings.achievements[api] = true
	GameSettings._save()
	SteamLB.achievement(api)

# --- declanșatoarele ---

func buton_unlock_all() -> void:
	GameSettings.unlock_all_folosit = true
	da("Easy Way Out")

# Collector / Arsenal / True Master se dau DOAR dacă n-ai apăsat niciodată UNLOCK ALL (de la
# ultima ștergere a salvării) — altfel butonul ți-ar fi dat patru achievement-uri dintr-o apăsare,
# iar „True Master" n-ar mai fi însemnat nimic.
func verifica_deblocari() -> void:
	if GameSettings.unlock_all_folosit:
		return
	var caractere := true
	var arme := true
	for id in Unlocks.CERINTE:
		if Unlocks.e_castigat(id):
			continue
		if Unlocks.CERINTE[id]["tip"] == "character":
			caractere = false
		else:
			arme = false
	if caractere:
		da("Collector")
	if arme:
		da("Arsenal")
	if caractere and arme:
		da("True Master")

func kill() -> void:
	GameSettings.total_kills += 1
	var k := GameSettings.total_kills
	# comparație ieftină, la fiecare kill; `da` scrie în salvare doar o dată pe prag
	if k == KILLS["Hunter"] or k == KILLS["Predator"] or k == KILLS["Demon"] or k == KILLS["The Devil"]:
		verifica_kills()

func verifica_kills() -> void:
	for api in KILLS:
		if GameSettings.total_kills >= int(KILLS[api]):
			da(api)

func verifica_runda(p) -> void:
	if p == null:
		return
	if not are("Royal Flush") and p.luck_total() >= LUCK_ROYAL:
		da("Royal Flush")
	var ot := Difficulty.overtime()
	for api in DUPA_TIMER:
		if ot >= float(DUPA_TIMER[api]):
			da(api)

# ⚠️ NU trece prin `da()`: aia scrie în salvare, iar salvarea tocmai a fost ștearsă — fișierul
# s-ar fi născut la loc din prima secundă. Merge direct pe Steam; cu Steam închis se pierde (nu
# are unde să aștepte fără fișier) — dar jocul de pe Steam pornește oricum cu Steam deschis.
func amnezie() -> void:
	SteamLB.achievement("Amnesia")

# Chemată o dată, la pornirea jocului (`_ready`): prinde ce s-a câștigat ÎNAINTE de actualizarea asta
# (kill-uri numărate de acum încolo, deci pragurile vin din jucat; deblocări deja făcute).
#
# ⚠️ O salvare de DINAINTE de achievement-uri nu știe dacă s-a apăsat UNLOCK ALL. Dacă are TOTUL
# deblocat, presupunem că da (așa arăta chiar salvarea lui Răzvan) — altfel butonul apăsat cândva
# ar fi dat pe loc Collector + Arsenal + True Master. Cine a deblocat doar o parte nu pierde nimic.
func _ready() -> void:
	if GameSettings.salvare_dinainte_de_achievements and Unlocks.tot_deblocat():
		GameSettings.unlock_all_folosit = true
	verifica_la_pornire()

func verifica_la_pornire() -> void:
	verifica_deblocari()
	verifica_kills()
