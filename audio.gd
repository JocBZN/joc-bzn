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
	"button": "res://audio/button.wav",
}

# Muzica de fundal, pe ecrane. Gol = n-avem încă fișier (nu se aude nimic, fără erori).
const MUSIC_MENU := "res://audio/main menu theme.ogg"
const MUSIC_GAME := ""

const POOL_SIZE := 12       # câte "boxe" (playere) avem pregătite
var _streams := {}          # nume -> AudioStream încărcat
var _players: Array = []    # lista de AudioStreamPlayer
var _next := 0              # ce boxă folosim data viitoare (rotativ)
var _music: AudioStreamPlayer  # boxă separată doar pentru muzica de fundal (în buclă)
var _music_path := ""       # ce melodie cântă acum (ca să n-o repornim degeaba)

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
	var p := _find_free_player()
	p.stream = _streams[name]
	p.volume_db = volume_db
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
	_music.stream = s
	_music.volume_db = volume_db
	_music.play()

# Găsește o boxă care nu cântă; dacă toate cântă, o refolosește pe următoarea (rotativ).
func _find_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	return p
