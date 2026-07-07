extends Node

# Manager global de sunet. Autoload "Audio" — există o singură dată și se aude din orice scenă.
# Îl chemi simplu de oriunde:  Audio.play("shoot")
# Analogie: un DJ cu mai multe boxe. Când ceri un sunet îl pune pe o boxă liberă,
# ca să poată suna mai multe efecte în același timp (multe gloanțe deodată etc.).

# Numele efectului -> fișierul din folderul audio/. Adaugi aici ca să ai un sunet nou.
const SFX := {
	"shoot": "res://audio/shoot.wav",
	"hit": "res://audio/hit.wav",
	"enemy_die": "res://audio/enemy_die.wav",
	"xp": "res://audio/xp.wav",
	"levelup": "res://audio/levelup.wav",
	"hurt": "res://audio/hurt.wav",
}

const POOL_SIZE := 12       # câte "boxe" (playere) avem pregătite
var _streams := {}          # nume -> AudioStream încărcat
var _players: Array = []    # lista de AudioStreamPlayer
var _next := 0              # ce boxă folosim data viitoare (rotativ)
var _music: AudioStreamPlayer  # boxă separată doar pentru muzica de fundal (în buclă)

func _ready() -> void:
	# rulează chiar și când jocul e pe pauză (ex. la level up)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# încărcăm o dată fiecare sunet
	for name in SFX:
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
# O pornim la începutul jocului (spawner._ready) și o oprim la ieșirea din joc.
func play_music(volume_db: float = -12.0) -> void:
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = "Master"
		_music.process_mode = Node.PROCESS_MODE_ALWAYS  # cântă și pe pauză (ex. Game Over)
		add_child(_music)
	var s = load("res://audio/music.wav")
	if s == null:
		return
	# facem WAV-ul să se repete la nesfârșit fără pauză
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
	_music.stream = s
	_music.volume_db = volume_db
	_music.play()

func stop_music() -> void:
	if _music != null:
		_music.stop()

# Găsește o boxă care nu cântă; dacă toate cântă, o refolosește pe următoarea (rotativ).
func _find_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	return p
