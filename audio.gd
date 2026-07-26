extends Node

# Manager global de sunet. Autoload "Audio" — există o singură dată și se aude din orice scenă.
# Îl chemi simplu de oriunde:  Audio.play("shoot")
# Analogie: un DJ cu mai multe boxe. Când ceri un sunet îl pune pe o boxă liberă,
# ca să poată suna mai multe efecte în același timp (multe gloanțe deodată etc.).

# Numele efectului -> fișierul din folderul audio/. Adaugi aici ca să ai un sunet nou.
# Sunetele vechi (shoot/hit/enemy_die/xp/levelup/hurt) au fost șterse — codul care le cere
# încă există, dar `play()` nu face nimic dacă numele nu e aici. Când ai fișierul nou,
# îl pui în audio/ și adaugi o linie mai jos; restul jocului începe să-l folosească singur.
const SFX := {
	"button":         "res://audio/button.wav",
	"shoot":          "res://audio/Bullet.mp3",                         # glonțul de pistol / mage
	"levelup":        "res://audio/Choose Item Menu Open - Close.wav",  # ecranul de Level Up
	"hurt":           "res://audio/When enemy hits player.wav",         # player-ul primește damage
	"extinguisher":   "res://audio/Extinguisher.wav",                   # pulsul stingătorului
	"sword":          "res://audio/Cursed Sword.wav",                   # tăietura săbiei
	"garda_attack":   "res://audio/Garda Attack.wav",                   # boss-ul Garda aruncă bastonul
	"game_start":     "res://audio/Game Start.wav",                     # începutul unei runde
	"game_over":      "res://audio/Game Over.wav",                      # ecranul de Game Over
	"footsteps_grass": "res://audio/Footsteps_Grass_Run_01.wav",       # un pas pe iarbă/pădure
	"footsteps_sand":  "res://audio/Footsteps_Sand_Run_01.wav",        # un pas pe nisip/deșert
	"footsteps_nether": "res://audio/Nether Audio/Footsteps_Nether.wav",  # un pas pe cărămida din Nether
	"forest_ambient":  "res://audio/Forest Ambient.wav",               # ambient de pădure (buclă, vezi mai jos)
	"teleport":        "res://audio/Nether Audio/Teleport Sfx.wav",    # E pe portal: intrarea/ieșirea din Nether
}

const CHUNK_PX := 512.0     # mărimea unui chunk (ca în props/ground/pathways) — pentru desertness

# Muzica de fundal, pe ecrane. Gol = n-avem încă fișier (nu se aude nimic, fără erori).
const MUSIC_MENU := "res://audio/main menu theme.ogg"
# În joc: se alege UNA la întâmplare din listă la începutul fiecărei runde.
# Ca să adaugi o melodie nouă, pui fișierul în folder și mai scrii o linie aici.
const MUSIC_GAME := [
	"res://audio/First 5 Minutes - Main World/Ruined_Place.ogg",
	"res://audio/First 5 Minutes - Main World/tiny-rpg-town.ogg",
]
# În Nether: mereu aceeași melodie, în buclă, cât ești acolo (`nether.gd`).
const MUSIC_NETHER := "res://audio/Nether Audio/sky-lines.ogg"

const POOL_SIZE := 12       # câte "boxe" (playere) avem pregătite
const MIN_GAP_MS := 45      # pauza minimă între două redări ale ACELUIAȘI sunet (vezi `play`)
var _ultima := {}           # nume -> momentul (ms) când s-a auzit ultima oară
var _streams := {}          # nume -> AudioStream încărcat
var _players: Array = []    # lista de AudioStreamPlayer
var _next := 0              # ce boxă folosim data viitoare (rotativ)
var _music: AudioStreamPlayer  # boxă separată doar pentru muzica de fundal (în buclă)
var _music_path := ""       # ce melodie cântă acum (ca să n-o repornim degeaba)
var _music_base_db := 0.0   # volumul „de bază" al melodiei; peste el se adaugă reglajul din Settings

# --- Fade la muzică ---
# Orice melodie INTRĂ din tăcere în FADE secunde și IESE la fel. Când se schimbă melodia
# (ex. intri în Nether), cele două se suprapun: vechea se stinge pe boxa `_music_vechi`
# în timp ce noua urcă pe `_music` — deci nu rămâne nicio pauză de liniște între ele.
const FADE := 3.0
const TACERE_DB := -60.0    # „zero" pentru un fade (nu -80: de acolo ultima parte a urcării e inaudibilă)
var _music_vechi: AudioStreamPlayer   # boxa melodiei care se stinge acum
var _tw_in: Tween
var _tw_out: Tween

# Transformă volumul-slider (0..1) în decibeli. 0 = tăcere completă (nu -inf, care ar da erori).
func _lin_to_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)

func _ready() -> void:
	# rulează chiar și când jocul e pe pauză (ex. la level up)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# încărcăm o dată fiecare sunet (verificăm întâi că fișierul chiar există,
	# altfel `load()` umple consola cu erori roșii)
	for name in SFX:
		if not ResourceLoader.exists(SFX[name]):
			push_warning("Audio: lipsește %s" % SFX[name])
			continue
		var s = load(SFX[name])
		if s != null:
			_streams[name] = s
	# pregătim boxele
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

# Redă un efect. volume_db: mai mic = mai încet (ex. -6). pitch_rand: variație aleatoare
# de ton (0.1 = ±10%) ca să nu sune identic de fiecare dată.
func play(name: String, volume_db: float = 0.0, pitch_rand: float = 0.08) -> void:
	if not _streams.has(name):
		return
	# Același sunet nu se pornește mai des de MIN_GAP. În Final Swarm, „hit" și „enemy_die"
	# se cer de sute de ori pe secundă (aură + Thunder God peste o gloată): boxele s-ar tăia
	# una pe alta oricum, s-ar auzi ca un zid de zgomot, și ar costa degeaba.
	var acum := Time.get_ticks_msec()
	if acum - int(_ultima.get(name, -10000)) < MIN_GAP_MS:
		return
	_ultima[name] = acum
	var p := _find_free_player()
	p.stream_paused = false   # boxa poate fi înghețată de pause_all(); clicurile din meniu trebuie să se audă
	p.stream = _streams[name]
	p.volume_db = volume_db + _lin_to_db(GameSettings.sfx_volume)   # reglajul „Efecte" din Settings
	p.pitch_scale = 1.0 + randf_range(-pitch_rand, pitch_rand)
	p.play()

# --- Muzică de fundal, în buclă ---
# Meniul o pornește cu play_menu_music(), jocul cu play_music() (spawner._ready).
func play_menu_music(volume_db: float = -14.0) -> void:
	_play_track(MUSIC_MENU, volume_db)

# Muzica din joc: alege o melodie la întâmplare din MUSIC_GAME, alta (posibil) la fiecare rundă.
# Sar peste fișierele care lipsesc, ca să nu iasă tăcere dacă unul e șters/redenumit.
func play_music(volume_db: float = -12.0) -> void:
	_nether_prev_path = ""   # rundă nouă → uităm ce cânta înainte de un Nether vechi
	var disponibile: Array = []
	for path in MUSIC_GAME:
		if ResourceLoader.exists(path):
			disponibile.append(path)
	if disponibile.is_empty():
		stop_music()
		return
	_play_track(disponibile[randi() % disponibile.size()], volume_db)

# --- Muzica din Nether ---
# Intri în Nether → ținem minte CE cânta și DIN CE SECUNDĂ, apoi punem sky-lines în buclă.
# La întoarcere reluăm melodia lumii exact de unde a rămas (nu de la capăt), ca și cum
# ar fi cântat mai departe cât ai fost plecat.
var _nether_prev_path := ""
var _nether_prev_db := 0.0
var _nether_prev_pos := 0.0

func play_nether_music(volume_db: float = -12.0) -> void:
	if _music != null and _music.playing:
		_nether_prev_path = _music_path
		_nether_prev_db = _music_base_db
		_nether_prev_pos = _music.get_playback_position()
	_play_track(MUSIC_NETHER, volume_db)

func restore_world_music() -> void:
	if _nether_prev_path == "":
		play_music()   # n-avem ce relua (ex. ai intrat fără muzică) → alegem una nouă
		return
	var path := _nether_prev_path
	var db := _nether_prev_db
	var poz := _nether_prev_pos
	_nether_prev_path = ""
	_play_track(path, db)
	if _music != null and _music.playing:
		_music.seek(poz)

# Oprește muzica STINGÂND-O în FADE secunde. `imediat = true` o taie pe loc (nu se folosește
# în joc; e acolo pentru cazurile în care chiar vrei liniște instantă).
func stop_music(imediat: bool = false) -> void:
	_music_path = ""
	if _music == null:
		return
	if imediat:
		_opreste_tween(_tw_in)
		_music.stop()
		return
	_stinge(_music)
	_music = null   # boxa curentă devine „cea care se stinge"; următoarea melodie primește una nouă

# Stinge o boxă în FADE secunde și apoi o oprește. Boxa e reținută în `_music_vechi` ca s-o
# putem pune pe pauză odată cu restul (ESC) și ca să nu se calce două stingeri una pe alta.
func _stinge(p: AudioStreamPlayer) -> void:
	if p == null:
		return
	if not p.playing:
		p.queue_free()   # n-are ce stinge, dar boxa tot trebuie eliberată (altfel se adună)
		return
	_opreste_tween(_tw_out)
	if _music_vechi != null and _music_vechi != p and is_instance_valid(_music_vechi):
		_music_vechi.stop()   # deja se stingea alta → o tăiem, n-avem trei melodii deodată
		_music_vechi.queue_free()
	_music_vechi = p
	_tw_out = create_tween()
	_tw_out.tween_property(p, "volume_db", TACERE_DB, FADE)
	_tw_out.tween_callback(_gata_stins.bind(p))

func _gata_stins(p: AudioStreamPlayer) -> void:
	if p != null and is_instance_valid(p):
		p.stop()
		p.queue_free()
	if _music_vechi == p:
		_music_vechi = null

func _opreste_tween(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()

func _play_track(path: String, volume_db: float) -> void:
	# path gol sau fișier lipsă = pur și simplu tăcere (nu crapă, nu dă erori)
	if path == "" or not ResourceLoader.exists(path):
		stop_music()
		return
	# dacă exact melodia asta cântă deja, o lăsăm în pace (să nu repornească din capăt)
	if _music_path == path and _music != null and _music.playing:
		return
	# melodia veche se stinge pe boxa ei, în paralel cu urcarea celei noi (crossfade)
	if _music != null:
		_stinge(_music)
		_music = null
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS  # cântă și pe pauză (ex. meniul de pauză)
	add_child(_music)
	var s = load(path)
	if s == null:
		return
	# o facem să se repete la nesfârșit, indiferent de format
	if s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
	_music_path = path
	_music_base_db = volume_db
	_music.stream = s
	# pornim din tăcere și urcăm în FADE secunde până la volumul cerut (+ reglajul din Settings)
	_music.volume_db = TACERE_DB
	_music.play()
	_opreste_tween(_tw_in)
	_tw_in = create_tween()
	_tw_in.tween_property(_music, "volume_db", _volum_muzica(), FADE)

func _volum_muzica() -> float:
	return _music_base_db + _lin_to_db(GameSettings.music_volume)   # reglajul „Muzică" din Settings

# Recalculează volumul muzicii care cântă acum (chemat din Settings când miști slider-ul).
# Dacă tocmai urca (fade-in), oprim urcarea și sărim la volumul cerut — altfel tween-ul ar
# trage înapoi spre volumul vechi și slider-ul ar părea că nu face nimic.
func refresh_music_volume() -> void:
	if _music == null:
		return
	_opreste_tween(_tw_in)
	_music.volume_db = _volum_muzica()

# --- Ambient de pădure ---
# O buclă care se aude cât ești în pădure și se estompează lin când intri în deșert (și invers).
# Volumul urmărește „cât de pădure" e locul (1 - desertness la poziția player-ului), cu un fade
# ușor (lerp), deci trecerea pădure↔deșert nu e bruscă. Pornit la începutul rundei (spawner),
# oprit în meniu. Merge pe reglajul „SOUND FX" (ca pașii), nu pe muzică.
const AMBIENT_DB := 8.0      # volumul la pădure plină (fișierul e la ~-54dBFS; înjumătățit de 2 ori: 20→14→8)
const AMBIENT_FADE := 1.5    # cât de repede urmărește ținta (mai mic = fade mai lent)
var _ambient: AudioStreamPlayer
var _ambient_level := 0.0    # 0..1, nivelul curent (urcă/coboară lin spre forestness)
var _ambient_se_stinge := false   # true = coboară spre tăcere și apoi se oprește (moarte)

func play_forest_ambient() -> void:
	if not _streams.has("forest_ambient"):
		return
	if _ambient == null:
		_ambient = AudioStreamPlayer.new()
		_ambient.bus = "Master"
		_ambient.process_mode = Node.PROCESS_MODE_ALWAYS
		var s = _streams["forest_ambient"]
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			# ATENȚIE: fără loop_end explicit, el rămâne 0 → loop-ul [0,0] e gol și playback-ul
			# se blochează pe loc. loop_end e în CADRE = durata × rata de eșantionare.
			s.loop_end = int(s.get_length() * s.mix_rate)
		_ambient.stream = s
		add_child(_ambient)
	_ambient_level = 0.0          # pornește din tăcere → fade-in lin până la nivelul locului
	_ambient_se_stinge = false
	_ambient.volume_db = -80.0
	_ambient.stream_paused = false  # siguranță: să nu rămână blocat pe pauză de la o rundă anterioară
	if not _ambient.playing:
		_ambient.play()

func stop_forest_ambient() -> void:
	if _ambient != null:
		_ambient.stop()
	_ambient_se_stinge = false

# Stinge ambientul LIN și apoi îl oprește (folosit la moarte — vezi `gameover.gd`).
# Nu are tween propriu: `_process` deja mișcă `_ambient_level` spre o țintă, așa că îi
# spunem doar că ținta e tăcerea și, când ajunge acolo, oprim boxa.
func fade_out_forest_ambient() -> void:
	if _ambient != null and _ambient.playing:
		_ambient_se_stinge = true

# Pune ambientul pe pauză păstrând poziția (ex. cât alegi un power up), apoi îl reia de unde era.
# stream_paused (nu stop) = când revii, continuă din același loc, nu de la început.
func pause_forest_ambient() -> void:
	if _ambient != null:
		_ambient.stream_paused = true

func resume_forest_ambient() -> void:
	if _ambient != null:
		_ambient.stream_paused = false

func _process(delta: float) -> void:
	if _ambient == null or not _ambient.playing:
		return
	# ținta = cât de pădure e locul de sub player (1 = pădure pură, 0 = deșert). Fără player → tăcere.
	var target := 0.0
	if _ambient_se_stinge:
		# ne stingem de tot (ecran de moarte): ținta e tăcerea, iar când am ajuns, oprim boxa
		if _ambient_level < 0.01:
			stop_forest_ambient()
			return
	else:
		var p = get_tree().get_first_node_in_group("player")
		if p != null and is_instance_valid(p):
			var d: float = clampf(BiomeMap.desertness_at_chunk(p.global_position / CHUNK_PX), 0.0, 1.0)
			target = 1.0 - d
	_ambient_level = lerpf(_ambient_level, target, clampf(delta * AMBIENT_FADE, 0.0, 1.0))
	_ambient.volume_db = AMBIENT_DB + _lin_to_db(_ambient_level * GameSettings.sfx_volume)

# --- Pauză globală de sunet (meniul de ESC) ---
# Îngheață TOT ce se aude acum — muzica, ambientul de pădure și efectele care încă sună —
# păstrând poziția, ca butonul de pauză de la un player. `stream_paused` (nu `stop`) = la Resume
# continuă de unde a rămas. Clicurile din meniul de pauză se aud în continuare: `play()`
# dezgheață boxa pe care o folosește.
func pause_all() -> void:
	_seteaza_pauza(true)

func resume_all() -> void:
	_seteaza_pauza(false)

func _seteaza_pauza(pe_pauza: bool) -> void:
	if _music != null:
		_music.stream_paused = pe_pauza
	# și melodia care tocmai se stingea (crossfade în curs când ai apăsat ESC)
	if _music_vechi != null and is_instance_valid(_music_vechi):
		_music_vechi.stream_paused = pe_pauza
	if _ambient != null:
		_ambient.stream_paused = pe_pauza
	for p in _players:
		p.stream_paused = pe_pauza

# Găsește o boxă care nu cântă; dacă toate cântă, o refolosește pe următoarea (rotativ).
func _find_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	return p
