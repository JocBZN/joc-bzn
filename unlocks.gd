extends Node

# DEBLOCĂRI. Autoload „Unlocks".
#
# Jocul pornește cu UN caracter (The G) și O armă (Pistol). Restul se câștigă jucând: fiecare are
# o cerință scrisă în tabelul de mai jos, iar în meniu se vede ca o siluetă NEAGRĂ, cu cerința
# scrisă în fișa din dreapta — deci nu e „ceva ce lipsește", e „ceva ce am de făcut".
#
# 🔑 Tot ce ține de deblocări trece pe aici: și CE se cere (tabelul), și DACĂ s-a împlinit
# (funcțiile de mai jos), și CINE știe asta (meniul întreabă `e_deblocat`). Locurile din joc care
# declanșează o deblocare cheamă o singură funcție și nu știu nimic despre restul:
#   · `levelup.gd::_apply`   → `item_luat(id)`        (Tome of Knowledge)
#   · `chest.gd::invoca`     → `cufar_deschis()`      (3 cufere)
#   · `celesto.gd::_die`     → `celesto_invins()`
#   · `player.gd::_process`  → `verifica_statusuri(p)` (noroc / damage / crit, la fiecare 0.5s)
#
# ⚠️ Ce s-a deblocat se ține în `GameSettings.unlocked` (deci în `user://scores.save`), NU aici:
# aici e doar logica. O salvare veche n-are cheia → totul e încuiat în afară de Pistol și The G,
# ceea ce e exact ce trebuie pentru un jucător care abia începe.

const MENU_GD := "res://menu.gd"

# Cerințele. Cine NU e în tabel (id-urile „pistol" și „grasu") e deblocat din start.
# Textele sunt în ENGLEZĂ, ca tot ce se afișează; traducerile lor stau în `i18n.gd`.
const CERINTE := {
	# --- CARACTERE ---
	"spellman": {"tip": "character", "cerinta": "Take Tome of Knowledge in one run"},
	"jordan":   {"tip": "character", "cerinta": "Open 3 chests in one run"},
	# --- ARME ---
	"mage":     {"tip": "weapon",    "cerinta": "Get 20 Luck in one run"},
	"sword":    {"tip": "weapon",    "cerinta": "Have 100 Damage in one run"},
	"scythe":   {"tip": "weapon",    "cerinta": "Defeat Celesto"},
	"knife":    {"tip": "weapon",    "cerinta": "Have 100 Crit in one run"},
}

# Pragurile, scoase din texte ca să nu poată minți unul pe altul: dacă schimbi cifra aici,
# schimb-o și în textul de sus (sunt două rânduri, unul lângă altul).
const ITEM_SPELLMAN := "tome_knowledge"   # id-ul din `levelup.gd` al lui Tome of Knowledge
const CUFERE_JORDAN := 3
const LUCK_MAGE := 20.0
const DAMAGE_SWORD := 100
const CRIT_KNIFE := 1.0                   # 1.0 = 100% șansă de critic

var _nume := {}   # id -> numele de pe ecran, citit o singură dată din `menu.gd`

# --- întrebările pe care le pune meniul ---

# Ce arată MENIUL. Două căi duc la „deblocat": ori l-ai câștigat, ori e pornit OP START.
#
# Cheat-ul din colț deschide TOT (cerut pe 2026-09-07), ca să se poată proba orice armă și orice
# caracter fără să le câștigi întâi — asta e chiar rostul lui: să ajungi repede la ce ai de
# probat. E un COMUTATOR, deci stinsul lui pune totul înapoi cum era; nu șterge nimic, fiindcă
# nici nu scrie nimic. Pentru deblocări DEFINITIVE există butonul UNLOCK ALL din Settings.
func e_deblocat(id: String) -> bool:
	return GameSettings.op_start or e_castigat(id)

# Ce s-a câștigat CU ADEVĂRAT, jucând — și SINGURA întrebare pe care și-o pune tot ce ține minte
# (`deblocheaza`, `verifica_statusuri`). Cu OP START pornit, `e_deblocat` e mereu `true`, deci
# dacă s-ar fi întrebat pe ea, cerințele s-ar fi oprit din numărat și ai fi rămas, la stins, cu
# exact ce aveai înainte. Așa, cheat-ul doar ACOPERĂ lacătele; jocul de sub el merge înainte.
func e_castigat(id: String) -> bool:
	return not CERINTE.has(id) or bool(GameSettings.unlocked.get(id, false))

func cerinta(id: String) -> String:
	return String(CERINTE[id]["cerinta"]) if CERINTE.has(id) else ""

# Deblochează și ANUNȚĂ. Se poate chema oricât de des: dacă e deja deblocat, iese pe loc — de aia
# `verifica_statusuri` poate să bată la ușă de două ori pe secundă fără să salveze de fiecare dată.
func deblocheaza(id: String) -> void:
	if e_castigat(id):
		return
	GameSettings.unlocked[id] = true
	GameSettings._save()
	_anunta(id)

# UNLOCK ALL — butonul din Settings → pagina SAVE (2026-09-07). Spre deosebire de OP START, care
# doar acoperă lacătele cât e pornit, ăsta SCRIE în salvare: e definitiv și rămâne și după ce
# închizi jocul.
#
# Nu anunță nimic pe ecran: pancarta „UNLOCKED" e răsplata pentru o cerință împlinită, nu pentru
# un buton apăsat — și oricum se apasă din meniu, unde nu există HUD care s-o arate.
func deblocheaza_tot() -> void:
	for id in CERINTE:
		GameSettings.unlocked[id] = true
	GameSettings._save()

# Mai e ceva de câștigat? Butonul de sus se stinge când nu mai e — altfel ar fi rămas un buton
# care se poate apăsa la nesfârșit fără să se întâmple nimic.
func tot_deblocat() -> bool:
	for id in CERINTE:
		if not e_castigat(id):
			return false
	return true

# --- ce declanșează deblocările ---

func item_luat(id: String) -> void:
	if id == ITEM_SPELLMAN:
		deblocheaza("spellman")

# Contorul stă în `GameSettings.run_chests`, lângă `run_kills`/`run_keys`, fiindcă e stat de RUNDĂ:
# se șterge singur la `reset_run()`, deci trei cufere adunate în două runde diferite nu contează.
func cufar_deschis() -> void:
	GameSettings.run_chests += 1
	if GameSettings.run_chests >= CUFERE_JORDAN:
		deblocheaza("jordan")

func celesto_invins() -> void:
	deblocheaza("scythe")

# Cele trei cerințe care se uită la STATUSURILE de acum. Nu se pot prinde pe un eveniment (un item
# luat, un inamic mort), fiindcă damage-ul și criticul se schimbă și în mers — Diesel Power crește
# cu viteza, Megane's Katana la fel. De-aia se întreabă pe ceas, din `player.gd::_process`.
#
# `bullet_damage * damage_mult()` e exact cifra pe care o vede jucătorul la „Damage" în panoul de
# level up (`stat_lines`) — altfel ar fi scris „100 damage" și i-ar fi cerut alt număr.
func verifica_statusuri(p) -> void:
	if p == null:
		return
	if not e_castigat("mage") and p.luck_total() >= LUCK_MAGE:
		deblocheaza("mage")
	if not e_castigat("sword") and int(round(p.bullet_damage * p.damage_mult())) >= DAMAGE_SWORD:
		deblocheaza("sword")
	if not e_castigat("knife") and p.crit_chance_now() >= CRIT_KNIFE:
		deblocheaza("knife")

# --- anunțul de pe ecran ---

# Aceeași pancartă mare ca la fazele de boss (`hud.announce`), dar AURIE, nu roșie: roșul din joc
# înseamnă „vine ceva peste tine". În meniu nu există HUD, deci acolo pur și simplu nu se anunță
# nimic — și nici n-are cine să deblocheze ceva de acolo.
const AUR := Color(1.0, 0.82, 0.35)

func _anunta(id: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("UNLOCKED", nume(id), AUR)

# Numele de pe ecran, citit DIN `menu.gd` (`WEAPONS` + `CHARACTERS`), nu copiat aici — exact ca
# `menu.gd::_arme_stats`, care citește statusurile din `player.gd`. O copie ar fi rămas în urmă în
# tăcere dacă Răzvan redenumește o armă, iar pancarta ar fi strigat vechiul nume.
func nume(id: String) -> String:
	if _nume.is_empty():
		var s := load(MENU_GD)
		if s != null:
			var c: Dictionary = s.get_script_constant_map()
			for lista in [c.get("WEAPONS", []), c.get("CHARACTERS", [])]:
				for x in lista:
					_nume[String(x["id"])] = String(x["name"])
	return String(_nume.get(id, id))
