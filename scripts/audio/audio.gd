extends Node
## Sonido del juego (autoload "Audio").
## - Música: temas medievales CC0 de RandomMind (OpenGameArt), en assets/audio/music.
## - Efectos: sintetizados por código al arrancar (originales, sin licencias de terceros).
## - Volúmenes por bus (Música / Efectos) guardados en Save.data["settings"].
## - Vibración opcional en el móvil.

const RATE := 22050
const MUSIC := {
	"menu": "res://assets/audio/music/menu_old_tower_inn.mp3",
	"battle": "res://assets/audio/music/battle.mp3",
	"battle2": "res://assets/audio/music/battle_market_day.mp3",
	"victory": "res://assets/audio/music/victory.mp3",
	"defeat": "res://assets/audio/music/defeat.mp3",
}
const LOOPING := ["menu", "battle", "battle2"]
## Sonido de cada tipo de proyectil de las torres.
const PROJECTILE_SFX := {
	"arrow": "arrow", "arrow_poison": "arrow", "bolt": "arrow", "fireball": "fire", "fire": "fire",
	"ice": "ice", "rocket": "cannon", "rock": "cannon", "": "zap", "flask": "pop", "void": "magic",
	"holy": "magic", "slash": "slash",
}
const POOL_SIZE := 14

var _sfx := {}
var _last_play := {}
var _pool: Array = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)
	_build_sfx()
	apply_settings()


# ---------------------------------------------------------------- Ajustes
func setting(key: String, default_value = null):
	return Save.data.get("settings", {}).get(key, default_value)


func set_setting(key: String, value) -> void:
	if not Save.data.has("settings"):
		Save.data["settings"] = {}
	Save.data["settings"][key] = value
	Save.save_game()
	apply_settings()


func apply_settings() -> void:
	_set_bus("Music", float(setting("music_vol", 0.7)) if bool(setting("music", true)) else 0.0)
	_set_bus("SFX", float(setting("sfx_vol", 0.8)) if bool(setting("sound", true)) else 0.0)


func _set_bus(bus: String, vol: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, vol <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(vol, 0.001)))


func vibrate(ms := 40) -> void:
	if bool(setting("vibration", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# ---------------------------------------------------------------- Música
func play_music(id: String) -> void:
	if id == _music_id or not MUSIC.has(id) or not ResourceLoader.exists(MUSIC[id]):
		return
	_music_id = id
	var stream: AudioStream = load(MUSIC[id])
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = id in LOOPING
	# Fundido cruzado entre el tema anterior y el nuevo
	var old := _music_a if _music_a.playing else null
	var nxt := _music_b if old == _music_a else _music_a
	nxt.stream = stream
	nxt.volume_db = -30.0
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, 1.2)
	if old != null:
		tw.tween_property(old, "volume_db", -40.0, 1.2)
		tw.chain().tween_callback(old.stop)
	if old == null and _music_b.playing and nxt != _music_b:
		_music_b.stop()


func stop_music() -> void:
	_music_id = ""
	for m in [_music_a, _music_b]:
		m.stop()


# ---------------------------------------------------------------- Efectos
## Reproduce un efecto. `min_gap` evita que 30 torres disparando saturen el sonido.
func sfx(id: String, volume_db := 0.0, pitch_var := 0.08, min_gap := 0.05) -> void:
	if not _sfx.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(id, -10.0)) < min_gap:
		return
	_last_play[id] = now
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _sfx[id]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func shot(projectile_style: String) -> void:
	sfx(PROJECTILE_SFX.get(projectile_style, "arrow"), -8.0, 0.12, 0.07)


# ---------------------------------------------------------------- Síntesis
func _build_sfx() -> void:
	_sfx["click"] = _make(0.06, func(t: float) -> float: return _sine(t, lerpf(900.0, 650.0, t / 0.06)) * _env(t, 0.002, 0.06))
	_sfx["arrow"] = _make(0.12, func(t: float) -> float:
		return (_noise() * 0.6 + _sine(t, lerpf(1400.0, 500.0, t / 0.12)) * 0.4) * _env(t, 0.003, 0.12) * 0.7)
	_sfx["cannon"] = _make(0.45, func(t: float) -> float:
		return (_sine(t, lerpf(110.0, 38.0, t / 0.45)) * 0.8 + _noise() * 0.5 * exp(-t * 14.0)) * _env(t, 0.004, 0.45))
	_sfx["fire"] = _make(0.3, func(t: float) -> float:
		return (_noise() * 0.5 * (0.6 + 0.4 * sin(t * 90.0)) + _sine(t, lerpf(300.0, 140.0, t / 0.3)) * 0.4) * _env(t, 0.02, 0.3))
	_sfx["ice"] = _make(0.35, func(t: float) -> float:
		return (_sine(t, 1760.0) * 0.4 + _sine(t, 2637.0) * 0.3 + _sine(t, 3520.0) * 0.15) * _env(t, 0.004, 0.35))
	_sfx["zap"] = _make(0.22, func(t: float) -> float:
		var sq := 1.0 if sin(TAU * t * lerpf(220.0, 90.0, t / 0.22)) > 0.0 else -1.0
		return (sq * 0.3 + _noise() * 0.5 * (1.0 if randf() > 0.6 else 0.2)) * _env(t, 0.002, 0.22))
	_sfx["magic"] = _make(0.3, func(t: float) -> float:
		var f := lerpf(500.0, 1300.0, t / 0.3) * (1.0 + 0.03 * sin(t * 60.0))
		return (_sine(t, f) * 0.5 + _sine(t, f * 1.5) * 0.25) * _env(t, 0.01, 0.3))
	_sfx["pop"] = _make(0.15, func(t: float) -> float: return _sine(t, lerpf(500.0, 180.0, t / 0.15)) * _env(t, 0.003, 0.15))
	_sfx["slash"] = _make(0.14, func(t: float) -> float: return _noise() * _env(t, 0.01, 0.14) * (0.5 + 0.5 * t / 0.14))
	_sfx["death"] = _make(0.2, func(t: float) -> float:
		var sq := 1.0 if sin(TAU * t * lerpf(380.0, 110.0, t / 0.2)) > 0.0 else -1.0
		return sq * 0.25 * _env(t, 0.003, 0.2))
	_sfx["coin"] = _make(0.22, func(t: float) -> float:
		return _sine(t, 988.0 if t < 0.07 else 1319.0) * _env(t, 0.002, 0.22) * 0.6)
	_sfx["gem"] = _make(0.45, func(t: float) -> float:
		return (_sine(t, 1568.0) + _sine(t, 2093.0) * (0.0 if t < 0.1 else 1.0) + _sine(t, 2637.0) * (0.0 if t < 0.2 else 1.0)) * 0.25 * _env(t, 0.003, 0.45))
	_sfx["build"] = _make(0.22, func(t: float) -> float:
		return (_sine(t, lerpf(220.0, 120.0, t / 0.22)) * 0.7 + _noise() * 0.4 * exp(-t * 30.0)) * _env(t, 0.003, 0.22))
	_sfx["levelup"] = _make(0.5, func(t: float) -> float:
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var f: float = notes[mini(int(t / 0.1), 3)]
		return (_sine(t, f) * 0.5 + _sine(t, f * 2.0) * 0.15) * _env(t, 0.005, 0.5))
	_sfx["horn"] = _make(0.9, func(t: float) -> float:
		var s := _saw(t, 220.0) * 0.35 + _saw(t, 330.0) * 0.2 + _sine(t, 110.0) * 0.3
		return s * minf(t / 0.12, 1.0) * clampf((0.9 - t) / 0.3, 0.0, 1.0) * 0.6)
	_sfx["boss"] = _make(1.1, func(t: float) -> float:
		var s := _saw(t, 68.0 + 6.0 * sin(t * 9.0)) * 0.5 + _noise() * 0.25
		return s * (0.6 + 0.4 * sin(t * 25.0)) * minf(t / 0.1, 1.0) * clampf((1.1 - t) / 0.4, 0.0, 1.0) * 0.7)
	_sfx["hurt"] = _make(0.25, func(t: float) -> float:
		return (_sine(t, lerpf(160.0, 60.0, t / 0.25)) * 0.8 + _noise() * 0.3 * exp(-t * 20.0)) * _env(t, 0.003, 0.25))
	_sfx["error"] = _make(0.18, func(t: float) -> float: return _saw(t, 140.0) * 0.3 * _env(t, 0.005, 0.18))


func _make(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(float(fn.call(float(i) / RATE)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func _sine(t: float, f: float) -> float:
	return sin(TAU * f * t)


static func _saw(t: float, f: float) -> float:
	return 2.0 * fposmod(t * f, 1.0) - 1.0


static func _noise() -> float:
	return randf() * 2.0 - 1.0


## Envolvente: subida rápida y caída exponencial hasta el final.
static func _env(t: float, attack: float, dur: float) -> float:
	if t < attack:
		return t / attack
	var k := (t - attack) / maxf(dur - attack, 0.001)
	return pow(1.0 - clampf(k, 0.0, 1.0), 2.0)
