class_name Sfx
extends RefCounted
## 効果音をコードで合成する（音声ファイル不要）。一度作った音はキャッシュして使い回す。
## 本番用の音素材ができたら、get_stream() の中身を差し替えるだけで済む。

const MIX_RATE := 22050

static var _cache := {}


static func get_stream(sound: StringName) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _synthesize(sound)
	return _cache[sound]


## 位置を持たない音（UI、自分の足音など）を鳴らす。鳴り終わったら自動で消える。
static func play(parent: Node, sound: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	_start(parent, AudioStreamPlayer.new(), sound, volume_db, pitch)


## 3D 空間の指定位置で音を鳴らす。
static func play_at(parent: Node3D, sound: StringName, global_pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.position = parent.to_local(global_pos)
	player.max_distance = 30.0
	_start(parent, player, sound, volume_db, pitch)


static func _start(parent: Node, player: Node, sound: StringName, volume_db: float, pitch: float) -> void:
	player.stream = get_stream(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()


static func _synthesize(sound: StringName) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	match sound:
		&"footstep":
			return _to_stream(_footstep(rng), false)
		&"clink":
			return _to_stream(_clink(), false)
		&"jar_hum":
			return _to_stream(_jar_hum(), true)
		&"ghost_wail":
			return _to_stream(_ghost_wail(rng), true)
		&"ambient":
			return _to_stream(_ambient(rng), true)
		&"sell":
			return _to_stream(_notes([880.0, 1318.5], 0.12, 0.7, 6.0), false)
		&"night_clear":
			return _to_stream(_notes([523.25, 659.25, 783.99, 1046.5], 0.14, 1.4, 4.0), false)
		&"escape":
			return _to_stream(_escape(rng), false)
		&"game_over":
			return _to_stream(_game_over(rng), false)
		&"ui_click":
			return _to_stream(_ui_click(), false)
	push_error("Unknown sound: %s" % sound)
	return _to_stream(PackedFloat32Array(), false)


static func _to_stream(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream


static func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * MIX_RATE))
	return out


## コンクリートを踏む鈍い音
static func _footstep(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _buffer(0.14)
	var low := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.12
		out[i] = (low * 2.5 + sin(TAU * 70.0 * t) * 0.5) * exp(-t * 35.0)
	return out


## ガラス瓶がぶつかる音
static func _clink() -> PackedFloat32Array:
	var out := _buffer(0.5)
	var partials := [Vector3(2400, 1.0, 12), Vector3(3650, 0.6, 16), Vector3(5200, 0.4, 22), Vector3(7100, 0.25, 30)]
	for i in out.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for p: Vector3 in partials:
			v += p.y * sin(TAU * p.x * t) * exp(-t * p.z)
		out[i] = v * 0.3
	return out


## 瓶の中で霊がうなる音（1 秒ループ。周波数はループが途切れないよう整数 Hz）
static func _jar_hum() -> PackedFloat32Array:
	var out := _buffer(1.0)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var v := sin(TAU * 110.0 * t) * 0.6 + sin(TAU * 165.0 * t) * 0.3 + sin(TAU * 220.0 * t) * 0.15
		out[i] = v * (0.75 + 0.25 * sin(TAU * 4.0 * t)) * 0.35
	return out


## 幽霊のうめき声（2 秒ループ）
static func _ghost_wail(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _buffer(2.0)
	var phase := 0.0
	var breath := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		phase += TAU * (330.0 + 25.0 * sin(TAU * 1.5 * t)) / MIX_RATE
		breath += (rng.randf_range(-1.0, 1.0) - breath) * 0.05
		var env := 0.6 + 0.4 * sin(TAU * 0.5 * t)
		out[i] = (sin(phase) * 0.5 + sin(phase * 1.5) * 0.2 + breath * 0.6) * env * 0.4
	return out


## 刑務所の環境音：低いうなりと遠い空調のノイズ（4 秒ループ）
static func _ambient(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _buffer(4.0)
	var rumble := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		rumble += (rng.randf_range(-1.0, 1.0) - rumble) * 0.02
		var v := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 82.5 * t) * 0.25 + rumble * 1.5
		out[i] = v * (0.7 + 0.3 * sin(TAU * 0.25 * t)) * 0.3
	return out


## 順番に鳴るベルの音（売却・夜突破）
static func _notes(freqs: Array, interval: float, seconds: float, decay: float) -> PackedFloat32Array:
	var out := _buffer(seconds)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for n in freqs.size():
			var local := t - n * interval
			if local >= 0.0:
				var f: float = freqs[n]
				v += (sin(TAU * f * local) + 0.3 * sin(TAU * f * 2.0 * local)) * exp(-local * decay)
		out[i] = v * 0.25
	return out


## 封印が破れたときの悲鳴
static func _escape(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _buffer(1.0)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(1400.0, 180.0, t) / MIX_RATE
		var v := sin(phase) * 0.5 + rng.randf_range(-1.0, 1.0) * 0.4 * exp(-t * 3.0)
		out[i] = v * exp(-t * 2.2) * 0.5
	return out


## ゲームオーバー：沈んでいく低音
static func _game_over(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _buffer(2.0)
	var phase := 0.0
	var rumble := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(220.0, 70.0, t / 2.0) / MIX_RATE
		rumble += (rng.randf_range(-1.0, 1.0) - rumble) * 0.03
		var v := signf(sin(phase)) * 0.25 + sin(phase) * 0.4 + rumble * 1.2
		out[i] = v * exp(-t * 1.2) * 0.5
	return out


static func _ui_click() -> PackedFloat32Array:
	var out := _buffer(0.06)
	for i in out.size():
		var t := float(i) / MIX_RATE
		out[i] = sin(TAU * 1800.0 * t) * exp(-t * 80.0) * 0.4
	return out
