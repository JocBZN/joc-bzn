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
	"shoot":          "res://audio/Bullet.mp3",                         # glonțul de pistol
	"mage_shoot":     "res://audio/Mage Staff Audio.wav",               # proiectilul de Mage Staff (are alt sunet decât pistolul)
	"levelup":        "res://audio/Choose Item Menu Open - Close.wav",  # ecranul de Level Up
	"hurt":           "res://audio/When enemy hits player.wav",         # player-ul primește damage
	# Sabia sună cu fostul sunet de STINGĂTOR: cerut de Răzvan pe 2026-08-04, odată cu scoaterea
	# stingătorului din joc. `Cursed Sword.wav` a rămas pe disc, nefolosit — dacă vrei sunetul
	# vechi înapoi, schimbi doar linia asta.
	"sword":          "res://audio/Extinguisher.wav",                   # tăietura săbiei
	"garda_attack":   "res://audio/Garda Attack.wav",                   # boss-ul Garda aruncă bastonul
	"game_start":     "res://audio/Game Start.wav",                     # începutul unei runde
	"game_over":      "res://audio/Game Over.wav",                      # ecranul de Game Over
	"footsteps_grass": "res://audio/Footsteps_Grass_Run_01.wav",       # un pas pe iarbă/pădure
	"footsteps_sand":  "res://audio/Footsteps_Sand_Run_01.wav",        # un pas pe nisip/deșert
	"footsteps_nether": "res://audio/Nether Audio/Footsteps_Nether.wav",  # un pas pe cărămida din Nether
	"forest_ambient":  "res://audio/Forest Ambient.wav",               # ambient de pădure (buclă, vezi mai jos)
	"teleport":        "res://audio/Nether Audio/Teleport Sfx.wav",    # E pe portal: intrarea/ieșirea din Nether
	"saratalin_flash": "res://audio/Nether Audio/Saratalin Flashing Purple.wav",  # UN puls mov din cinematica lui Saratalin
	# Fișierul stă lângă ARTA lui Celesto, nu în `audio/`, fiindcă acolo l-a pus Răzvan, odată cu
	# cadrele. Lăsat acolo dinadins: dacă re-copiază folderul boss-ului, vine și sunetul cu el.
	"celesto_teleport": "res://harta/Portal Ender/Celesto/Teleport.wav",  # Celesto apare în spatele tău (fazele 2 și 3)
	# --- cinematica de intrare a lui Celesto (`ender.gd::_cutscene_celesto`) ---
	# Opt sunete alese din biblioteca `Soundpack/` și PRELUCRATE, nu copiate: tăiate de liniște,
	# scurtate la cât folosește scena, aduse la 48 kHz / 16 biți și normalizate toate la vârf
	# -1 dBFS. ⚠️ Deci în fișiere sunt toate la fel de tari — echilibrul dintre ele e în `volume_db`
	# de la fiecare chemare din `ender.gd`, ca la orice mix de joc: schimbi mixul fără să reexporți
	# nimic. Cifrele alese acolo sunt în comentariul de la `_cutscene_celesto`.
	# (Sursele stau în `Soundpack/`, care e gitignorat — vezi `.gitignore`.)
	"celesto_freeze":      "res://audio/Ender Audio/Celesto Freeze.wav",      # bubuitura cu care ÎNGHEAȚĂ timpul
	"celesto_riser":       "res://audio/Ender Audio/Celesto Riser.wav",       # urcarea de sub tot, cât intră camera
	"celesto_materialize": "res://audio/Ender Audio/Celesto Materialize.wav", # se face din nimic
	"celesto_name":        "res://audio/Ender Audio/Celesto Name.wav",        # clicul de când aterizează bara cu numele
	"celesto_swish":       "res://audio/Ender Audio/Celesto Swish.wav",       # aerul din locul pe care tocmai l-a PĂRĂSIT (mono, se panoramează)
	"celesto_zap":         "res://audio/Ender Audio/Celesto Zap.wav",         # pocnetul de unde APARE (mono, se panoramează)
	"celesto_vanish":      "res://audio/Ender Audio/Celesto Vanish.wav",      # dispariția de la final
	"celesto_sub":         "res://audio/Ender Audio/Celesto Sub.wav",         # numai bas, se pune SUB freeze și sub dispariție
	"enemy_hit":      "res://audio/Enemy Hit.wav",                     # un proiectil a rănit un inamic
	"earthquake":     "res://audio/Earthquake.wav",                    # bubuitura de cutremur (vezi QUAKE_DB)
	"key_pickup":     "res://audio/Key Pickup.wav",                    # ai călcat pe o cheie de cufăr
	# --- MAGNETUL de XP (`magnet.gd`), DOUĂ straturi ---
	# Până pe 2026-08-18 magnetul suna cu `key_pickup`, adică EXACT ca o cheie de cufăr — deși e
	# alt obiect și face altceva. Acum are sunetul lui, luat din `Soundpack/` și prelucrat
	# (48 kHz/16 biți, vârf -1 dBFS; echilibrul e în `volume_db`, la chemare, ca la cinematici).
	#
	# De ce DOUĂ fișiere și nu unul: momentul are două lucruri de spus, unul după altul.
	#   • `magnet_pickup` (1,0 s) — CONTACTUL: ai călcat pe el. Transient metalic-magic, care
	#     taie prin harababura de luptă, ca să știi pe loc că ai luat ceva.
	#   • `magnet_pull` (1,8 s) — CE FACE: un val care URCĂ 0,4 s și se termină în sclipici. Urcarea
	#     e mișcarea spre tine a tot XP-ului de pe hartă, iar sclipiciul acoperă secunda în care
	#     gemele chiar aterizează. ⚠️ Fără el momentul e MUT: gemele culese n-au sunet propriu
	#     (vechiul „xp" a fost șters din listă), deci tot spectacolul se vedea, dar nu se auzea.
	# Se pornesc odată, cu `play_ex` (ton FIX): pe două straturi suprapuse, variația de ton a lui
	# `play` le-ar dezacorda între ele, de fiecare dată altfel.
	"magnet_pickup":  "res://audio/Magnet Pickup.wav",                 # ai călcat pe un magnet de XP
	"magnet_pull":    "res://audio/Magnet Pull.wav",                   # tot XP-ul de pe hartă vine spre tine
	"chest_open":     "res://audio/Chest Opening.wav",                 # ai apăsat E pe cufăr (capacul se ridică)
	"chest_anim":     "res://audio/Chest Animation.wav",               # explozia de raze de deasupra cufărului deschis
	# --- RULETA din cazinou (`casino_roata.gd`), ȘAPTE straturi ---
	# Alese din `Soundpack/` și prelucrate ca la cinematica lui Celesto: tăiate de liniște,
	# scurtate la cât ține momentul, 48 kHz/16 biți, vârf −1 dBFS. Deci în fișiere sunt toate la
	# fel de tari — echilibrul dintre ele stă în `casino_roata.gd` (constantele `DB_*`), ca la
	# orice mix de joc: schimbi mixul fără să reexporți nimic.
	#
	# De ce ȘAPTE și nu unul singur „de ruletă": învârtirea are șapte lucruri DIFERITE de spus,
	# iar dacă le spune același sunet nu se aude niciunul. Fiecare are exact o treabă:
	#   • `launch` — pornirea: pocnetul din degete al croupierului. O dată, la început.
	#   • `bed`    — huruitul mașinăriei. BUCLĂ, singurul de aici care nu trece prin `play()`;
	#                fișierul e croit ca să se închidă în buclă (coada stinsă peste cap).
	#                Tonul și volumul lui urmează viteza roții — el spune „încetinește".
	#   • `tick`   — bila trece pe lângă un braț al butucului. Ritmul lui, care rărește, e
	#                ceasul întregii învârtiri.
	#   • `drop`   — bila cade de pe rama de aur. E cel mai tare sunet din tot momentul: aici
	#                se hotărăște totul, și riser-ul se termină exact în el.
	#   • `clack`  — săriturile de după cădere (trei, tot mai stinse).
	#   • `settle` — bila s-a oprit în buzunar.
	#   • `riser`  — urcarea de sub ultima secundă, croită pe fix 1,10 s cât ține căderea.
	"roulette_launch": "res://audio/Casino Audio/Roulette Launch.wav",
	"roulette_bed":    "res://audio/Casino Audio/Roulette Bed.wav",
	"roulette_tick":   "res://audio/Casino Audio/Roulette Tick.wav",
	"roulette_drop":   "res://audio/Casino Audio/Roulette Drop.wav",
	"roulette_clack":  "res://audio/Casino Audio/Roulette Clack.wav",
	"roulette_settle": "res://audio/Casino Audio/Roulette Settle.wav",
	"roulette_riser":  "res://audio/Casino Audio/Roulette Riser.wav",
}

# Cutremurul are volumul lui, într-un singur loc: se aude din cinci locuri din joc (invocarea
# Gărzii, invocarea lui Saratalin, cinematica lui de la jumătate, Panic Button, portalul care
# se scufundă la ieșirea din Nether) și trebuie să bubuie la fel peste tot. Răzvan l-a vrut
# TARE — de-asta e peste 0, nu sub: e singurul sunet al jocului care înseamnă „se cutremură
# pământul". Decibelii nu se înmulțesc, se ADUNĂ: „de 2 ori mai tare" = +20·log10(2) ≈ +6 dB,
# deci 6 → 12 (cerut de Răzvan pe 2026-07-27, a doua rundă).
#
# ⚠️ De aici încolo NU mai există cap: fișierul are vârful la -2.4 dBFS, iar la +12 dB, cu
# slider-ul de efecte dat tare, vârful trece de maximul plăcii de sunet și se TAIE (bubuitura
# poate să pârâie). Dacă se aude spart, soluția nu e să cobori de aici, ci să scazi RESTUL
# efectelor — ce contează la urechi e diferența dintre ele, nu numărul absolut.
const QUAKE_DB := 12.0

const CHUNK_PX := 512.0     # mărimea unui chunk (ca în props/ground/pathways) — pentru desertness

# Muzica de fundal, pe ecrane. Gol = n-avem încă fișier (nu se aude nimic, fără erori).
const MUSIC_MENU := "res://audio/main menu theme.ogg"
# În joc: se alege UNA la întâmplare din listă la începutul fiecărei runde.
# Ca să adaugi o melodie nouă, pui fișierul în folder și mai scrii o linie aici.
# Din 2026-08-20 lista are un singur nume: Răzvan a scos `Ruined_Place` și `tiny-rpg-town` din
# folder și a pus în locul lor `Overworld Theme` — „vreau să se audă doar audio-ul de ți l-am pus
# acolo". A rămas listă tocmai ca a doua melodie să fie iar o singură linie de scris.
const MUSIC_GAME := [
	"res://audio/First 5 Minutes - Main World/Overworld Theme.mp3",
]
# În Nether: melodia locului, în buclă — de la intrare până când coboară Saratalin, și din nou
# după ce cade el (`nether.gd`).
const MUSIC_NETHER := "res://audio/Nether Audio/Nether Song.mp3"
# Tema lui Saratalin: intră când boss-ul coboară din tavan (`summoning_portal.gd`) și ține până
# moare (`nether.gd::boss_invins`). Cât se aude ea, ești în luptă — asta e tot ce spune.
const MUSIC_SARATALIN := "res://audio/Nether Audio/Saratalin Theme.mp3"
# Pușcăria n-are muzică proprie: împrumuta „bucla Nether-ului", adică `sky-lines`. Nether-ul și-a
# primit acum melodia lui, dar pușcăria a rămas tot pe `sky-lines` — altfel s-ar fi trezit peste
# noapte cu tema unui loc în care nu ești, iar Nether-ul ar fi împărțit-o cu altcineva.
# (E o singură linie de schimbat, dacă vrei totuși ca și pușcăria să sune a Nether.)
const MUSIC_PRISON := "res://audio/Nether Audio/sky-lines.ogg"
# În Ender: la fel, în buclă — dar NU de la intrare, ci de la capătul cinematicii lui Celesto
# (`ender.gd`, `_cutscene_gata`). Vezi acolo de ce.
const MUSIC_ENDER := "res://audio/Ender Audio/Ender Theme.ogg"

# Melodiile care APARȚIN unui loc anume. Niciuna nu poate fi ținută minte ca „melodia lumii" —
# vezi `_tine_minte_melodia()`, singurul motiv pentru care lista asta există.
const MUSIC_DIMENSIUNI := [MUSIC_NETHER, MUSIC_SARATALIN, MUSIC_PRISON, MUSIC_ENDER]

# --- Gaura de la capătul buclei ---
# Un fișier de muzică nu se termină fix pe ultima notă: în coadă rămâne liniște (fade-ul de la
# export, reverbul care se stinge, tăcerea lăsată de compozitor). La o melodie care se reia la
# nesfârșit, tăcerea aia devine o PAUZĂ în mijlocul jocului — la `Overworld Theme` sunt 2,3
# secunde, adică de trei-patru ori pe rundă muzica pare pur și simplu că s-a stricat.
# Godot n-are „punct de final al buclei" pentru mp3/ogg, așa că îl punem noi: în `_process`,
# când melodia ajunge la `lungime - trim`, o trimitem înapoi la zero. Cifrele sunt MĂSURATE
# (`test_muzica.gd`, 2026-08-20): cât ține liniștea din coadă, sub -45 dBFS.
# Ce nu apare aici n-are coadă de tăiat (`Saratalin Theme`: 0,13s — n-o auzi).
const MUSIC_TRIM := {
	"res://audio/First 5 Minutes - Main World/Overworld Theme.mp3": 2.2,
	"res://audio/Nether Audio/Nether Song.mp3": 0.45,
}

const POOL_SIZE := 20       # câte "boxe" (playere) avem pregătite
# 12 ajungeau când toate efectele erau scurte (0.2–0.4s). Sunetul de Mage Staff ține ~1.5s,
# iar cu attack speed mare se trage la ~0.2s → singur ar fi ținut ocupate vreo 8 boxe, iar
# pașii/loviturile ar fi început să se taie între ele. 20 e tot ieftin (un nod tăcut costă
# aproape nimic) și lasă loc de respiro.
const MIN_GAP_MS := 45      # pauza minimă între două redări ale ACELUIAȘI sunet (vezi `play`)
var _ultima := {}           # nume -> momentul (ms) când s-a auzit ultima oară
var _streams := {}          # nume -> AudioStream încărcat
var _players: Array = []    # lista de AudioStreamPlayer
var _next := 0              # ce boxă folosim data viitoare (rotativ)
const POOL_2D := 6          # boxe „cu loc pe hartă", numai pentru cinematici (vezi `play_pan`)
var _players_2d: Array = [] # lista de AudioStreamPlayer2D
var _next_2d := 0
var _music: AudioStreamPlayer  # boxă separată doar pentru muzica de fundal (în buclă)
var _music_path := ""       # ce melodie cântă acum (ca să n-o repornim degeaba)
var _music_base_db := 0.0   # volumul „de bază" al melodiei; peste el se adaugă reglajul din Settings
var _music_loop_end := 0.0  # secunda la care sărim înapoi la 0 (vezi MUSIC_TRIM); 0 = bucla lui Godot

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
	# și cele câteva boxe „cu loc" (vezi `play_pan`). Puține dinadins: se folosesc numai în
	# cinematici, unde sună 2-3 lucruri odată, nu în toiul luptei.
	for i in POOL_2D:
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = "Master"
		# Cât de departe se aude și cât de tare scade cu distanța. Aici NU vrem scădere: sunetul e
		# pus într-un loc ca să se audă din PARTEA aia, nu ca să pară departe — cinematica îl vrea
		# la fel de tare oriunde ar sări boss-ul. `attenuation` minim (0.1) + rază uriașă = plat.
		p2.max_distance = 6000.0
		p2.attenuation = 0.1
		p2.panning_strength = 2.0   # despărțire clară stânga/dreapta (implicit 1.0 abia se simte)
		add_child(p2)
		_players_2d.append(p2)

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

# --- redare pentru CINEMATICI ---
# `play()` de mai sus e făcut pentru JOC: ton puțin aleator (ca să nu sune identic de o mie de ori)
# și o pauză minimă de 45 ms între două redări ale aceluiași sunet (ca să nu se calce peste ele în
# Final Swarm). Într-o cinematică amândouă sunt pe dos: acolo fiecare sunet e pus la milisecundă,
# cu tonul lui ales, și trebuie să se audă NEGREȘIT. De-aia astea două sar peste ambele reguli.

# Ton FIX, fără poarta de 45 ms. `pitch`: 1.0 = tonul din fișier, 1.06 ≈ un semiton mai sus.
func play_ex(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _find_free_player()
	p.stream_paused = false
	p.stream = _streams[name]
	p.volume_db = volume_db + _lin_to_db(GameSettings.sfx_volume)
	p.pitch_scale = maxf(pitch, 0.01)
	p.play()

# Același lucru, dar sunetul vine DINTR-UN LOC de pe hartă: se aude dinspre partea în care s-a
# întâmplat. Într-o cinematică în care boss-ul sare stânga-dreapta, asta e diferența dintre „aud
# un pocnet" și „a apărut în DREAPTA mea".
# ⚠️ Cere un fișier MONO. Unul stereo are deja stânga/dreapta scrise în el și nu mai poate fi pus
# unde vrem noi — de-aia `Celesto Swish` și `Celesto Zap` sunt singurele două făcute mono.
# Cine ascultă e camera (Godot ia Camera2D-ul din viewport drept ureche), deci poziția se dă în
# coordonate de LUME, nu de ecran.
func play_pan(name: String, poz: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name) or _players_2d.is_empty():
		return
	var p: AudioStreamPlayer2D = _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _players_2d.size()
	p.stream_paused = false
	p.stream = _streams[name]
	p.global_position = poz
	p.volume_db = volume_db + _lin_to_db(GameSettings.sfx_volume)
	p.pitch_scale = maxf(pitch, 0.01)
	p.play()

# --- pentru cine își ține BOXA LUI ---
# Un sunet în BUCLĂ, cu volumul și tonul schimbate din cadru în cadru, nu poate trece prin
# `play()`: acolo boxa e împrumutată din grămadă și e luată înapoi la următorul efect. Așa ceva
# (deocamdată doar huruitul ruletei, `casino_roata.gd`) își face `AudioStreamPlayer`-ul lui și
# ia de aici cele două lucruri pe care nu are de unde să le știe.

# Volumul „Efecte" din Settings, în decibeli — de adunat la volumul propriu, exact cum face
# `play()`. Fără el, sunetul ăla ar rămâne tare și cu slider-ul dat la zero.
func sfx_db() -> float:
	return _lin_to_db(GameSettings.sfx_volume)

# Stream-ul deja încărcat al unui efect (null dacă nu există fișierul). Se ia de aici, nu cu
# `load()`, ca să rămână O SINGURĂ listă de sunete în joc: cea de sus.
func stream_for(name: String) -> AudioStream:
	return _streams.get(name)

# --- Muzică de fundal, în buclă ---
#
# 🎚️ TABELUL DE VOLUME — de ce fiecare melodie are alt număr.
# Fiecare fișier vine masterizat altfel: unul e tare, altul e domol. Dacă le-am da tuturor
# același `volume_db`, s-ar auzi ca la radio când sari între posturi. Deci NU le potrivim după
# ureche, ci le MĂSURĂM: fiecare melodie e pusă să cânte la 0 dB și se citește vârful magistralei
# Master în patru locuri din ea (0%, 25%, 50%, 75%), câte 3 secunde; media aia e „cât de tare e
# fișierul". Volumul din joc iese apoi din scădere. (Unealta: `test_muzica.gd`, 2026-08-20.)
#
#   melodie              media fișierului   volum în joc   cât se aude de fapt
#   Overworld Theme          -2,1 dBFS          -21,0           -23,1
#   main menu theme          -8,2               -14,0           -22,2
#   Nether Song              -7,7               -14,0           -21,7
#   sky-lines (pușcăria)     -9,4               -12,0           -21,4
#   Ender Theme              -3,4               -18,0           -21,4
#   Saratalin Theme          -4,4               -15,5           -19,9
#
# Ultima coloană e singura care contează la ureche, și de-aia arată așa: tot jocul stă la ~-21,5;
# lumea, care cântă zece minute în continuu, cu un pic mai jos; tema boss-ului, cu 1,8 dB peste
# restul — atât cât să simți că s-a schimbat ceva. Când mai vine o melodie: măsoar-o și scade
# media din -23 (lume) sau din -21,5 (dimensiuni). Urechea minte, contorul nu.
#
# Meniul o pornește cu play_menu_music(), jocul cu play_music() (spawner._ready).
# Meniul intră FĂRĂ fade-in (`fade_in = 0`): e primul lucru care se aude la pornirea jocului,
# iar o urcare de 3 secunde acolo se simte ca și cum sunetul ar fi stricat. Stingerea rămâne
# cu fade — când pleci din meniu în rundă, cele două melodii tot se încrucișează frumos.
func play_menu_music(volume_db: float = -14.0) -> void:
	_play_track(MUSIC_MENU, volume_db, 0.0)

# Muzica din joc: alege o melodie la întâmplare din MUSIC_GAME, alta (posibil) la fiecare rundă.
# Sar peste fișierele care lipsesc, ca să nu iasă tăcere dacă unul e șters/redenumit.
#
# ⚠️ -21, nu -12 ca înainte: `Overworld Theme` e masterizată cu 10 dB mai tare decât melodiile pe
# care le-a înlocuit (medie -2,1 dBFS, față de -12,2 la `Ruined_Place`). Lăsată la -12, ar fi
# acoperit tot jocul; la -21 se aude fix cât se auzea melodia veche. Vezi tabelul de volume.
func play_music(volume_db: float = -21.0) -> void:
	_nether_prev_path = ""   # rundă nouă → uităm ce cânta înainte de un Nether vechi
	var disponibile: Array = []
	for path in MUSIC_GAME:
		if ResourceLoader.exists(path):
			disponibile.append(path)
	if disponibile.is_empty():
		stop_music()
		return
	_play_track(disponibile[randi() % disponibile.size()], volume_db)

# --- Muzica din alte dimensiuni (Nether, Saratalin, Pușcărie, Ender) ---
# Pleci din lume → ținem minte CE cânta și DIN CE SECUNDĂ, apoi punem melodia locului în buclă.
# La întoarcere reluăm melodia lumii exact de unde a rămas (nu de la capăt), ca și cum
# ar fi cântat mai departe cât ai fost plecat.
var _nether_prev_path := ""
var _nether_prev_db := 0.0
var _nether_prev_pos := 0.0

# Melodia Nether-ului. Se cheamă de DOUĂ ori pe vizită: la intrare și încă o dată după ce cade
# Saratalin, ca să ia locul temei lui. A doua oară `_tine_minte_melodia()` nu face nimic — vezi
# acolo de ce, e chiar lucrul care ține „melodia lumii" nepătată.
# -14: `Nether Song` are media la -7,7 dBFS, deci ajunge fix unde stătea `sky-lines` la -12.
func play_nether_music(volume_db: float = -14.0) -> void:
	_tine_minte_melodia()
	_play_track(MUSIC_NETHER, volume_db)

# Tema lui Saratalin, când boss-ul atinge pământul. Stă cu 1,8 dB PESTE melodia Nether-ului
# (media măsurată -4,4 dBFS): atât cât să simți că s-a schimbat ceva, nu cât să dai volumul mai
# încet. Restul diferenței o face muzica însăși, nu numărul de aici.
func play_saratalin_music(volume_db: float = -15.5) -> void:
	# Boss-ul a ajuns → gata cu făcutul de loc pentru cutremur (`duck_music` din `invoca()`).
	# Punem coborârea la zero AICI, nu prin `unduck_music()`: melodia veche oricum se stinge, iar
	# cea nouă trebuie să urce direct la volumul ei întreg. `unduck_music()` ar fi tras de același
	# `volume_db` ca fade-in-ul, și se băteau între ele.
	_duck_db = 0.0
	_play_track(MUSIC_SARATALIN, volume_db)

# Pușcăria: aceeași melodie ca înainte (`sky-lines`), doar că acum și-o cere pe nume.
func play_prison_music(volume_db: float = -12.0) -> void:
	_tine_minte_melodia()
	_play_track(MUSIC_PRISON, volume_db)

# Tema Ender-ului. NU ține minte melodia lumii: când se cheamă ea, lumea e deja pusă deoparte de
# `stop_music_tinand_minte()` la intrarea în dimensiune. Dacă ar ține minte, ar salva „tăcere"
# peste melodia lumii și la ieșire ai fi primit alta, de la capăt.
#
# -18, nu -12 ca celelalte: fișierul e masterizat mai tare (medie -3,4 dBFS). Vezi tabelul de
# volume de la începutul secțiunii.
func play_ender_music(volume_db: float = -18.0) -> void:
	_play_track(MUSIC_ENDER, volume_db)

# Ține minte melodia lumii și TACE. Folosit la intrarea în Ender: peste cinematica lui Celesto
# nu vrem nicio melodie (are sunetul ei), iar tema locului intră abia la capătul ei.
#
# ⚠️ Stingerea e SCURTĂ (0,6s), nu cele 3 secunde obișnuite. Melodia care se stinge nu mai poate fi
# coborâtă de `duck_music` (aia lucrează pe melodia CURENTĂ, iar aici nu mai e niciuna) — deci, cu
# fade-ul normal, melodia lumii ar fi rămas la volum întreg peste primele 3 secunde de cinematică,
# adică fix peste înghețul timpului. 0,6s = apucă să se ducă sub sunetul teleportării.
func stop_music_tinand_minte(secunde: float = 0.6) -> void:
	_tine_minte_melodia()
	stop_music(false, secunde)

func _tine_minte_melodia() -> void:
	if _music == null or not _music.playing:
		return
	# ⚠️ „Melodia lumii" e ce se auzea ÎNAINTE să pleci de acasă — niciodată melodia unui loc în
	# care ești deja. Fără linia asta, `play_nether_music()` chemat a doua oară (după ce cade
	# Saratalin) ar fi ținut minte TEMA LUI SARATALIN, iar la ieșirea din Nether te-ai fi întors
	# în lumea normală cu muzică de boss peste cap. E o plasă de siguranță, nu o optimizare:
	# orice cod scris de aici înainte poate chema liniștit funcțiile astea de câte ori vrea.
	if _music_path in MUSIC_DIMENSIUNI:
		return
	_nether_prev_path = _music_path
	_nether_prev_db = _music_base_db
	_nether_prev_pos = _music.get_playback_position()

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

# Oprește muzica STINGÂND-O în `secunde` (implicit FADE). `imediat = true` o taie pe loc (nu se
# folosește în joc; e acolo pentru cazurile în care chiar vrei liniște instantă).
func stop_music(imediat: bool = false, secunde: float = FADE) -> void:
	_music_path = ""
	_music_loop_end = 0.0   # boxa care se stinge n-are de ce să mai sară înapoi la început
	if _music == null:
		return
	if imediat:
		_opreste_tween(_tw_in)
		_music.stop()
		return
	_stinge(_music, secunde)
	_music = null   # boxa curentă devine „cea care se stinge"; următoarea melodie primește una nouă

# Stinge o boxă în `secunde` și apoi o oprește. Boxa e reținută în `_music_vechi` ca s-o
# putem pune pe pauză odată cu restul (ESC) și ca să nu se calce două stingeri una pe alta.
func _stinge(p: AudioStreamPlayer, secunde: float = FADE) -> void:
	if p == null:
		return
	if not p.playing:
		p.queue_free()   # n-are ce stinge, dar boxa tot trebuie eliberată (altfel se adună)
		return
	_opreste_tween(_tw_out)
	# ⚠️ Și tween-ul de „ducking": el trage tot pe `volume_db`-ul boxei ăsteia. Lăsat în aer, ar
	# urca-o la loc exact în timp ce noi o stingem, iar melodia veche ar rămâne agățată sub cea
	# nouă. (Se întâmplă dacă schimbi melodia în timp ce muzica își revine după o cinematică.)
	_opreste_tween(_tw_duck)
	if _music_vechi != null and _music_vechi != p and is_instance_valid(_music_vechi):
		_music_vechi.stop()   # deja se stingea alta → o tăiem, n-avem trei melodii deodată
		_music_vechi.queue_free()
	_music_vechi = p
	_tw_out = create_tween()
	_tw_out.tween_property(p, "volume_db", TACERE_DB, secunde)
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

# `fade_in` = în câte secunde urcă melodia NOUĂ de la tăcere la volumul ei. 0 = pornește direct
# la volum (folosit de meniu). Stingerea celei vechi ține oricum FADE secunde.
func _play_track(path: String, volume_db: float, fade_in: float = FADE) -> void:
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
	# unde se termină muzica de fapt, dacă fișierul are liniște în coadă (vezi MUSIC_TRIM)
	_music_loop_end = 0.0
	if MUSIC_TRIM.has(path):
		_music_loop_end = maxf(s.get_length() - float(MUSIC_TRIM[path]), 1.0)
	_music.stream = s
	_opreste_tween(_tw_in)
	if fade_in <= 0.0:
		# fără fade: pornește direct la volumul cerut (+ reglajul din Settings)
		_music.volume_db = _volum_muzica()
		_music.play()
		return
	# pornim din tăcere și urcăm în `fade_in` secunde până la volumul cerut
	_music.volume_db = TACERE_DB
	_music.play()
	_tw_in = create_tween()
	_tw_in.tween_property(_music, "volume_db", _volum_muzica(), fade_in)

func _volum_muzica() -> float:
	return _music_base_db + _lin_to_db(GameSettings.music_volume) + _duck_db   # reglajul „Muzică" din Settings

# --- COBORÂREA muzicii sub o cinematică („ducking") ---
# Prima regulă a sunetului de film: când vrei să se audă ceva, faci LOC pentru el. Melodia de fundal
# ocupă exact mijlocul în care stau și bubuiturile cinematicii; lăsată sus, tot ce urmează sună
# „într-o cameră plină". Coborâtă cu 16 dB, aceleași sunete par de două ori mai mari, fără să fi
# dat pe nimic mai tare — iar la loc urcă lent, ca și cum lumea își revine.
#
# `_duck_db` se ADUNĂ în `_volum_muzica()`, deci mișcarea slider-ului din Settings în timpul unei
# cinematici (sau schimbarea melodiei) păstrează coborârea, nu o anulează.
var _duck_db := 0.0
var _tw_duck: Tween

func duck_music(cat_db: float = -16.0, timp: float = 0.25) -> void:
	_duck_db = cat_db
	_urmeaza_volumul(timp)

func unduck_music(timp: float = 1.4) -> void:
	_duck_db = 0.0
	_urmeaza_volumul(timp)

func _urmeaza_volumul(timp: float) -> void:
	_opreste_tween(_tw_duck)
	if _music == null or not is_instance_valid(_music):
		return
	# ⚠️ Oprim și fade-in-ul melodiei, dacă tocmai urca: două tween-uri pe același `volume_db` s-ar
	# trage unul pe altul, iar rezultatul ar depinde de care s-a creat ultimul.
	_opreste_tween(_tw_in)
	if timp <= 0.0:
		_music.volume_db = _volum_muzica()
		return
	_tw_duck = create_tween()
	_tw_duck.tween_property(_music, "volume_db", _volum_muzica(), timp)

# Sare peste liniștea din coada melodiei, ca bucla să n-aibă pauză (vezi MUSIC_TRIM). Chemat
# în fiecare cadru din `_process`; după `seek(0)` poziția e la zero, deci nu se retrimite.
func _taie_coada_buclei() -> void:
	if _music_loop_end <= 0.0 or _music == null or not _music.playing:
		return
	if _music.get_playback_position() >= _music_loop_end:
		_music.seek(0.0)

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
	_taie_coada_buclei()
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
	for p in _players_2d:
		p.stream_paused = pe_pauza

# Găsește o boxă care nu cântă; dacă toate cântă, o refolosește pe următoarea (rotativ).
func _find_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	return p
