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
	"levelup":        "res://audio/Choose Item Menu Open - Close.wav",  # ecranul de Level Up
	"hurt":           "res://audio/When enemy hits player.wav",         # player-ul primește damage
	"extinguisher":   "res://audio/Extinguisher.wav",                   # pulsul stingătorului
	"sword":          "res://audio/Cursed Sword.wav",                   # tăietura săbiei
	"garda_attack":   "res://audio/Garda Attack.wav",                   # boss-ul Garda aruncă bastonul
	"game_start":     "res://audio/Game Start.wav",                     # începutul unei runde
	"game_over":      "res://audio/Game Over.wav",                      # ecranul de Game Over
	"footsteps_grass": "res://audio/Footsteps_Grass_Run_01.wav",       # un pas pe iarbă/pădure
	"footsteps_sand":  "res://audio/Footsteps_Sand_Run_01.wav",        # un pas pe nisip/deșert
	"forest_ambient":  "res://audio/Forest Ambient.wav",               # ambient de pădure (buclă, vezi mai jos)
}

const CHUNK_PX := 512.0     # mărimea unui chunk (ca în props/ground/pathways) — pentru desertness

# Muzica de fundal, pe ecrane. Gol = n-avem încă fișier (nu se aude nimic, fără erori).
const MUSIC_MENU := "res://audio/main menu theme.ogg"
const MUSIC_GAME := ""

const POOL_SIZE := 12       # câte "boxe" (playere) avem pregătite
const MIN_GAP_MS := 45      # pauza minimă între două redări ale ACELUIAȘI sunet (vezi `play`)
var _ultima := {}           # nume -> momentul (ms) când s-a auzit ultima oară
var _streams := {}          # nume -> AudioStream încărcat
var _players: Array = []    # lista de AudioStreamPlayer
var _next := 0              # ce boxă folosim data viitoare (rotativ)
var _music: AudioStreamPlayer  # boxă separată doar pentru muzica de fundal (în buclă)
var _music_path := ""       # ce melodie cântă acum (ca să n-o repornim degeaba)
var _music_base_db := 0.0   # volumul „de bază" al melodiei; peste el se adaugă reglajul din Settings

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
	p.stream = _streams[name]
	p.volume_db = volume_db + _lin_to_db(GameSettings.sfx_volume)   # reglajul „Efecte" din Settings
	p.pitch_scale = 1.0 + randf_range(-pitch_rand, pitch_rand)
	p.play()

# --- Muzică de fundal, în buclă ---
# Meniul o pornește cu play_menu_music(), jocul cu play_music() (spawner._ready).
func play_menu_music(volume_db: float = -14.0) -> void:
	_play_track(MUSIC_MENU, volume_db)

func play_music(volume_db: float = -12.0) -> void:
	_play_track(MUSIC_GAME, volume_db)

func stop_music() -> void:
	_music_path = ""
	if _music != null:
		_music.stop()

func _play_track(path: String, volume_db: float) -> void:
	# path gol sau fișier lipsă = pur și simplu tăcere (nu crapă, nu dă erori)
	if path == "" or not ResourceLoader.exists(path):
		stop_music()
		return
	# dacă exact melodia asta cântă deja, o lăsăm în pace (să nu repornească din capăt)
	if _music_path == path and _music != null and _music.playing:
		return
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = "Master"
		_music.process_mode = Node.PROCESS_MODE_ALWAYS  # cântă și pe pauză (ex. Game Over)
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
	_music.volume_db = volume_db + _lin_to_db(GameSettings.music_volume)   # reglajul „Muzică" din Settings
	_music.play()

# Recalculează volumul muzicii care cântă acum (chemat din Settings când miști slider-ul).
func refresh_music_volume() -> void:
	if _music != null:
		_music.volume_db = _music_base_db + _lin_to_db(GameSettings.music_volume)

# --- Ambient de pădure ---
# O buclă care se aude cât ești în pădure și se estompează lin când intri în deșert (și invers).
# Volumul urmărește „cât de pădure" e locul (1 - desertness la poziția player-ului), cu un fade
# ușor (lerp), deci trecerea pădure↔deșert nu e bruscă. Pornit la începutul rundei (spawner),
# oprit în meniu. Merge pe reglajul „SOUND FX" (ca pașii), nu pe muzică.
const AMBIENT_DB := -6.0     # volumul la pădure plină
const AMBIENT_FADE := 1.5    # cât de repede urmărește ținta (mai mic = fade mai lent)
var _ambient: AudioStreamPlayer
var _ambient_level := 0.0    # 0..1, nivelul curent (urcă/coboară lin spre forestness)

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
	_ambient.volume_db = -80.0
	if not _ambient.playing:
		_ambient.play()

func stop_forest_ambient() -> void:
	if _ambient != null:
		_ambient.stop()

func _process(delta: float) -> void:
	if _ambient == null or not _ambient.playing:
		return
	# ținta = cât de pădure e locul de sub player (1 = pădure pură, 0 = deșert). Fără player → tăcere.
	var target := 0.0
	var p = get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p):
		var d: float = clampf(BiomeMap.desertness_at_chunk(p.global_position / CHUNK_PX), 0.0, 1.0)
		target = 1.0 - d
	_ambient_level = lerpf(_ambient_level, target, clampf(delta * AMBIENT_FADE, 0.0, 1.0))
	_ambient.volume_db = AMBIENT_DB + _lin_to_db(_ambient_level * GameSettings.sfx_volume)

# Găsește o boxă care nu cântă; dacă toate cântă, o refolosește pe următoarea (rotativ).
func _find_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	return p
