extends Node

# ÎNCĂRCAREA DE LA PORNIRE (cerută de Răzvan pe 2026-08-05: „sa fie un loading screen inainte sa
# intrii in joc (inainte si de meniu) in care sa se incarce deja toate asseturile sa nu faca lag").
#
# Autoload „PreloadAll". Nu face nimic singur — îl pornește `loading.gd`, ecranul de încărcare,
# care e acum PRIMA scenă a jocului (`project.godot`, `run/main_scene`).
#
# CE FACE: scanează folderele de artă și sunet, încarcă TOT ce găsește și **ține referințe** la
# resurse. Partea cu ținutul e miezul: cache-ul de resurse al lui Godot e pe referințe slabe, deci
# o resursă pe care n-o mai ține nimeni e eliberată imediat și data viitoare se citește iar de pe
# disc. Fără `_tinute`, ecranul de încărcare ar fi doar o pierdere de timp.
#
# DE CE nu o listă scrisă de mână: ar rămâne în urmă în tăcere la primul PNG pe care îl pui în
# folder. Scanarea pe FOLDERE (numele lor se schimbă rar) se descurcă singură.
#
# ⚠️ Numele fișierelor NU se citesc la fel în editor și în jocul exportat: acolo apar cu `.import`
# sau `.remap` la coadă. De-aia se taie coada și se scot dublurile (vezi `_aduna`).

# Ce foldere se scanează, recursiv. Ce nu e aici nu se preîncarcă.
const FOLDERE := [
	"res://fx",
	"res://harta",
	"res://homeless directii",
	"res://Upgrades",
	"res://boss",
	"res://grasu directii",
	"res://xp",
	"res://stones",
	"res://bullets",
	"res://weapons_icons",
	"res://menu",
	"res://audio",
	"res://scripts",
]
# ...plus tot ce stă direct în rădăcină (scenele și `.tres`-urile jocului), fără să intrăm în
# subfoldere de acolo — alea sunt deja în lista de sus.
const RADACINA := "res://"
# Capturile de ecran din rapoartele de bug n-au ce căuta în memoria jocului.
#
# `bullet2.tscn` / `bullet3.tscn` sunt RUPTE de dinainte de ecranul ăsta: cer
# `bullets/bullet2.png` și `bullet3.png`, care nu mai există pe disc, iar niciun `.gd` nu le mai
# folosește (verificat cu grep pe tot proiectul). Preîncărcarea doar le-a scos la iveală, umplând
# consola cu roșu la fiecare pornire. Le sărim până le șterge Răzvan.
const IGNORATE := ["res://debugging", "res://bullet2.tscn", "res://bullet3.tscn"]

# --- ȚINUTE DOAR PÂNĂ SE DESCHIDE MENIUL ---
# Cele 120 de cadre de fundal ale meniului sunt 1920×1080 fiecare: singure fac ~70 MB din memoria
# de textură. Le încărcăm (de-asta meniul se deschide instant, nu cu o proptire de o secundă), dar
# NU le ținem pe veci: după ce meniul a apucat să le ceară el, le dăm drumul. De atunci încolo ele
# trăiesc cât trăiește meniul, exact ca înainte — deci în timpul rundei nu ocupă nimic.
#
# ⚠️ Regula generală: aici intră doar artă care se vede EXCLUSIV în meniu. Orice se poate cere în
# timpul unei runde trebuie ținut permanent, altfel preîncărcarea nu folosește la nimic.
const TEMPORARE := ["res://menu/bg_frames"]
const EXTENSII := ["png", "webp", "tres", "tscn", "gdshader", "ogg", "mp3", "wav"]

# Cât timp se încarcă în fiecare cadru, în milisecunde. Restul cadrului rămâne pentru desenat, ca
# bara să chiar se miște în loc să înghețe imaginea.
#
# ⚠️ Încărcare SINCRONĂ, nu pe fire de fundal, și amândouă motivele contează:
#   1. `load_threaded_request` cu mai multe cereri deodată face ca două fire să ajungă în același
#      timp la aceeași dependință, iar `preload()` dintr-un script care tocmai se compilează cade
#      cu „Could not preload resource file" — și scriptul rămâne STRICAT în cache tot restul
#      rundei. S-a întâmplat cu `egt.tscn` / `egts.gd` la prima încercare;
#   2. cu o singură cerere pe rând, ridici cel mult un fișier per cadru, adică 16 ms de fișier
#      degeaba: 728 de fișiere ajungeau la ~11 secunde, deși citirea lor durează sub 3.
const BUGET_MS := 10

var _coada: Array = []        # ce a mai rămas de încărcat
var _tinute: Array = []       # ⚠️ referințele care țin resursele în viață
var _temporare: Array = []    # ...cele care se dau drumul după ce se deschide meniul
var _total := 0
var gata := false

# Cât s-a încărcat până acum, 0..1 — pentru bară.
func progres() -> float:
	if _total <= 0:
		return 1.0
	return float(_total - _coada.size()) / float(_total)

func total() -> int:
	return _total

# Construiește lista. Se cheamă o dată, din `loading.gd`.
func porneste() -> void:
	if gata or _total > 0:
		return
	var vazute := {}
	for f in FOLDERE:
		_aduna(f, vazute, true)
	_aduna(RADACINA, vazute, false)
	_coada = vazute.keys()
	_coada.sort()
	_total = _coada.size()

# Un pas de încărcare. Se cheamă în fiecare cadru din `loading.gd`; întoarce `true` când s-a
# terminat tot. Nu blochează: cererile merg pe firele de fundal ale lui Godot, iar aici doar
# întrebăm ce-a sosit — de-asta bara chiar se mișcă, în loc să înghețe imaginea.
func pas() -> bool:
	var pana_la := Time.get_ticks_msec() + BUGET_MS
	while not _coada.is_empty() and Time.get_ticks_msec() < pana_la:
		var cale: String = _coada.pop_front()
		var res = ResourceLoader.load(cale)
		if res != null:
			# ⚠️ fără listele astea, resursa se eliberează imediat ce se termină linia
			if _e_temporara(cale):
				_temporare.append(res)
			else:
				_tinute.append(res)
	gata = _coada.is_empty()
	return gata

# Chemată de `loading.gd` odată cu trecerea la meniu. Așteptăm câteva cadre ca meniul să apuce să
# se construiască (`change_scene_to_file` schimbă scena abia la sfârșitul cadrului) și ABIA APOI
# dăm drumul cadrelor de fundal — de acolo încolo le ține meniul, cât e el pe ecran.
func preda_meniului() -> void:
	for i in 4:
		await get_tree().process_frame
	_temporare.clear()

func _e_temporara(cale: String) -> bool:
	for t in TEMPORARE:
		if cale.begins_with(t):
			return true
	return false

# Adună fișierele dintr-un folder. `recursiv = false` → doar ce stă direct acolo (rădăcina).
func _aduna(folder: String, vazute: Dictionary, recursiv: bool) -> void:
	for ign in IGNORATE:
		if folder.begins_with(ign):
			return
	var d := DirAccess.open(folder)
	if d == null:
		return
	d.list_dir_begin()
	var nume := d.get_next()
	while nume != "":
		var cale := folder.path_join(nume) if folder != "res://" else "res://" + nume
		if d.current_is_dir():
			if recursiv and not nume.begins_with("."):
				_aduna(cale, vazute, true)
		else:
			# în jocul exportat vin cu coada `.import` / `.remap`; o tăiem și scoatem dublurile
			var curat := cale
			for coada in [".import", ".remap"]:
				if curat.ends_with(coada):
					curat = curat.substr(0, curat.length() - coada.length())
			if EXTENSII.has(curat.get_extension().to_lower()) \
					and not curat.get_file().begins_with("tool_") \
					and not IGNORATE.has(curat) \
					and ResourceLoader.exists(curat):
				vazute[curat] = true
		nume = d.get_next()
	d.list_dir_end()
