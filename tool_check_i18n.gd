extends Node

# UNEALTĂ de verificare a traducerilor (nu face parte din joc):
#
#   godot --headless --path <proiect> res://tool_check_i18n.tscn
#
# Se rulează ca SCENĂ, nu cu `--script`: are nevoie de autoload-uri (I18n, GameSettings),
# care în modul `--script` nu există și dau „Identifier not found".
#
# Verifică patru lucruri, fiindcă nimic altceva nu te avertizează dacă rămâne un text în engleză:
#   1. fiecare rând din `I18n.TRAD` are exact atâtea traduceri câte limbi sunt, niciuna goală;
#   2. fiecare nume/descriere/raritate din `levelup.gd` are un rând în TRAD;
#   3. fiecare `tr("...")` scris în cod are un rând în TRAD;
#   4. fiecare text pus direct pe un Label/Button (`.text = "..."`) are un rând în TRAD —
#      aici sunt și rezultate false (simboluri, formate), de aia se afișează ca AVERTISMENT.
# Iese cu cod 1 dacă găsește o problemă din primele trei categorii.

const LEVELUP := "res://levelup.gd"
# fișierele care desenează text; restul n-au UI
const FISIERE_UI := [
	"res://menu.gd", "res://settings_ui.gd", "res://pause.gd", "res://gameover.gd",
	"res://hud.gd", "res://interact_ui.gd", "res://levelup.gd", "res://player.gd",
	"res://limbo.gd", "res://nether.gd", "res://spawner.gd", "res://summoning_portal.gd",
	"res://ender.gd", "res://executioner.gd",
]
# texte care APAR în cod dar NU trebuie traduse: simboluri, nume proprii, formate pur numerice
const IGNORATE := [
	"⚙", "▲", "SARATALIN", "%d", "%s", "", " ", "MAX",
	"keybinds", "graphics", "main", "settings", "language", "weapon", "character",
	"leaderboard", "same", "up", "down",
]

var _erori := 0
var _trad: Dictionary = {}

func _ready() -> void:
	_trad = I18n.TRAD
	var limbi: Array = I18n.ORDINE
	var toate: Array = I18n.LIMBI
	print("--- verific %d chei × %d limbi ---" % [_trad.size(), limbi.size()])

	_verifica_randurile(limbi.size())
	_verifica_steagurile(toate)
	_verifica_levelup()
	_verifica_tr()
	_avertizeaza_text_direct()

	if _erori == 0:
		print("\n✔ TOTUL E TRADUS")
	else:
		print("\n✘ %d probleme" % _erori)
	get_tree().quit(1 if _erori > 0 else 0)

func _problema(mesaj: String) -> void:
	_erori += 1
	print("  ✘ ", mesaj)

# 1. rânduri complete
func _verifica_randurile(n: int) -> void:
	print("[1] rânduri complete")
	for cheie in _trad:
		var rand: Array = _trad[cheie]
		if rand.size() != n:
			_problema('"%s" are %d traduceri, trebuie %d' % [cheie, rand.size(), n])
		for t in rand:
			if String(t).strip_edges() == "":
				_problema('"%s" are o traducere goala' % cheie)
				break

func _verifica_steagurile(limbi: Array) -> void:
	print("[2] steaguri")
	for l in limbi:
		if not ResourceLoader.exists(String(l["steag"])):
			_problema("lipsește steagul %s" % l["steag"])

# 3. numele, descrierile și raritățile upgrade-urilor
func _verifica_levelup() -> void:
	print("[3] upgrade-uri din levelup.gd")
	var text := _citeste(LEVELUP)
	var re := RegEx.new()
	re.compile('"(?:nume|desc)":\\s*"((?:[^"\\\\]|\\\\.)*)"')
	var vazute := {}
	for m in re.search_all(text):
		var s := m.get_string(1)
		if vazute.has(s):
			continue
		vazute[s] = true
		if not _trad.has(s) and not IGNORATE.has(s):
			_problema('levelup.gd: "%s" nu are traduceri' % s)

# 4. tr("...") din cod
func _verifica_tr() -> void:
	print("[4] tr(...) din cod")
	var re := RegEx.new()
	re.compile('\\btr\\(\\s*"((?:[^"\\\\]|\\\\.)*)"')
	for f in FISIERE_UI:
		for m in re.search_all(_citeste(f)):
			var s := m.get_string(1).c_unescape()
			if not _trad.has(s):
				_problema("%s: tr(\"%s\") nu are traduceri" % [f.get_file(), s])

# 5. „.text = ..." pus direct (doar avertisment: prinde și simboluri/formate)
func _avertizeaza_text_direct() -> void:
	print("[5] texte puse direct pe noduri (doar avertisment)")
	var re := RegEx.new()
	re.compile('(?:\\.text\\s*=\\s*|_center_label\\(|_header\\(|_menu_button\\(|_button\\(|_title\\(|_buton\\(|_volume_row\\(|_toggle_row\\(|announce\\(|_announce\\(|text_popup\\([^,]+,\\s*)"((?:[^"\\\\]|\\\\.)*)"')
	var vazute := {}
	for f in FISIERE_UI:
		for m in re.search_all(_citeste(f)):
			var s := m.get_string(1).c_unescape()
			if vazute.has(s) or _trad.has(s) or IGNORATE.has(s):
				continue
			vazute[s] = true
			print('  ? %s: "%s"' % [f.get_file(), s])

func _citeste(cale: String) -> String:
	var f := FileAccess.open(cale, FileAccess.READ)
	return f.get_as_text() if f != null else ""
