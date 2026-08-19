extends CanvasLayer

# CAZINOUL („Let's go gambling") — interfața aparatului EGT din lume (`egt.gd`).
#
# Cum se leagă: apeși E pe aparat → `egt.gd::invoca()` → `open()` de aici. Jocul se OPREȘTE
# (`get_tree().paused`), exact ca la ecranul de Level Up, iar meniul merge mai departe fiindcă
# nodul are `PROCESS_MODE_ALWAYS`. ESC te întoarce un pas înapoi (de la masă la meniu, din meniu
# afară din cazinou).
#
# Patru ecrane:
#   1. „Let's go gambling" + Gamble your stats / Gamble your items.
#   2. MASA DE RULETĂ: poza din `harta/EGT/Roulette Table.png`, cu zone de click peste FIECARE
#      număr și peste toate pariurile exterioare (roșu/negru, par/impar, duzini, coloane).
#      În dreapta bifezi ce statusuri bagi în joc.
#   3. TRADE-UP CONTRACT (2026-08-07): dai 3 iteme de ACEEAȘI raritate și primești unul cu o
#      treaptă mai sus, pe care NU-L VEZI până nu tragi. Vezi secțiunea lui, mai jos.
#   4. BANAT (2026-08-11): dacă îți ies TREI câștiguri la rând la ruletă, cazinoul te dă afară
#      pentru tot run-ul — „You've been banned for cheating". Vezi `CASTIGURI_BAN`.
#
# ---------------------------------------------------------------------------
# CUM ARATĂ (refăcut pe 2026-08-07: „ca un joc cu 1 milion de copii vândute")
# ---------------------------------------------------------------------------
# Tot meniul stă acum în chenarele de aramă ale lui Răzvan din `harta/EGT/Border EGT.png` — o
# PLANȘĂ de 5×4 chenare de 64×64, din care tăiem la rulare doar celulele care ne trebuie
# (`_chenar`). Fiecare chenar are și interiorul lui aproape negru, deci ține loc și de ramă, și
# de fundal. Rama de lemn auriu (`Menu.png`) a plecat din panoul mesei din același motiv pentru
# care plecase și de la masa Ender: ea era tot ce făcea ecranul „prietenos".
#
# Regulile de croială, aceleași ca la `trade.gd` (citește acolo motivele pe larg):
#   · o singură culoare de accent (arama artei) și una de text (os), nimic altceva;
#   · ierarhie pe mărime, nu pe culoare: titlu 46 → secțiune 22 → ajutor 15;
#   · butoanele sunt piatră întunecată cu muchie de aramă, nu lemn cald;
#   · titlul respiră încet (2.6s dus-întors) — cât să pară viu, nu cât să distragă.
#
# MIZA (cerută de Răzvan pe 2026-07-30): „totul sau nimic". Câștigi → fiecare status bifat se
# DUBLEAZĂ. Pierzi → se ÎNJUMĂTĂȚEȘTE. La fel indiferent pe ce ai pariat: un număr plin plătește
# cât roșu/negru. Vezi `CASTIG_MULT` / `PIERDERE_MULT` dacă vrei plăți diferite pe tip de pariu.
#
# RULETA E CINSTITĂ: numărul iese din `randi() % 37` (0–36, ruletă europeană cu un singur zero),
# tras ÎNAINTE de animație (`_spin`). Învârtirea în sine — discul, bila, sunetul — stă în
# `casino_roata.gd`; de acolo vine înapoi un semnal (`gata`) când bila s-a oprit, și abia atunci
# se anunță rezultatul.
#
# ⚠️ Roata NU poate arăta numărul: arta ei are 28 de buzunare, nu 37. Ce poate — de pe
# 2026-08-19, când Răzvan a adus o roată desenată fără numere pe ea — e CULOAREA: bila se
# oprește într-un buzunar roșu la număr roșu, negru la negru, în cel verde la 0. Deci se vede pe
# roată ce a ieșit, fără ca roata să mintă. Numărul rămâne scris în butuc, iar căsuța
# câștigătoare se aprinde pe masă.

const MENU_UI_DIR := "res://Upgrades/Menu UI/"
# Imaginile sunt SCOASE din poza mare `harta/EGT/Roulette Table.png` de `tool_egt_assets.gd`
# (masa cu fundalul alb făcut transparent, discul roții decupat rotund, jetonul roșu; bila e
# desenată tot acolo, în cod, fiindcă poza n-are așa ceva).
# Schimbi poza mare → rulezi unealta din nou ȘI remăsori constantele de geometrie de mai jos.
const TABLE_TEX := "res://harta/EGT/table.png"
const CHIP_TEX := "res://harta/EGT/chip_red.png"
const ROATA := preload("res://casino_roata.gd")   # discul care se învârte + bila + sunetul ei

# --- rama de meniu (planșa lui Răzvan, pusă în joc pe 2026-08-07) ---
const SHEET := "res://harta/EGT/Border EGT.png"
const CELULA := 64          # cât are o celulă din planșă
# ⚠️ Celula se MĂREȘTE de ZOOM ori (vecinul cel mai apropiat, deci rămâne pixel art curat) înainte
# să ajungă textură: nine-patch-ul întinde doar MIJLOCUL laturilor, nu și grosimea lor, iar o
# celulă de 64px pusă pe un panou de 1000 lăsa linii de 1px — un chenar desenat cu pixul.
const ZOOM := 2
# Ce chenar din planșă folosim (coloană, rând), numărate de la 0 din stânga-sus.
const CH_PANOU := Vector2i(2, 0)     # colțuri în spirală + linie dublă — panoul mare
const CH_SLOT := Vector2i(1, 2)      # chenar subțire cu colțuri mici — un slot de item
const CH_PREMIU := Vector2i(3, 2)    # octogon cu spirale — cutia premiului
# ⚠️ NU folosi celulele (0,1) și (0,3): au pătrate ALBE în colțuri (sunt marcaje de planșă).

# Culorile scoase din artă: arama chenarelor (cea mai deasă nuanță din PNG e #C37450) plus un os
# pentru text. `ACCENT` era auriul vechi din `Menu.png` — schimbat aici o dată, se schimbă peste
# tot în cazinou, fiindcă tot fișierul îl citește de aici.
const ACCENT := Color8(198, 118, 80)        # arama aprinsă
const ACCENT_CLAR := Color8(222, 152, 116)  # aceeași, luminată (evidențieri)
const ACCENT_STINS := Color8(116, 62, 42)   # aceeași, dată în întuneric (contururi, muchii stinse)
const OS_ALB := Color8(232, 224, 214)           # alb-os, pentru titluri și nume
const CENUSA := Color8(150, 142, 138)       # gri stins, pentru textul de ajutor
const BTN_MAIN := Color8(26, 22, 28)        # umplutura butoanelor: piatră întunecată
const BTN_SECOND := ACCENT_STINS            # muchia lor

# Cât se ÎNMULȚEȘTE un status bifat dacă pariul iese — pe TIP de pariu (cerut de Răzvan pe
# 2026-07-30; până atunci toate plăteau 2×, deci un număr plin nu avea niciun rost).
const CASTIG_MULT := {
	"numar": 20.0,    # număr plin — o șansă din 37
	"rosu": 2.0,
	"negru": 2.0,
	"par": 2.0,
	"impar": 2.0,
	"jos": 3.0,       # căsuța scrisă „1-12" pe poză (vezi JOS_MAXIM)
	"sus": 3.0,       # „19-36"
	"duzina": 3.0,    # 1st 12 / 2nd 12 / 3rd 12
	"coloana": 3.0,   # cele trei „2 to 1"
}
# Dacă pierzi, statusul se înjumătățește — la fel pentru orice pariu.
const PIERDERE_MULT := 0.5

# --- BANAT PENTRU „TRIȘAT" (cerut de Răzvan pe 2026-08-11) ---
# Trei câștiguri LA RÂND la ruletă și cazinoul te dă afară pentru tot run-ul: „You've been banned
# for cheating". Al treilea câștig se ÎNCASEAZĂ normal (statusul se dublează) și abia apoi cade
# banul — altfel ar arăta ca și cum jocul ți-a furat rotirea câștigătoare.
#
# Șirul se numără pe RUNDĂ, nu pe vizită: nodul cazinoului e unul singur, stă în `main.tscn` și
# trăiește cât runda, deci nu poți ieși din meniu după două câștiguri ca să o iei de la capăt, și
# nici nu scapi mergând la alt aparat EGT (toate deschid acest nod). O pierdere duce șirul înapoi
# la 0. Trade-up-ul nu are câștig/pierdere, deci nu intră la socoteală.
# La restart, `reload_current_scene()` face nodul din nou → și șirul, și banul pornesc curate.
const CASTIGURI_BAN := 3
const BAN_INTARZIERE := 1.7   # cât rămâne rezultatul pe ecran înainte să apară ecranul de ban (sec)

# --- NOROCUL la ruletă (cerut de Răzvan pe 2026-07-30) ---
# Norocul strâns în rundă (Unusual Clover, The Office...) înclină și ruleta: +1 PUNCT PROCENTUAL
# de șansă la pariul pus, pentru fiecare 10 puncte de noroc. Fără noroc, roșul are 18 din 37 =
# 48,65%; cu 10 noroc are 49,65%, cu 50 de noroc 53,65%.
#
# 🔑 Punctele în plus se iau DOAR de la numerele care pierd, niciodată de la ZERO: verdele își
# păstrează mereu 1/37 = 2,70%. Adică norocul îți ia din adversar, nu din avantajul casei — la
# roșu ridică roșul și coboară negrul, exact ca în exemplul cerut (49/49/1 → 50/48/1).
#
# ⚠️ Rata NU e `player.luck_bonus()` (0,4 puncte pe noroc). Acolo norocul umflă șanse mici, de
# proc (crit, instakill), unde 0,4 pe punct e mărunt. Aici s-ar aplica peste o șansă de ~50%,
# iar 50 de noroc ar duce roșul la 68% — masa nu s-ar mai numi ruletă. De-aia are rata ei.
const LUCK_PER := 0.001   # +0,1 puncte procentuale de șansă pe punct de noroc (10 noroc = +1%)

# ---------------------------------------------------------------------------
# GEOMETRIA MESEI, în pixelii pozei (1648×954). Toate zonele de click de mai jos sunt date în
# acești pixeli și se transformă în ANCORE (fracții din poză), ca masa să meargă identic la
# orice rezoluție. Cifrele sunt MĂSURATE pe liniile albe din poză, nu ghicite — dacă schimbi
# poza mesei, remăsoară-le (unealta care le-a scos căuta coloanele/rândurile de pixeli albi).
# ---------------------------------------------------------------------------
# ⚠️ Toate cifrele de mai jos sunt de pe poza adusă de Răzvan pe 2026-08-19 (1660×948). Masa e
# desenată de mână, deci liniile nu cad la distanțe egale: cifrele sunt POTRIVITE pe cele 13
# linii albe măsurate (cea mai bună dreaptă prin ele), nu luate din prima și ultima. Diferența
# maximă față de linia adevărată e ~3 px dintr-o căsuță de 69 — sub un fir de păr pe ecran.
const TABLE_W := 1660.0
const TABLE_H := 948.0

const GRID_X0 := 655.0     # marginea stângă a grilei de numere (1–36)
const GRID_X1 := 1481.0    # marginea dreaptă
const GRID_Y0 := 295.0     # marginea de sus
const GRID_Y1 := 535.0     # marginea de jos
const COL_W := (GRID_X1 - GRID_X0) / 12.0   # lățimea unei coloane (12 coloane)
const ROW_H := (GRID_Y1 - GRID_Y0) / 3.0    # înălțimea unui rând (3 rânduri)

const ZERO_RECT := Rect2(586, 295, 68, 240)   # căsuța rotunjită cu „0", în stânga grilei
const COL2_X0 := 1481.0                        # coloana de „2 to 1", în dreapta grilei
const COL2_X1 := 1541.0
const DOZ_Y0 := 537.0      # rândul cu 1st 12 / 2nd 12 / 3rd 12
const DOZ_Y1 := 613.0
const OUT_Y0 := 617.0      # rândul de jos: 1-12 / EVEN / roșu / negru / ODD / 19-36
const OUT_Y1 := 694.0

# Centrul roții nu e ochiometru: l-a ales un căutător care măsoară raza ramei de aur la 360 de
# unghiuri și ia punctul care o face cât mai constantă (a ieșit 260,5 / 649,5, raza 171).
const WHEEL_CENTER := Vector2(260.5, 649.5)   # centrul discului roții în poza mare
const WHEEL_R := 174.0                        # raza discului decupat (wheel.png e 348×348)

# Numerele ROȘII de pe o ruletă europeană (restul, în afară de 0, sunt negre).
# Poza mesei le respectă exact — verificat număr cu număr.
const ROSII := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

# ⚠️ Căsuța din stânga jos scrie „1-12" pe poză, deși pe o masă adevărată acolo scrie „1-18".
# Am lăsat-o să facă exact ce scrie pe ea (câștigă la 1–12), ca să nu pară că jocul trișează.
# Vrei regula adevărată de ruletă? Schimbă cifra de mai jos în 18.
const JOS_MAXIM := 12

# ---------------------------------------------------------------------------
# STATUSURILE care se pot paria. Apar în dreapta mesei DOAR dacă valoarea lor de acum e > 0 —
# n-are rost să bifezi un status pe 0 (dublul lui e tot 0, deci ar fi un pariu fără risc).
# `jos_e_bine` = la statusul ăsta MAI MIC înseamnă mai bun (tragi mai des / încasezi mai puțin),
# deci la CÂȘTIG valoarea se împarte, nu se înmulțește.
# ---------------------------------------------------------------------------
const STATS := [
	{"id": "damage",    "nume": "Damage"},
	{"id": "atkspeed",  "nume": "Attack Speed", "jos_e_bine": true},
	{"id": "crit",      "nume": "Crit"},
	{"id": "proj",      "nume": "Projectiles"},
	{"id": "pierce",    "nume": "Pierce"},
	{"id": "wsize",     "nume": "Weapon Size"},
	{"id": "knockback", "nume": "Knockback"},
	{"id": "instakill", "nume": "Instakill"},
	{"id": "luck",      "nume": "Luck"},
	{"id": "speed",     "nume": "Move Speed"},
	{"id": "maxhp",     "nume": "Max HP"},
	{"id": "regen",     "nume": "HP Regen"},
	# „Damage Taken" a fost aici până pe 2026-08-14, când statul a ieșit de tot din joc.
]

# ---------------------------------------------------------------------------
# TRADE-UP CONTRACT — „Gamble your items" (cerut de Răzvan pe 2026-08-07)
# ---------------------------------------------------------------------------
# Regula, ca la CS:GO: pui `TU_CATE` (3) iteme de ACEEAȘI raritate și primești UNUL cu o treaptă
# mai sus. Nu vezi ce pică până nu tragi — vezi doar RARITATEA premiului, fiindcă ea e decisă de
# ce ai băgat tu. Itemul câștigat se trage CINSTIT, înainte de orice animație (exact ca numărul
# de la ruletă, `_spin`); rularea de iconițe de deasupra e doar spectacol.
#
# ⚠️ Legendary NU poate fi urcat: peste el nu mai e nimic, deci `raritate_mai_sus` l-ar da tot
# Legendary și ai schimba 3 pe 1 în pierdere curată. Itemele legendare apar în listă, dar stinse.
#
# ⚠️⚠️ DE CE COSTĂ DIFICULTATE, deși ai dat 3 iteme pe 1. Fiindcă efectele NU se iau înapoi:
# ca peste tot în joc (vezi `ender_statue.gd` și README), un item se aplică o dată, la luare,
# direct pe statusuri, iar jumătate din ele nici n-ar putea fi anulate (Panic Button a explodat
# deja, Wine te-a vindecat deja). Deci din cele 3 iteme pleacă doar RÂNDUL din registru, nu și
# ce ți-au dat — adică un trade-up e câștig curat, și fără un preț ar fi buton de „mai dă-mi".
# Prețul e același mecanism ca la statuia Ender (`Difficulty.add_trade_penalty`), doar mai mic:
# acolo urci 2 trepte, aici una. **Vrei-l gratis? Pune `TU_COST_PROCENT` pe 0** — atât.
const TU_CATE := 3                  # câte iteme intră într-un contract
const TU_COST_PROCENT := 10.0       # cu cât urcă dificultatea un trade-up (0 = gratis)
const TU_PASI := 18                 # câte iconițe se perindă la dezvăluire
const TU_PAS_START := 0.035         # cât stă prima (secunde)
const TU_PAS_FACTOR := 1.12         # cu cât încetinește la fiecare pas (≈2s în total)

const PANOU_IT_W := 1010.0          # ⚠️ în pixeli de ECRAN DE BAZĂ (1152×648) — vezi trade.gd
# Cel mai înalt lucru care încape pe 648 de pixeli fără să pară înghesuit. Conținutul cel mai
# gras măsurat (30 de iteme, turcă, cu premiul câștigat pe ecran) cere 607 — citit cu
# `get_combined_minimum_size` după o tragere adevărată, nu ghicit. Sub atât, subtitrarea ruptă pe
# două rânduri urcă peste chenar. Golul de sub iteme, care rămâne la un inventar mic, nu se mai
# vede a gaură: scroll-ul stă acum într-o casetă desenată (vezi `_build_iteme`).
const PANOU_IT_H := 612.0
# ⚠️ TOATE CELE PATRU căsuțe au ACEEAȘI latură — cele 3 de intrare și cutia premiului.
# (Răzvan, 2026-08-07: „nu sunt egale cu al 4-lea primele 3".) Sloturile ieșeau și DREPTUNGHIULARE,
# nu doar mai mici: sunt copii de HBoxContainer, iar acesta întinde pe verticală tot ce nu e marcat
# altfel — deci se lungeau până la înălțimea coloanei premiului (cutie + două etichete). Leacul e
# `SIZE_SHRINK_BEGIN` mai jos, care le lasă pătrate ȘI le lipește de marginea de sus, la fel ca
# cutia premiului.
const SLOT_LAT := 116.0
# Cât e de groasă rama desenată, în pixeli de ecran. Măsurat din planșă, nu ghicit: celula (1,2)
# are 6px de ramă, (3,2) are 8px, iar ZOOM le dublează. Sub valorile astea chenarul de RARITATE
# urcă peste aramă — exact „nu intră bine în căsuță".
const RAMA_SLOT := 6 * ZOOM
const RAMA_PREMIU := 8 * ZOOM
# Chenarul de raritate + iconița sunt la fel de mari în toate patru: cât încape în cea mai strâmtă,
# adică în cutia premiului. La sloturi rămâne mai mult joc de fiecare parte, dar acolo e fundalul
# închis al ramei (#201E26), aceeași culoare — deci golul nu se vede, iar itemele se văd egale.
#
# ⚠️ `JOC_CHENAR` = cât rămâne GOL între rama de aramă și chenarul de raritate. Fără el (adică
# `CONTINUT = SLOT_LAT - 2*RAMA_PREMIU`) chenarul de raritate se lipea exact de muchia interioară
# a aramei și cele două rame se citeau ca una singură, groasă și murdară — „fac overlap cu celălalt
# border" (Răzvan, 2026-08-07). Două rame desenate au nevoie de aer între ele ca să se vadă că-s două.
const JOC_CHENAR := 7.0
const CONTINUT := SLOT_LAT - 2.0 * (RAMA_PREMIU + JOC_CHENAR)
const ICON_MARGINE := 11.0          # cât ține rama pictată a chenarului de raritate (~15%, ca în inventar)
const CELULA_IT := 62.0             # latura unei iconițe din inventar
const GRILA_COL := 12               # câte iteme pe un rând de inventar

# ---------------------------------------------------------------------------
var _pagina := "intro"
var _pariu = null              # dicționarul pariului curent (vezi `_castiga`), sau null
var _pariu_rect := Rect2()     # zona lui pe masă, în pixelii pozei (acolo se pune jetonul)
var _evid_rect := Rect2()      # căsuța numărului ieșit (se evidențiază după învârtire)
# Statusul bifat în dreapta — UNUL SINGUR („" = niciunul). Cerut de Răzvan pe 2026-08-03:
# până atunci era un dicționar de bifate și puteai trimite câte statusuri voiai la aceeași
# învârtire, adică un singur zar decidea jumătate din build. Bifele sunt ținute exclusive de
# un `ButtonGroup` (vezi `_umple_statusuri`), deci regula se vede pe ecran, nu doar în cod.
var _ales := ""
var _se_invarte := false
var _castiguri_la_rand := 0    # câte câștiguri consecutive are la ruletă (vezi CASTIGURI_BAN)
var _banat := false            # dat afară din cazinou pentru tot run-ul

var _pag_intro: Control
var _pag_masa: Control
var _pag_ban: Control
var _lbl_motiv: Label          # „3 wins in a row" de pe ecranul de ban
var _masa: TextureRect
var _roata: Control            # `casino_roata.gd` — discul, bila și sunetul învârtirii
var _jeton: TextureRect
var _evid: Panel
# ⚠️ `_nr_iesit` e ETICHETA cu numărul din butuc, nu bila. Până pe 2026-08-19 se numea `_bila`,
# fiindcă bilă adevărată nu exista; acum există una (în `casino_roata.gd`) și două lucruri cu
# același nume în același ecran sunt o capcană gata pusă.
var _nr_iesit: Label           # numărul ieșit, scris în butucul roții
var _panou: NinePatchRect
var _lista_stat: VBoxContainer
var _lbl_pariu: Label
var _lbl_plata: Label          # cât plătește pariul ales (×20, ×3, ×2)
var _btn_spin: Button
var _rezultat: VBoxContainer
var _banner: Label

# --- trade-up ---
var _pag_iteme: Control
var _sheet: Image = null       # planșa de chenare, citită o singură dată
var _sel := []                 # ce indici din `player.run_items` sunt puși în contract
var _rar_blocata := ""         # raritatea impusă de prima alegere ("" = niciuna încă)
var _rula := false             # cât se perindă iconițele la dezvăluire
var _sloturi := []             # cele TU_CATE sloturi de intrare: {"cell", "icon", "border", "x"}
var _premiu := {}              # cutia premiului: {"icon", "border", "semn", "nume", "rar", "box"}
var _grila: GridContainer
var _lbl_stare: Label
var _lbl_cost_it: Label
var _btn_tradeup: Button

func _ready() -> void:
	add_to_group("casino")
	process_mode = Node.PROCESS_MODE_ALWAYS   # merge și când jocul e pe pauză
	layer = 12                                # peste HUD și Level Up (10), sub meniul de pauză (15)
	visible = false

	var overlay := ColorRect.new()
	# aproape opac: la 0.93 se mai citea cronometrul din HUD prin bannerul cu rezultatul
	overlay.color = Color(0.07, 0.06, 0.09, 0.985)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_build_intro()
	_build_masa()
	_build_iteme()
	_build_ban()
	_arata_pagina("intro")
	get_viewport().size_changed.connect(_relayout)

# ---------------------------------------------------------------------------
# DESCHIDERE / ÎNCHIDERE
# ---------------------------------------------------------------------------
func open() -> void:
	if visible:
		return
	visible = true
	_arata_pagina("intro")
	get_tree().paused = true
	Audio.pause_forest_ambient()   # ambientul se oprește cât joci; se reia de unde a rămas
	Audio.play("levelup", -4.0, 0.0)

func _inchide() -> void:
	if _se_invarte or _rula:
		return                     # nu pleca din mijlocul unei învârtiri / dezvăluiri
	visible = false
	get_tree().paused = false
	Audio.resume_forest_ambient()

# ESC: de la masă înapoi la meniu, din meniu afară din cazinou.
# ⚠️ Ca să nu se deschidă meniul de pauză PESTE cazinou, `pause.gd::_blocked()` întreabă și de noi.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _pagina == "masa":
		if not _se_invarte:
			_arata_pagina("intro")
	elif _pagina == "iteme":
		if not _rula:            # nu pleca din mijlocul unei dezvăluiri
			_arata_pagina("intro")
	else:
		_inchide()

func _arata_pagina(care: String) -> void:
	# Banat = nu mai există alt ecran în cazinou. Redirectarea stă AICI, într-un singur loc, ca să
	# nu poată fi ocolită: și `open()`, și ESC-ul de pe masă, și butoanele „Back" trec pe aici.
	if _banat:
		care = "ban"
	_pagina = care
	_pag_intro.visible = (care == "intro")
	_pag_masa.visible = (care == "masa")
	_pag_iteme.visible = (care == "iteme")
	_pag_ban.visible = (care == "ban")
	if care == "masa":
		_reseteaza_masa()
		_relayout()
	elif care == "iteme":
		_reseteaza_iteme()
	elif care == "ban":
		_lbl_motiv.text = tr("%d wins in a row") % CASTIGURI_BAN   # tr() explicit: are %d, vezi i18n.gd

# ---------------------------------------------------------------------------
# ECRANUL 1 — „Let's go gambling"
# ---------------------------------------------------------------------------
func _build_intro() -> void:
	_pag_intro = Control.new()
	_pag_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pag_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pag_intro)

	# Panoul din planșa de chenare, centrat. Nu mai e text plutind pe un ecran negru: alegerea
	# stă într-o cutie, ca la orice meniu comercial.
	var pw := 620.0
	var ph := 430.0
	var panel := _cadru(CH_PANOU, 16)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -pw / 2.0
	panel.offset_right = pw / 2.0
	panel.offset_top = -ph / 2.0
	panel.offset_bottom = ph / 2.0
	_pag_intro.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	var titlu := Label.new()
	titlu.text = "Let's go gambling"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titlu.add_theme_font_size_override("font_size", 46)
	titlu.add_theme_color_override("font_color", OS_ALB)
	# contur de ARAMĂ, nu negru: la un titlu alb pe negru ține loc de aureolă și leagă textul de
	# rama artei, fără shader și fără font nou (același truc ca la `trade.gd`).
	titlu.add_theme_color_override("font_outline_color", ACCENT_STINS)
	titlu.add_theme_constant_override("outline_size", 6)
	box.add_child(titlu)
	# respiră încet, ca reclama unui aparat de bani
	var puls := create_tween().set_loops()
	puls.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	puls.tween_property(titlu, "modulate:a", 0.74, 1.3).set_trans(Tween.TRANS_SINE)
	puls.tween_property(titlu, "modulate:a", 1.0, 1.3).set_trans(Tween.TRANS_SINE)

	box.add_child(_linie(300.0, 12))
	box.add_child(_spatiu(6))

	box.add_child(_buton("Gamble your stats", _on_stats))
	box.add_child(_buton("Gamble your items", _on_items))

	box.add_child(_spatiu(10))
	box.add_child(_buton("Leave", _inchide))

# ---------------------------------------------------------------------------
# ECRANUL 4 — BANAT (vezi CASTIGURI_BAN)
# ---------------------------------------------------------------------------
# Aceeași croială ca ecranul de intro (același panou de aramă, aceeași ierarhie pe mărime), doar
# că titlul e roșu: e singura dată când cazinoul îți spune „nu". Nu are decât butonul „Leave" —
# un buton care nu duce nicăieri ar fi o promisiune mincinoasă.
func _build_ban() -> void:
	_pag_ban = Control.new()
	_pag_ban.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pag_ban.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pag_ban)

	var pw := 700.0
	var ph := 430.0
	var panel := _cadru(CH_PANOU, 16)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -pw / 2.0
	panel.offset_right = pw / 2.0
	panel.offset_top = -ph / 2.0
	panel.offset_bottom = ph / 2.0
	_pag_ban.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	var titlu := Label.new()
	titlu.text = "You've been banned for cheating"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# autowrap OBLIGATORIU: e cel mai lung titlu din joc, iar tradus („Zostałeś zbanowany za
	# oszustwo") crește și mai mult — fără el și-ar impune lățimea și ar ieși din panou.
	titlu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titlu.add_theme_font_size_override("font_size", 40)
	titlu.add_theme_color_override("font_color", Color8(214, 78, 64))
	titlu.add_theme_color_override("font_outline_color", Color8(52, 14, 12))
	titlu.add_theme_constant_override("outline_size", 6)
	box.add_child(titlu)

	box.add_child(_linie(340.0, 12))

	# De ce ai fost dat afară — cifra vine din constantă, nu scrisă de mână în text.
	# ⚠️ Textul se pune abia la afișare (`_arata_pagina`), nu aici: fiind ASAMBLAT cu `tr(...) % n`,
	# nu se re-traduce singur când schimbi limba din Settings, iar panoul se construiește o dată,
	# la pornirea rundei. Pus la afișare, e mereu în limba de acum.
	_lbl_motiv = Label.new()
	_lbl_motiv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_motiv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_motiv.add_theme_font_size_override("font_size", 22)
	_lbl_motiv.add_theme_color_override("font_color", OS_ALB)
	_contur(_lbl_motiv)
	box.add_child(_lbl_motiv)

	var cat := Label.new()
	cat.text = "The casino is closed for the rest of the run"
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cat.add_theme_font_size_override("font_size", 15)
	cat.add_theme_color_override("font_color", CENUSA)
	_contur(cat)
	box.add_child(cat)

	box.add_child(_spatiu(10))
	box.add_child(_buton("Leave", _inchide))

func _on_stats() -> void:
	_arata_pagina("masa")

func _on_items() -> void:
	_arata_pagina("iteme")

# ---------------------------------------------------------------------------
# ECRANUL 2 — MASA DE RULETĂ
# ---------------------------------------------------------------------------
func _build_masa() -> void:
	_pag_masa = Control.new()
	_pag_masa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pag_masa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pag_masa)

	# poza mesei. `EXPAND_IGNORE_SIZE` + `STRETCH_SCALE` = se întinde exact cât îi spunem noi în
	# `_relayout()`, fără să-și impună mărimea texturii (1648×954, mult peste ecran).
	_masa = TextureRect.new()
	_masa.texture = load(TABLE_TEX)
	_masa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_masa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_masa.stretch_mode = TextureRect.STRETCH_SCALE
	_masa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pag_masa.add_child(_masa)

	_build_zone()

	# evidențierea căsuței câștigătoare (chenar auriu, fără umplutură)
	_evid = Panel.new()
	_evid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ACCENT_CLAR.r, ACCENT_CLAR.g, ACCENT_CLAR.b, 0.30)
	sb.border_color = ACCENT_CLAR
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(4)
	_evid.add_theme_stylebox_override("panel", sb)
	_evid.visible = false
	_masa.add_child(_evid)

	# jetonul roșu, pus peste zona pe care ai pariat
	_jeton = TextureRect.new()
	_jeton.texture = load(CHIP_TEX)
	_jeton.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_jeton.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_jeton.stretch_mode = TextureRect.STRETCH_SCALE
	_jeton.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jeton.visible = false
	_masa.add_child(_jeton)

	# roata care se învârte, exact peste roata din poză (vezi `casino_roata.gd`)
	_roata = ROATA.new()
	_roata.gata.connect(_arata_rezultat)
	_masa.add_child(_roata)

	# numărul ieșit, scris în butucul roții — deasupra roții, ca să nu-l acopere discul
	_nr_iesit = Label.new()
	_nr_iesit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nr_iesit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nr_iesit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nr_iesit.add_theme_color_override("font_color", Color(1, 1, 1))
	_nr_iesit.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_nr_iesit.add_theme_constant_override("outline_size", 6)
	_nr_iesit.visible = false
	_masa.add_child(_nr_iesit)

	# bannerul cu rezultatul, peste marginea de sus a ecranului
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 12
	_banner.offset_bottom = 52
	_pag_masa.add_child(_banner)

	_build_panou()

# Zonele de click: fiecare e un buton transparent, ancorat pe o fracție din poză (deci se mută
# și se redimensionează singur odată cu masa).
func _build_zone() -> void:
	# 0
	_zona(ZERO_RECT, {"tip": "numar", "n": 0}, "0")
	# 1–36
	for n in range(1, 37):
		_zona(_rect_numar(n), {"tip": "numar", "n": n}, str(n))
	# coloanele „2 to 1" (câte una pe rândul ei)
	var mod_rand := [0, 2, 1]   # rândul 0 = 3,6,…36 (n%3==0); rândul 1 = 2,5,…35; rândul 2 = 1,4,…34
	for r in 3:
		var rect := Rect2(COL2_X0, GRID_Y0 + r * ROW_H, COL2_X1 - COL2_X0, ROW_H)
		_zona(rect, {"tip": "coloana", "m": mod_rand[r]}, "2 to 1")
	# duzinile
	var doz_nume := ["1st 12", "2nd 12", "3rd 12"]
	for i in 3:
		var w := (GRID_X1 - GRID_X0) / 3.0
		_zona(Rect2(GRID_X0 + i * w, DOZ_Y0, w, DOZ_Y1 - DOZ_Y0), {"tip": "duzina", "i": i}, doz_nume[i])
	# rândul de jos, 6 căsuțe egale
	var w6 := (GRID_X1 - GRID_X0) / 6.0
	var jos := [
		[{"tip": "jos"}, "1-%d" % JOS_MAXIM],
		[{"tip": "par"}, "EVEN"],
		[{"tip": "rosu"}, "RED"],
		[{"tip": "negru"}, "BLACK"],
		[{"tip": "impar"}, "ODD"],
		[{"tip": "sus"}, "19-36"],
	]
	for i in jos.size():
		_zona(Rect2(GRID_X0 + i * w6, OUT_Y0, w6, OUT_Y1 - OUT_Y0), jos[i][0], jos[i][1])

# Un buton transparent peste o zonă a mesei. `r` e în pixelii pozei; îl legăm prin ANCORE, deci
# rămâne pe loc la orice mărime a mesei.
func _zona(r: Rect2, pariu: Dictionary, eticheta: String) -> void:
	var b := Button.new()
	b.flat = true
	b.anchor_left = r.position.x / TABLE_W
	b.anchor_right = (r.position.x + r.size.x) / TABLE_W
	b.anchor_top = r.position.y / TABLE_H
	b.anchor_bottom = (r.position.y + r.size.y) / TABLE_H
	b.offset_left = 0.0
	b.offset_top = 0.0
	b.offset_right = 0.0
	b.offset_bottom = 0.0
	b.tooltip_text = eticheta
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _lumina(0.22))
	b.add_theme_stylebox_override("pressed", _lumina(0.35))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_pune_pariu.bind(pariu, r, eticheta))
	_masa.add_child(b)

func _lumina(alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(3)
	return sb

# Căsuța unui număr din grilă, în pixelii pozei.
# Rândul de sus e 3,6,…36 (n%3==0), mijlocul 2,5,…35 (n%3==2), josul 1,4,…34 (n%3==1).
func _rect_numar(n: int) -> Rect2:
	if n == 0:
		return ZERO_RECT
	var col := (n - 1) / 3
	var rand := 0
	if n % 3 == 2:
		rand = 1
	elif n % 3 == 1:
		rand = 2
	return Rect2(GRID_X0 + col * COL_W, GRID_Y0 + rand * ROW_H, COL_W, ROW_H)

func _pune_pariu(pariu: Dictionary, r: Rect2, eticheta: String) -> void:
	if _se_invarte or _banat:
		return
	Audio.play("button", -4.0, 0.0)
	_pariu = pariu
	_pariu_rect = r
	_lbl_pariu.text = tr("Bet: %s") % eticheta
	# „Win x2  ·  49.6%" — procentul e ȘANSA REALĂ, cu norocul inclus, ca să se vadă la ce
	# folosește el aici. Zecimala nu e moft: fără ea, +1 punct de la 10 noroc s-ar rotunji
	# la loc în 49% și ai crede că itemul n-a făcut nimic. Procentul nu are nevoie de traducere.
	_lbl_plata.text = "%s   ·   %.1f%%" % [tr("Win x%s") % _text_plata(pariu), _sansa(pariu) * 100.0]
	_jeton.visible = true
	_evid.visible = false
	_nr_iesit.visible = false
	_roata.reseteaza()      # bila din tura trecută pleacă de pe roată odată cu numărul din butuc
	_banner.text = ""
	_goleste_rezultat()
	_relayout()
	_actualizeaza_spin()

# ---------------------------------------------------------------------------
# PANOUL DIN DREAPTA — ce statusuri bagi în joc
# ---------------------------------------------------------------------------
func _build_panou() -> void:
	# Rama de lemn auriu (`Menu.png`) a plecat de aici pe 2026-08-07, odată cu restul meniului:
	# ea era tot ce mai făcea ecranul „prietenos". Acum e același chenar de aramă ca peste tot.
	_panou = _cadru(CH_PANOU, 16)
	_panou.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_pag_masa.add_child(_panou)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ⚠️ Marginile trebuie să treacă de grosimea ramei desenate (16px de celulă × ZOOM = 32),
	# altfel textul se urcă pe chenarul ornat.
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 36)
	_panou.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var titlu := Label.new()
	titlu.text = "Gamble your stats"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titlu.add_theme_font_size_override("font_size", 17)
	titlu.add_theme_color_override("font_color", ACCENT)
	titlu.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	titlu.add_theme_constant_override("outline_size", 2)
	box.add_child(titlu)

	var sub := Label.new()
	sub.text = "One stat per spin · Lose = half of it"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", CENUSA)
	box.add_child(sub)

	# lista de statusuri, într-un ScrollContainer ca să încapă mereu, oricâte ar fi
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_lista_stat = VBoxContainer.new()
	_lista_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_stat.add_theme_constant_override("separation", 1)
	scroll.add_child(_lista_stat)

	# ⚠️ `autowrap` pe etichetele astea două nu e de frumusețe: o etichetă FĂRĂ autowrap își impune
	# lățimea textului ca mărime MINIMĂ, iar „Place your bet on the table" cerea 291px într-un panou
	# de 345 — împingea tot conținutul (inclusiv butoanele) cu 25px peste rama ornată.
	_lbl_pariu = Label.new()
	_lbl_pariu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_pariu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_pariu.add_theme_font_size_override("font_size", 14)
	_lbl_pariu.add_theme_color_override("font_color", ACCENT)
	box.add_child(_lbl_pariu)

	# cât plătește pariul ales (20× la număr plin, 3× la duzini/coloane, 2× la roșu/negru…)
	_lbl_plata = Label.new()
	_lbl_plata.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_plata.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_plata.add_theme_font_size_override("font_size", 13)
	_lbl_plata.add_theme_color_override("font_color", Color(0.44, 0.86, 0.44))
	box.add_child(_lbl_plata)

	_btn_spin = _buton("SPIN", _spin)
	_btn_spin.custom_minimum_size = Vector2(0, 38)
	_btn_spin.add_theme_font_size_override("font_size", 17)
	box.add_child(_btn_spin)

	_rezultat = VBoxContainer.new()
	_rezultat.add_theme_constant_override("separation", 0)
	box.add_child(_rezultat)

	var inapoi := _buton("Back", _on_back)
	inapoi.custom_minimum_size = Vector2(0, 32)
	inapoi.add_theme_font_size_override("font_size", 15)
	box.add_child(inapoi)

func _on_back() -> void:
	if not _se_invarte:
		_arata_pagina("intro")

# Reumple lista de statusuri cu valorile de ACUM. Se cheamă la fiecare intrare pe masă și după
# fiecare învârtire: valorile s-au schimbat, iar un status ajuns pe 0 iese din listă.
func _umple_statusuri() -> void:
	for c in _lista_stat.get_children():
		_lista_stat.remove_child(c)
		c.queue_free()
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	# Un `ButtonGroup` comun face bifele EXCLUSIVE: apeși pe alta, prima se stinge singură.
	# Grup nou la fiecare reumplere, fiindcă și bifele sunt noduri noi.
	var grup := ButtonGroup.new()
	var vii := {}
	for s in STATS:
		if _valoare(p, s["id"]) <= 0.0:
			continue
		vii[s["id"]] = true
		var hb := HBoxContainer.new()
		var cb := CheckBox.new()
		cb.text = s["nume"]
		cb.button_group = grup
		cb.button_pressed = _ales == s["id"]
		cb.add_theme_font_size_override("font_size", 13)
		cb.add_theme_color_override("font_color", OS_ALB)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.clip_text = true   # un nume lung scurtează, nu lățește panoul peste ramă
		cb.toggled.connect(_on_bifa.bind(s["id"]))
		hb.add_child(cb)
		var val := Label.new()
		val.text = _afisare(p, s["id"])
		val.add_theme_font_size_override("font_size", 13)
		val.add_theme_color_override("font_color", ACCENT)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(val)
		_lista_stat.add_child(hb)
	# un status care a picat pe 0 (ex. Pierce înjumătățit) nu mai există în listă → scoate-l și
	# din bifat, altfel ai fi pariat pe ceva ce nu se mai vede
	if _ales != "" and not vii.has(_ales):
		_ales = ""

# ⚠️ La schimbarea bifei, `ButtonGroup` stinge bifa veche și o aprinde pe cea nouă — deci
# primim DOUĂ semnale, iar ordinea lor nu e garantată. De aia stingem doar dacă cel care
# tocmai s-a stins e chiar cel reținut: așa iese la fel indiferent care semnal vine primul.
func _on_bifa(bifat: bool, id: String) -> void:
	if bifat:
		_ales = id
	elif _ales == id:
		_ales = ""
	if bifat:
		Audio.play("button", -8.0, 0.0)   # o singură dată pe schimbare, nu de două ori
	_actualizeaza_spin()

# SPIN merge doar dacă ai și pariat pe masă, și ales statusul (și dacă nu ești banat).
func _actualizeaza_spin() -> void:
	_btn_spin.disabled = _banat or _se_invarte or _pariu == null or _ales == ""
	if _pariu == null:
		_lbl_pariu.text = "Place your bet on the table"
		_lbl_plata.text = ""

# Cât plătește pariul, scris scurt: „20", „3", „2" (fără „.0" degeaba).
func _text_plata(pariu: Dictionary) -> String:
	return ("%.1f" % _multiplicator(pariu)).trim_suffix(".0")

# Multiplicatorul de CÂȘTIG al unui pariu. Necunoscut → 2×, ca să nu iasă 0 dacă cineva adaugă
# un tip nou de pariu și uită să-l treacă în CASTIG_MULT.
func _multiplicator(pariu: Dictionary) -> float:
	return float(CASTIG_MULT.get(pariu["tip"], 2.0))

func _reseteaza_masa() -> void:
	_pariu = null
	_jeton.visible = false
	_evid.visible = false
	_nr_iesit.visible = false
	_roata.reseteaza()      # fără bilă pe roată; roata rămâne în plutirea ei înceată
	_banner.text = ""
	_goleste_rezultat()
	_umple_statusuri()
	_actualizeaza_spin()

func _goleste_rezultat() -> void:
	for c in _rezultat.get_children():
		_rezultat.remove_child(c)
		c.queue_free()

# ---------------------------------------------------------------------------
# ÎNVÂRTIREA
# ---------------------------------------------------------------------------
func _spin() -> void:
	if _se_invarte or _banat or _pariu == null or _ales == "":
		return
	_se_invarte = true
	_btn_spin.disabled = true
	_evid.visible = false
	_nr_iesit.visible = false
	_banner.text = ""
	_goleste_rezultat()

	# AICI se trage numărul — cinstit, înainte de orice animație (fără noroc: 0–36, toate la fel).
	var n := _trage_numarul(_pariu)

	# Roata primește numărul și CULOAREA lui, ca să aleagă un buzunar de culoarea aia; rezultatul
	# se anunță abia când bila s-a oprit acolo (semnalul `gata` → `_arata_rezultat`, legat în
	# `_build_masa`). Cât ține învârtirea hotărăște ea, nu un cronometru de aici: bila cade când
	# îi ajunge buzunarul sub ea, ca la masa adevărată (~4,5–5,5 s).
	_roata.invarte(n, _nume_culoare(n))

func _arata_rezultat(n: int) -> void:
	var castigat := _castiga(_pariu, n)
	var culoare := _culoarea(n)

	# numărul ieșit, în butucul roții, pe fundalul culorii lui
	_nr_iesit.text = str(n)
	var sb := StyleBoxFlat.new()
	sb.bg_color = culoare
	sb.border_color = ACCENT_CLAR
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(999)
	_nr_iesit.add_theme_stylebox_override("normal", sb)
	_nr_iesit.visible = true

	# evidențiem căsuța lui de pe masă
	_evid_rect = _rect_numar(n)
	_evid.visible = true

	# `tr(...)` explicit: textul e ASAMBLAT din bucăți, deci auto-translate n-ar avea ce cheie să
	# caute (ar căuta „25 RED — YOU LOSE"). Vezi i18n.gd. Numele culorii rămâne netradus, ca pe masă.
	_banner.text = "%s %s  —  %s" % [str(n), _nume_culoare(n), tr("YOU WIN!") if castigat else tr("YOU LOSE")]
	_banner.add_theme_color_override("font_color", Color(0.44, 0.86, 0.44) if castigat else Color(0.92, 0.38, 0.36))
	Audio.play("chest_anim" if castigat else "hurt", -2.0, 0.0)

	_aplica_pariul(castigat)
	_umple_statusuri()
	_se_invarte = false

	# ȘIRUL DE CÂȘTIGURI → banul. Se numără DUPĂ ce câștigul a fost încasat (vezi CASTIGURI_BAN):
	# al treilea îți dublează statusul ca oricare altul, abia apoi te dă afară.
	_castiguri_la_rand = (_castiguri_la_rand + 1) if castigat else 0
	if _castiguri_la_rand >= CASTIGURI_BAN:
		_banat = true             # de aici, `_actualizeaza_spin` stinge SPIN și masa e moartă

	_actualizeaza_spin()
	_relayout()

	if _banat:
		# Lăsăm rezultatul o clipă pe ecran: banul trebuie citit ca URMAREA câștigului, nu ca o
		# fereastră care a sărit peste el. Tween (nu timer), fiindcă jocul e pe pauză.
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_interval(BAN_INTARZIERE)
		t.tween_callback(_cade_banul)

# Ecranul de ban, la BAN_INTARZIERE secunde după al treilea câștig. Dacă între timp ai ieșit cu
# ESC din cazinou, paginile se schimbă în spate și îl vezi la următoarea apăsare de E — doar că
# `egt.gd` nu-l mai deschide, deci în practică rămâne eticheta de deasupra aparatului.
func _cade_banul() -> void:
	Audio.play("game_over", -8.0, 0.0)
	_arata_pagina("ban")

# Îl întreabă aparatul din lume (`egt.gd`): mai are voie jucătorul la joc?
func e_banat() -> bool:
	return _banat

# Câte puncte procentuale de șansă în plus dă norocul strâns în rundă. `luck` pornește de la 0
# și e ZECIMAL (The Office dă +2,5), deci bonusul curge continuu — 5 noroc dau o jumătate de
# punct, nu zero. Norocul negativ (nu există acum, dar tot îl păstrăm cinstit) nu scade șansa.
func _bonus_noroc() -> float:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not ("luck" in p):
		return 0.0
	return maxf(0.0, float(p.luck)) * LUCK_PER

# Șansa REALĂ ca pariul `pariu` să iasă, cu tot cu noroc. Folosită și la tragere, și la afișarea
# din panou, ca cifra scrisă acolo să fie chiar cea cu care se joacă — nu o socoteală paralelă.
func _sansa(pariu: Dictionary) -> float:
	var baza := 1.0 / 37.0
	return float(_numere_castigatoare(pariu).size()) * baza + _bonus_noroc_util(pariu)

# Numerele (0–36) care câștigă pariul.
func _numere_castigatoare(pariu: Dictionary) -> Array:
	var castig: Array = []
	for n in 37:
		if _castiga(pariu, n):
			castig.append(n)
	return castig

# Bonusul care CHIAR se poate aplica: nu poți muta spre câștig mai multă probabilitate decât au
# numerele care pierd (zero nu intră la socoteală, el rămâne mereu 1/37). Practic n-o să atingi
# plafonul — la roșu ar trebui vreo 480 de noroc — dar fără el, un noroc absurd ar da probabilități
# negative și tragerea ar deveni o prostie în tăcere.
func _bonus_noroc_util(pariu: Dictionary) -> float:
	var castig := _numere_castigatoare(pariu)
	var cate_pierd := 36 - castig.size() + (1 if castig.has(0) else 0)
	if castig.is_empty() or cate_pierd <= 0:
		return 0.0
	return minf(_bonus_noroc(), float(cate_pierd) / 37.0 * 0.99)

# Trage numărul. Fără noroc, toate cele 37 au aceeași greutate. Cu noroc, mutăm puncte procentuale
# de la numerele care PIERD (fără zero) spre cele care câștigă pariul pus — vezi LUCK_PER.
# Suma greutăților rămâne 1, deci roata e tot o roată, doar că înclinată în favoarea ta.
func _trage_numarul(pariu: Dictionary) -> int:
	var baza := 1.0 / 37.0
	var castig := _numere_castigatoare(pariu)
	var bonus := _bonus_noroc_util(pariu)
	if bonus <= 0.0:
		return randi() % 37
	var cate_pierd := 36 - castig.size() + (1 if castig.has(0) else 0)
	var g := PackedFloat32Array()
	g.resize(37)
	var total := 0.0
	for n in 37:
		if castig.has(n):
			g[n] = baza + bonus / float(castig.size())
		elif n == 0:
			g[n] = baza                                  # verdele nu se atinge niciodată
		else:
			g[n] = baza - bonus / float(cate_pierd)
		total += g[n]
	var r := randf() * total
	for n in 37:
		r -= g[n]
		if r < 0.0:
			return n
	return 36   # doar dacă virgula mobilă ne joacă feste pe ultimul pas

# Câștigă pariul dacă a ieșit numărul `n`? Zero pierde la toate pariurile exterioare — ca la
# ruleta adevărată, ăsta e avantajul casei.
func _castiga(pariu: Dictionary, n: int) -> bool:
	match pariu["tip"]:
		"numar":
			return n == int(pariu["n"])
		"rosu":
			return n != 0 and ROSII.has(n)
		"negru":
			return n != 0 and not ROSII.has(n)
		"par":
			return n != 0 and n % 2 == 0
		"impar":
			return n != 0 and n % 2 == 1
		"jos":
			return n >= 1 and n <= JOS_MAXIM
		"sus":
			return n >= 19 and n <= 36
		"duzina":
			return n >= 1 and n <= 36 and (n - 1) / 12 == int(pariu["i"])
		"coloana":
			return n >= 1 and n <= 36 and n % 3 == int(pariu["m"])
	return false

func _culoarea(n: int) -> Color:
	if n == 0:
		return Color(0.10, 0.45, 0.20)
	return Color(0.78, 0.13, 0.13) if ROSII.has(n) else Color(0.12, 0.12, 0.12)

func _nume_culoare(n: int) -> String:
	if n == 0:
		return "GREEN"
	return "RED" if ROSII.has(n) else "BLACK"

# ---------------------------------------------------------------------------
# EFECTUL PE STATUSURI
# ---------------------------------------------------------------------------
func _aplica_pariul(castigat: bool) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	# Câștigul depinde de PARIU (număr plin 20×, duzină/coloană 3×, roșu/negru 2×), pierderea nu:
	# oricum ai pariat, pierzi jumătate.
	var f: float = _multiplicator(_pariu) if castigat else PIERDERE_MULT
	for s in STATS:
		if s["id"] != _ales:
			continue
		var inainte := _afisare(p, s["id"])
		_aplica(p, s["id"], f)
		var dupa := _afisare(p, s["id"])
		var l := Label.new()
		l.text = "%s  %s → %s" % [tr(s["nume"]), inainte, dupa]   # tr() explicit: text asamblat
		# autowrap din același motiv ca la `_lbl_pariu`: fără el, un rând lung („Move Speed
		# 230 → 4600") își impune lățimea și scoate tot panoul din rama ornată.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.44, 0.86, 0.44) if castigat else Color(0.92, 0.38, 0.36))
		_rezultat.add_child(l)

# Valoarea de ACUM a unui status (număr brut, folosit ca să știm dacă e > 0).
func _valoare(p, id: String) -> float:
	match id:
		"damage":    return float(p.bullet_damage)
		"atkspeed":  return p.fire_interval
		"crit":      return p.crit_chance
		"proj":      return float(p.projectiles_total())
		"pierce":    return float(p.pierce)
		"wsize":     return p.weapon_size_mult
		"knockback": return p.knockback
		"instakill": return p.instakill_chance
		"luck":      return p.luck
		"speed":     return p.speed
		"maxhp":     return float(p.max_hp)
		"regen":     return float(p.hp_regen)
	return 0.0

# Cum se scrie statusul pe ecran — aceleași formate ca în panoul din meniul de Level Up.
func _afisare(p, id: String) -> String:
	match id:
		"damage":    return str(p.bullet_damage)
		"atkspeed":  return "%.2f/s" % (1.0 / maxf(p.fire_interval, 0.01))
		"crit":      return "%d%%" % round(p.crit_chance_now() * 100.0)
		"proj":      return str(p.projectiles_total())
		"pierce":    return str(p.pierce)
		"wsize":     return "%d%%" % round(p.weapon_size_scale() * 100.0)
		"knockback": return str(int(round(p.knockback)))
		"instakill": return "%.1f%%" % (p.instakill_chance_now() * 100.0)
		"luck":      return ("%.1f" % p.luck).trim_suffix(".0")
		"speed":     return str(int(round(p.speed)))
		"maxhp":     return str(p.max_hp)
		"regen":     return "%d/s" % p.hp_regen
	return ""

# Înmulțește un status cu `f` — factorul vine deja calculat din `_aplica_pariul()`: la câștig e
# plata pariului (20× / 3× / 2×), la pierdere e 0,5.
#
# Plafoanele de jos NU sunt cosmetice: fără ele o pierdere te poate lăsa cu 0 proiectile (nu mai
# tragi deloc) sau cu 0 viață maximă (mori pe loc), adică jocul s-ar termina de la o rotire —
# altceva decât „pierzi jumătate din status".
func _aplica(p, id: String, f: float) -> void:
	match id:
		"damage":
			p.bullet_damage = maxi(1, _intreg(p.bullet_damage, f))
		"atkspeed":
			# aici mai MIC = mai bun, deci la câștig se împarte. `upgrade_fire_rate` schimbă ȘI
			# cronometrul de tragere — dacă scrii direct în `fire_interval`, cadența nu se schimbă.
			var nou := clampf(p.fire_interval / f, 0.02, 5.0)
			p.upgrade_fire_rate(nou / p.fire_interval)
		"crit":
			p.crit_chance *= f
		"proj":
			# ⚠️ Proiectilele câștigate la ruletă trebuie să fie DE ACELAȘI FEL cu cele date de
			# iteme (Gunslinger, Twin Comets): salve întregi trase în ALȚI inamici, adică
			# `stacked_armory_stacks`. Până pe 2026-07-30 se scria în `bullet_count` — gloanțe
			# PARALELE, pe lângă aceeași țintă — o mecanică pe care niciun item n-o mai dă din
			# 2026-07-21 (vezi comentariul de la `player.bullet_count`). Ieșea altceva decât
			# scria pe stat și altceva decât se aștepta jucătorul.
			#
			# Socotim pe TOTAL (`projectiles_total()` = paralele + bonus), exact numărul afișat
			# în panou, iar diferența o punem în bonusuri. `bullet_count` rămâne 1.
			var total := maxi(1, _intreg(p.projectiles_total(), f))
			p.stacked_armory_stacks = maxi(0, total - p.bullet_count)
		"pierce":
			p.pierce = maxi(0, _intreg(p.pierce, f))
		"wsize":
			p.weapon_size_mult *= f
		"knockback":
			p.knockback *= f
		"instakill":
			p.instakill_chance = clampf(p.instakill_chance * f, 0.0, 1.0)
		"luck":
			p.luck *= f
		"speed":
			p.speed = clampf(p.speed * f, 60.0, 4000.0)
		"maxhp":
			# viața de acum se mută cu aceeași cantitate ca maximul (ca la `upgrade_max_hp`), dar
			# nu sub 1: o înjumătățire nu trebuie să te omoare, doar să te lase fragil.
			var nou_hp := maxi(10, _intreg(p.max_hp, f))
			var delta: int = nou_hp - p.max_hp
			p.max_hp = nou_hp
			p.hp = clampi(p.hp + delta, 1, p.max_hp)
		"regen":
			p.hp_regen = maxi(0, _intreg(p.hp_regen, f))

# Înmulțire pe numere ÎNTREGI: la câștig rotunjim normal, la pierdere TĂIEM în jos (1 → 0),
# altfel `round(1 * 0.5)` ar da tot 1 și un status pe 1 n-ar putea fi pierdut niciodată.
func _intreg(v: int, f: float) -> int:
	if f >= 1.0:
		return int(round(float(v) * f))
	return int(floor(float(v) * f))

# ---------------------------------------------------------------------------
# ECRANUL 3 — TRADE-UP CONTRACT („Gamble your items")
# ---------------------------------------------------------------------------
func _build_iteme() -> void:
	_pag_iteme = Control.new()
	_pag_iteme.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pag_iteme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pag_iteme)

	var panel := _cadru(CH_PANOU, 16)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANOU_IT_W / 2.0
	panel.offset_right = PANOU_IT_W / 2.0
	panel.offset_top = -PANOU_IT_H / 2.0
	panel.offset_bottom = PANOU_IT_H / 2.0
	_pag_iteme.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var titlu := Label.new()
	titlu.text = "TRADE-UP CONTRACT"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.add_theme_font_size_override("font_size", 34)
	titlu.add_theme_color_override("font_color", OS_ALB)
	titlu.add_theme_color_override("font_outline_color", ACCENT_STINS)
	titlu.add_theme_constant_override("outline_size", 6)
	box.add_child(titlu)

	box.add_child(_linie(420.0, 10))

	var sub := Label.new()
	sub.text = "Three of the same rarity become one of the next"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", CENUSA)
	_contur(sub)
	box.add_child(sub)

	var secret := Label.new()
	secret.text = "You do not see what you get until you pull"
	secret.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secret.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	secret.add_theme_font_size_override("font_size", 15)
	secret.add_theme_color_override("font_color", ACCENT)
	_contur(secret)
	box.add_child(secret)

	box.add_child(_spatiu(10))

	# rândul contractului: [slot][slot][slot]  ➜  [cutia premiului]
	var contract := HBoxContainer.new()
	contract.alignment = BoxContainer.ALIGNMENT_CENTER
	contract.add_theme_constant_override("separation", 10)
	contract.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(contract)

	_sloturi.clear()
	for i in TU_CATE:
		contract.add_child(_fa_slot(i))

	var sageata := Label.new()
	sageata.text = "➜"
	# înaltă exact cât o căsuță și lipită de sus: așa săgeata stă la mijlocul RÂNDULUI DE CĂSUȚE,
	# nu la mijlocul coloanei premiului (care are două etichete sub ea și ar trage-o în jos)
	sageata.custom_minimum_size = Vector2(70, SLOT_LAT)
	sageata.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sageata.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sageata.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sageata.add_theme_font_size_override("font_size", 34)
	sageata.add_theme_color_override("font_color", ACCENT)
	sageata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contur(sageata)
	contract.add_child(sageata)

	contract.add_child(_fa_premiu())

	box.add_child(_spatiu(8))

	_lbl_stare = Label.new()
	_lbl_stare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_stare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_stare.add_theme_font_size_override("font_size", 17)
	_lbl_stare.add_theme_color_override("font_color", OS_ALB)
	_contur(_lbl_stare)
	box.add_child(_lbl_stare)

	_lbl_cost_it = Label.new()
	_lbl_cost_it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_cost_it.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_cost_it.add_theme_font_size_override("font_size", 15)
	_lbl_cost_it.add_theme_color_override("font_color", Color8(206, 74, 60))
	_contur(_lbl_cost_it)
	box.add_child(_lbl_cost_it)

	box.add_child(_spatiu(8))

	var cap := Label.new()
	cap.text = "YOUR ITEMS"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", ACCENT_CLAR)
	_contur(cap)
	box.add_child(cap)

	# Inventarul, într-un ScrollContainer: la 30 de iteme n-ar încăpea altfel, iar panoul TREBUIE
	# să rămână de mărime fixă (vezi PANOU_IT_H — 1152×648 e tot ecranul pe care îl avem).
	# ⚠️ Scroll-ul înghite toată înălțimea rămasă, deci cu un singur rând de iteme sub ele rămâne
	# mult loc gol. De aia stă într-o CASETĂ desenată (fund închis + muchie de aramă stinsă): golul
	# se citește ca „rafturi goale de inventar", nu ca o gaură în meniu.
	var cutie := PanelContainer.new()
	cutie.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.086, 0.078, 0.104, 0.85)
	sb.border_color = Color(ACCENT_STINS.r, ACCENT_STINS.g, ACCENT_STINS.b, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(8)
	cutie.add_theme_stylebox_override("panel", sb)
	box.add_child(cutie)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cutie.add_child(scroll)

	_grila = GridContainer.new()
	_grila.columns = GRILA_COL
	_grila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grila.add_theme_constant_override("h_separation", 6)
	_grila.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grila)

	box.add_child(_spatiu(8))

	var jos := HBoxContainer.new()
	jos.alignment = BoxContainer.ALIGNMENT_CENTER
	jos.add_theme_constant_override("separation", 14)
	box.add_child(jos)
	_btn_tradeup = _buton("TRADE UP", _trade_up)
	_btn_tradeup.custom_minimum_size = Vector2(260, 46)
	_btn_tradeup.add_theme_font_size_override("font_size", 20)
	jos.add_child(_btn_tradeup)
	var inapoi := _buton("Back", _on_back_iteme)
	inapoi.custom_minimum_size = Vector2(180, 46)
	inapoi.add_theme_font_size_override("font_size", 18)
	jos.add_child(inapoi)

func _on_back_iteme() -> void:
	if not _rula:
		_arata_pagina("intro")

# Un slot de intrare: chenar de aramă gol, în care aterizează iconița itemului ales.
# E un BUTON, nu un simplu Control: click pe o căsuță plină scoate itemul din contract și îl dă
# înapoi în inventar (cerut de Răzvan pe 2026-08-07). Gol, butonul e stins, deci nu face nimic.
func _fa_slot(poz: int) -> Control:
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(SLOT_LAT, SLOT_LAT)
	# ⚠️ SHRINK_BEGIN, nu implicitul: vezi comentariul de la SLOT_LAT — altfel HBox-ul întinde
	# căsuța pe toată înălțimea rândului și iese dreptunghi.
	cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cell.flat = true
	cell.disabled = true
	for stare in ["normal", "hover", "pressed", "focus", "disabled"]:
		cell.add_theme_stylebox_override(stare, StyleBoxEmpty.new())
	cell.pressed.connect(_scoate_slot.bind(poz))

	var cadru := _cadru(CH_SLOT, 14)
	cadru.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cadru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(cadru)

	var c := _continut(cell)             # chenarul de RARITATE + iconița, la fel ca la premiu

	# „X"-ul se aliniază cu colțul CONȚINUTULUI, nu cu al ramei: stă pe item, nu în golul dintre rame
	var x := _semn_scoate((SLOT_LAT - CONTINUT) * 0.5, 20.0)
	x.visible = false
	cell.add_child(x)

	_sloturi.append({"cell": cell, "icon": c["icon"], "border": c["border"], "x": x})
	return cell

# Chenarul de raritate și iconița, centrate în căsuță. Aceleași dimensiuni la slot și la premiu —
# de aia sunt aici și nu scrise de două ori.
func _continut(cell: Control) -> Dictionary:
	var border := TextureRect.new()
	_centreaza(border, CONTINUT)
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(border)

	var icon := TextureRect.new()
	_centreaza(icon, CONTINUT - 2.0 * ICON_MARGINE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	return {"icon": icon, "border": border}

# Pune un copil fix în mijlocul părintelui, de latura cerută. Ancorele se scriu de mână: preset-ul
# de centru păstrează mărimea de dinainte, iar noi o impunem pe a noastră.
func _centreaza(c: Control, latura: float) -> void:
	c.anchor_left = 0.5
	c.anchor_top = 0.5
	c.anchor_right = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -latura * 0.5
	c.offset_top = -latura * 0.5
	c.offset_right = latura * 0.5
	c.offset_bottom = latura * 0.5

# Semnul „scoate-mă" din colțul din dreapta-sus. „X" simplu, nu „✕": fontul jocului e pixel art și
# n-are garantat semnul frumos, iar un pătrat gol în locul lui ar arăta a bug. Stă mereu vizibil,
# nu doar la hover — pe telefon (jocul e și pe Android) nu există hover.
# `marj` = cât intră dinspre colțul căsuței, ca să stea PE item și nu peste ornamentul de aramă.
func _semn_scoate(marj: float, dim: float) -> Label:
	var x := Label.new()
	x.text = "X"
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -marj - dim
	x.offset_top = marj
	x.offset_right = -marj
	x.offset_bottom = marj + dim
	x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	x.add_theme_font_size_override("font_size", 16)
	x.add_theme_color_override("font_color", ACCENT_CLAR)
	x.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	x.add_theme_constant_override("outline_size", 5)
	x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return x

# Cutia premiului: același tipar, dar cu chenarul ornat și cu un „?" cât timp nu știi ce e.
func _fa_premiu() -> Control:
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 2)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cell := Control.new()
	cell.custom_minimum_size = Vector2(SLOT_LAT, SLOT_LAT)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# pivotul în centru: la aterizare cutia „pocnește" (scale 1.3 → 1.0), iar fără pivot ar sări
	# din colțul stâng-sus în loc să crească din mijloc
	cell.pivot_offset = Vector2(SLOT_LAT, SLOT_LAT) * 0.5
	wrap.add_child(cell)

	var cadru := _cadru(CH_PREMIU, 14)
	cadru.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cadru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(cadru)

	var c := _continut(cell)
	var border: TextureRect = c["border"]
	var icon: TextureRect = c["icon"]

	var semn := Label.new()
	semn.text = "?"
	semn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	semn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	semn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	semn.add_theme_font_size_override("font_size", 38)   # cât să încapă în `CONTINUT`, nu să-l umple
	semn.add_theme_color_override("font_color", ACCENT)
	semn.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	semn.add_theme_constant_override("outline_size", 5)
	semn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(semn)

	var rar := Label.new()
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rar.add_theme_font_size_override("font_size", 14)
	rar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contur(rar)
	wrap.add_child(rar)

	var nume := Label.new()
	nume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# ⚠️ înălțimea a DOUĂ rânduri, rezervată din start deși eticheta e goală: numele câștigat apare
	# abia la aterizare, iar unul lung (turcă, germană) ar crește atunci coloana premiului și ar
	# împinge tot ce e sub ea peste chenarul panoului. Așa locul e ținut dinainte și nimic nu sare.
	nume.custom_minimum_size = Vector2(190, 44)
	nume.max_lines_visible = 2      # și plafonat la două: un nume tradus lung n-are voie să crească panoul
	nume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nume.add_theme_font_size_override("font_size", 16)
	nume.add_theme_color_override("font_color", OS_ALB)
	nume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contur(nume)
	wrap.add_child(nume)

	_premiu = {"box": cell, "icon": icon, "border": border, "semn": semn, "rar": rar, "nume": nume}
	return wrap

# ---------------------------------------------------------------------------
# TRADE-UP: starea ecranului
# ---------------------------------------------------------------------------
func _reseteaza_iteme() -> void:
	_sel.clear()
	_rar_blocata = ""
	_rula = false
	_umple_grila()
	_actualizeaza_contract()

# Inventarul se REDESENEAZĂ întreg la fiecare click. Sunt câteva zeci de iconițe și jocul e pe
# pauză, deci nu costă nimic — în schimb scapă de toată contabilitatea „ce celulă trebuie stinsă
# acum", care e exact locul unde se strecoară bug-urile de interfață.
func _umple_grila() -> void:
	for c in _grila.get_children():
		_grila.remove_child(c)
		c.queue_free()
	var p = get_tree().get_first_node_in_group("player")
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if p == null or lu == null or not ("run_items" in p):
		return
	for i in p.run_items.size():
		var u = lu.item_dupa_id(String(p.run_items[i]))
		if u == null:
			continue
		_grila.add_child(_celula_item(i, u, lu))

func _celula_item(idx: int, u, lu) -> Control:
	var rar := String(u.get("rar", "common"))
	var ales: bool = _sel.has(idx)
	var poate := ales or _poate_alege(rar)

	var b := Button.new()
	b.custom_minimum_size = Vector2(CELULA_IT, CELULA_IT)
	b.flat = true
	b.tooltip_text = String(u["nume"])
	for stare in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(stare, StyleBoxEmpty.new())

	var border := TextureRect.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.texture = load(MENU_UI_DIR + String(lu.RARITIES.get(rar, lu.RARITIES["common"])["border"]))
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(border)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 9
	icon.offset_top = 9
	icon.offset_right = -9
	icon.offset_bottom = -9
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(lu.icon_path(u))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	# Cele trei stări se citesc din OPACITATE: itemul PUS ÎN CONTRACT e stins (a plecat de aici, e
	# sus în slot), cel pe care nu-l poți alege acum e tras spre cenușiu, restul stau la putere
	# plină. ⚠️ Cel ales NU coboară sub ~0.45 și primește un „X" peste el: la 0.22 arăta mort și
	# nimeni nu ghicea că se poate apăsa din nou ca să-l scoți (Răzvan, 2026-08-07).
	if ales:
		# ⚠️ stingerea se pune pe ARTĂ, nu pe buton: `modulate` se moștenește la copii, iar un „X"
		# la 0.45 ar fi fost la fel de greu de văzut ca itemul de sub el
		border.modulate = Color(1, 1, 1, 0.4)
		icon.modulate = Color(1, 1, 1, 0.4)
		b.tooltip_text = String(u["nume"]) + " — " + tr("Click to take it out")
		var x := _semn_scoate(5.0, 15.0)
		x.add_theme_font_size_override("font_size", 13)
		b.add_child(x)
	elif not poate:
		b.modulate = Color(0.52, 0.50, 0.52, 0.55)
	b.disabled = not poate
	b.pressed.connect(_click_item.bind(idx, rar))
	return b

# Poate intra în contract un item de raritatea `rar`?
func _poate_alege(rar: String) -> bool:
	if _rula or _sel.size() >= TU_CATE:
		return false
	if rar == "legendary":
		return false                      # peste Legendary nu mai e nimic — vezi capul secțiunii
	return _rar_blocata == "" or _rar_blocata == rar

func _click_item(idx: int, rar: String) -> void:
	if _rula:
		return
	if _sel.has(idx):
		_sel.erase(idx)
		if _sel.is_empty():
			_rar_blocata = ""             # ai golit contractul → orice raritate e iar liberă
	else:
		if not _poate_alege(rar):
			return
		_sel.append(idx)
		_rar_blocata = rar
	Audio.play("button", -7.0, 0.0)
	_umple_grila()
	_actualizeaza_contract()

# Click pe o căsuță plină din contract → itemul se întoarce în inventar. Aceeași treabă ca al
# doilea click pe iconița din inventar, doar că apucată de celălalt capăt.
func _scoate_slot(poz: int) -> void:
	if _rula or poz < 0 or poz >= _sel.size():
		return
	_sel.remove_at(poz)
	if _sel.is_empty():
		_rar_blocata = ""
	Audio.play("button", -7.0, 0.0)
	_umple_grila()
	_actualizeaza_contract()

# Redesenează sloturile, cutia premiului, textul de stare și butonul.
# `pastreaza_premiu` = tocmai ai câștigat ceva și vrem să rămână pe ecran, nu să revină la „?".
func _actualizeaza_contract(pastreaza_premiu := false) -> void:
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	var p = get_tree().get_first_node_in_group("player")

	for i in _sloturi.size():
		var s: Dictionary = _sloturi[i]
		var plin := false
		if lu != null and p != null and i < _sel.size():
			var u = lu.item_dupa_id(String(p.run_items[int(_sel[i])]))
			if u != null:
				s["border"].texture = load(MENU_UI_DIR + String(lu.RARITIES.get(String(u.get("rar", "common")), lu.RARITIES["common"])["border"]))
				s["icon"].texture = load(lu.icon_path(u))
				s["cell"].tooltip_text = String(u["nume"]) + " — " + tr("Click to take it out")
				plin = true
		if not plin:
			s["border"].texture = null
			s["icon"].texture = null
			s["cell"].tooltip_text = ""
		# căsuța se poate apăsa doar cât e plină ȘI cât nu se învârte: în timpul tragerii contractul
		# e deja bătut în cuie (itemele au fost scoase din registru), un click ar fi minciună
		s["cell"].disabled = not plin or _rula
		s["x"].visible = plin and not _rula

	if not pastreaza_premiu:
		_premiu["icon"].texture = null
		_premiu["semn"].visible = true
		_premiu["nume"].text = ""
		_premiu["box"].scale = Vector2.ONE
		# Chenarul cutiei arată RARITATEA pe care o vei primi, chiar dacă nu vezi itemul: raritatea
		# o hotărăști tu prin ce bagi, deci a o ascunde ar fi minciună, nu suspans.
		if lu != null and _rar_blocata != "":
			var tinta: String = lu.raritate_mai_sus(_rar_blocata, 1)
			var r: Dictionary = lu.RARITIES.get(tinta, lu.RARITIES["common"])
			_premiu["border"].texture = load(MENU_UI_DIR + String(r["border"]))
			_premiu["rar"].text = String(r["nume"])
			_premiu["rar"].add_theme_color_override("font_color", r["color"])
		else:
			_premiu["border"].texture = null
			_premiu["rar"].text = ""

	var gata := _sel.size() == TU_CATE
	_btn_tradeup.disabled = _rula or not gata
	if not _rula:
		if gata:
			_lbl_stare.text = ""
		elif _are_set_posibil():
			_lbl_stare.text = "Pick 3 items of the same rarity"
		else:
			_lbl_stare.text = "You need 3 items of the same rarity"
	_lbl_cost_it.text = "" if TU_COST_PROCENT <= 0.0 else tr("Cost: +%d%% difficulty") % int(round(TU_COST_PROCENT))

# Există măcar o raritate (în afară de Legendary) din care ai TU_CATE bucăți? Doar ca să știm ce
# text de ajutor scriem — „alege 3" n-are sens dacă n-ai din ce.
func _are_set_posibil() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if p == null or lu == null or not ("run_items" in p):
		return false
	var cate := {}
	for id in p.run_items:
		var u = lu.item_dupa_id(String(id))
		if u == null:
			continue
		var r := String(u.get("rar", "common"))
		if r == "legendary":
			continue
		cate[r] = int(cate.get(r, 0)) + 1
		if int(cate[r]) >= TU_CATE:
			return true
	return false

# ---------------------------------------------------------------------------
# TRADE-UP: tragerea
# ---------------------------------------------------------------------------
func _trade_up() -> void:
	if _rula or _banat or _sel.size() != TU_CATE:
		return
	var p = get_tree().get_first_node_in_group("player")
	var lu = get_tree().get_first_node_in_group("levelup_menu")
	if p == null or lu == null:
		return
	var tinta: String = lu.raritate_mai_sus(_rar_blocata, 1)
	# ⚠️ AICI se trage premiul — CINSTIT, înainte de orice animație, exact ca numărul de la ruletă
	# (`_spin`). Perindarea de iconițe de mai jos e decor: dacă rezultatul s-ar alege la sfârșit,
	# n-ar exista nicio deosebire vizibilă, dar codul ar fi unul în care se POATE trișa.
	var castig = lu.item_random_de_raritate(tinta)
	if castig == null:
		_lbl_stare.text = "You need 3 items of the same rarity"   # raritatea de sus e goală (toate luate)
		return

	_rula = true
	_btn_tradeup.disabled = true
	_premiu["semn"].visible = true
	_umple_grila()                       # celulele se sting: nu se mai poate umbla la contract
	Audio.play("chest_open", -5.0, 0.0)

	# Perindarea: iconițe la întâmplare din raritatea premiului, tot mai rar, ca la un aparat de
	# bani care se oprește. Tween, nu `_process`, ca să meargă și cu jocul pe pauză.
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var pas := TU_PAS_START
	for i in TU_PASI:
		tw.tween_callback(_perinda.bind(lu.item_random_de_raritate(tinta), lu))
		tw.tween_interval(pas)
		pas *= TU_PAS_FACTOR
	tw.tween_callback(_aterizeaza.bind(castig, p, lu))

func _perinda(u, lu) -> void:
	if u == null:
		return
	_premiu["semn"].visible = false
	_premiu["icon"].texture = load(lu.icon_path(u))
	Audio.play("key_pickup", -16.0, 0.0)

func _aterizeaza(castig, p, lu) -> void:
	if not is_instance_valid(p) or not is_instance_valid(lu):
		_rula = false
		return
	# ⚠️ Scoatem cele TU_CATE rânduri din registru în ordine DESCRESCĂTOARE: ștergi întâi indicele
	# mic și toți ceilalți se mută cu unu sub tine. Și abia DUPĂ aia dăm itemul nou, fiindcă
	# `da_item` ADAUGĂ în aceeași listă (prin `_apply`) — aceeași grijă ca la `trade.gd::_alege`.
	var idx := _sel.duplicate()
	idx.sort()
	idx.reverse()
	for i in idx:
		var k := int(i)
		if k >= 0 and k < p.run_items.size():
			p.run_items.remove_at(k)
	lu.da_item(castig, p)
	if TU_COST_PROCENT > 0.0:
		Difficulty.add_trade_penalty(TU_COST_PROCENT / 100.0)

	var r: Dictionary = lu.RARITIES.get(String(castig.get("rar", "common")), lu.RARITIES["common"])
	_premiu["semn"].visible = false
	_premiu["icon"].texture = load(lu.icon_path(castig))
	_premiu["border"].texture = load(MENU_UI_DIR + String(r["border"]))
	_premiu["rar"].text = String(r["nume"])
	_premiu["rar"].add_theme_color_override("font_color", r["color"])
	_premiu["nume"].text = String(castig["nume"])
	Audio.play("chest_anim", -3.0, 0.0)

	# pocnetul de la aterizare — cât să se simtă că s-a oprit, nu cât să sară cutia din panou
	var pop := create_tween()
	pop.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_premiu["box"].scale = Vector2(1.3, 1.3)
	pop.tween_property(_premiu["box"], "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_sel.clear()
	_rar_blocata = ""
	_rula = false
	_umple_grila()
	_actualizeaza_contract(true)   # premiul rămâne pe ecran până alegi altceva
	_lbl_stare.text = ""

# ---------------------------------------------------------------------------
# AȘEZAREA ÎN PAGINĂ (merge la orice rezoluție)
# ---------------------------------------------------------------------------
func _relayout() -> void:
	if _masa == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var pan_w: float = clampf(vp.x * 0.30, 260.0, 380.0)
	_panou.offset_left = -pan_w - 10.0
	_panou.offset_right = -10.0
	_panou.offset_top = 10.0
	_panou.offset_bottom = -10.0

	# masa se întinde cât încape în ce rămâne la stânga panoului, PĂSTRÂND proporțiile pozei
	var zona := Rect2(12.0, 56.0, maxf(80.0, vp.x - pan_w - 34.0), maxf(80.0, vp.y - 70.0))
	var s: float = minf(zona.size.x / TABLE_W, zona.size.y / TABLE_H)
	var dim := Vector2(TABLE_W, TABLE_H) * s
	_masa.position = zona.position + (zona.size - dim) * 0.5
	_masa.size = dim
	_aseaza_suprapuse(s)

# Roata, jetonul, evidențierea și numărul ieșit — singurele care nu merg pe ancore, fiindcă se
# mută în timpul jocului (jetonul) sau au nevoie de pivot pentru rotire (roata).
func _aseaza_suprapuse(s: float) -> void:
	_roata.aseaza(WHEEL_CENTER * s, WHEEL_R * s)

	var bw := 108.0 * s
	_nr_iesit.position = WHEEL_CENTER * s - Vector2(bw, bw) * 0.5
	_nr_iesit.size = Vector2(bw, bw)
	_nr_iesit.add_theme_font_size_override("font_size", int(maxf(14.0, 54.0 * s)))

	if _pariu != null:
		var c := (_pariu_rect.position + _pariu_rect.size * 0.5) * s
		var j: float = clampf(minf(_pariu_rect.size.x, _pariu_rect.size.y) * s * 0.95, 14.0, 90.0)
		_jeton.position = c - Vector2(j, j) * 0.5
		_jeton.size = Vector2(j, j)

	if _evid.visible:
		_evid.position = _evid_rect.position * s
		_evid.size = _evid_rect.size * s

# ---------------------------------------------------------------------------
# CĂRĂMIZILE DE ASPECT (aceleași ca la `trade.gd` — citește acolo de ce arată așa)
# ---------------------------------------------------------------------------
# Un chenar din planșă, gata de întins (nine-patch). Celula se decupează la rulare din PNG și se
# face textură proprie: `NinePatchRect` vrea o textură întreagă, iar un `AtlasTexture` nu e de
# încredere aici. `margine` = câți pixeli din margine NU se întind (colțurile ornamentate).
func _cadru(celula: Vector2i, margine: int) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _chenar(celula)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.patch_margin_left = margine * ZOOM
	np.patch_margin_right = margine * ZOOM
	np.patch_margin_top = margine * ZOOM
	np.patch_margin_bottom = margine * ZOOM
	return np

func _chenar(celula: Vector2i) -> ImageTexture:
	if _sheet == null:
		var tex := load(SHEET) as Texture2D
		if tex == null:
			return null
		_sheet = tex.get_image()
	var bucata := _sheet.get_region(Rect2i(celula.x * CELULA, celula.y * CELULA, CELULA, CELULA))
	bucata.resize(CELULA * ZOOM, CELULA * ZOOM, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(bucata)

# Linia subțire de sub titlu. Se stinge spre capete (trei bucăți cu alfa diferit), ca să nu arate
# ca o bară trasă cu rigla peste artă.
func _linie(latime: float, inaltime: int) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, inaltime)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hb)
	for a in [0.15, 0.55, 0.15]:
		var r := ColorRect.new()
		r.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, a)
		r.custom_minimum_size = Vector2(latime / 3.0, 2)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(r)
	return wrap

func _contur(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)

# Butoanele: piatră întunecată cu muchie de aramă, nu lemnul cald de dinainte.
func _buton(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", OS_ALB)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color8(96, 90, 92))
	b.add_theme_stylebox_override("normal", _sb(BTN_MAIN, BTN_SECOND))
	b.add_theme_stylebox_override("hover", _sb(Color8(42, 30, 30), ACCENT))
	b.add_theme_stylebox_override("pressed", _sb(Color8(56, 36, 32), ACCENT_CLAR))
	b.add_theme_stylebox_override("disabled", _sb(BTN_MAIN.darkened(0.35), BTN_SECOND.darkened(0.5)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if cb.is_valid():
		b.pressed.connect(func(): Audio.play("button", -3.0, 0.0))
		b.pressed.connect(cb)
	return b

func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)   # colțuri aproape drepte: pixel art, nu material design
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _spatiu(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
