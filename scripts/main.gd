extends Node
## ゲーム全体の進行。夜ごとに刑務所を生成し、ノルマを達成すれば次の夜へ、
## 未達成か取り憑かれたら収監（ゲームオーバー）になる。全クリはなく、記録は「到達した夜」。
##
## 3D の世界は低解像度の SubViewport に描いて拡大し、PS1 風の粗い画面にしている。
## HUD とメニューは通常の解像度のまま重ねる。

enum State { TITLE, PLAYING, NIGHT_CLEAR, GAME_OVER }

const CLEAR_DELAY := 3.0
const TITLE_CAMERA_SPEED := 0.12
const ESCAPE_EMERGE_TIME := 1.5
const POST_SHADER := preload("res://shaders/ps1_post.gdshader")

var save_path := "user://save.cfg"
var night := 1
var quota := 0
var earned := 0
var time_left := 0.0
var best_night := 0
var state := State.TITLE

var balance: GameBalance = GameBalance.current()
var world := Node3D.new()
var level: Node3D
var player: Player
var zone: ExtractionZone
var hud := Hud.new()
var menu := Menu.new()

var _container := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _post_material := ShaderMaterial.new()
var _title_camera: Camera3D
var _ambient := AudioStreamPlayer.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	InputSetup.register()
	_rng.randomize()
	_load_best()
	_setup_viewport()
	_setup_environment()

	_ambient.stream = Sfx.get_stream(&"ambient")
	_ambient.volume_db = -8.0
	add_child(_ambient)
	_ambient.play()

	add_child(hud)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu)
	menu.start_requested.connect(start_game)
	menu.retry_requested.connect(start_game)
	menu.resume_requested.connect(set_paused.bind(false))
	menu.title_requested.connect(show_title)
	menu.quit_requested.connect(get_tree().quit)

	Config.settings_changed.connect(_apply_settings)
	_apply_settings()
	show_title()


func _setup_viewport() -> void:
	_container.stretch = true
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post_material.shader = POST_SHADER
	_container.material = _post_material
	_viewport.audio_listener_enable_3d = true
	add_child(_container)
	_container.add_child(_viewport)
	_viewport.add_child(world)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_density = 0.04
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)


func _apply_settings() -> void:
	_container.stretch_shrink = clampi(Config.pixel_size, 1, 4)
	_post_material.set_shader_parameter("pixel_size", float(_container.stretch_shrink))


## タイトル画面。背景では刑務所の中をカメラがゆっくり見回す。
func show_title() -> void:
	set_paused(false)
	state = State.TITLE
	hud.visible = false
	_build_level()
	_title_camera = Camera3D.new()
	_title_camera.position = Vector3(0, 1.7, 0)
	level.add_child(_title_camera)
	_title_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show_title(best_night)


func start_game() -> void:
	set_paused(false)
	night = 1
	quota = balance.base_quota
	start_night()


func start_night() -> void:
	var layout := _build_level()
	var start: Vector3 = layout["start"]

	player = Player.new()
	player.position = start + Vector3(0, 0.1, 0)
	player.damaged.connect(hud.flash_damage)
	player.died.connect(_on_player_died)
	level.add_child(player)
	_spawn_wanderers(layout["ghost_spots"])

	earned = 0
	time_left = balance.night_duration
	state = State.PLAYING
	hud.visible = true
	menu.hide_all()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message("夜 %d\nノルマ ¥%d" % [night, quota], 3.0)


## フロア・搬出口・霊瓶を作り直す。プレイヤーと幽霊は呼び出し側で置く。
func _build_level() -> Dictionary:
	if level:
		world.remove_child(level)
		level.queue_free()
	player = null
	_title_camera = null

	var level_rng := RandomNumberGenerator.new()
	level_rng.seed = _rng.randi()
	level = Node3D.new()
	level.name = "Level"
	world.add_child(level)
	var layout := LevelGenerator.new(level_rng).build(level)

	zone = ExtractionZone.new()
	zone.position = layout["start"]
	zone.jar_sold.connect(_on_jar_sold)
	level.add_child(zone)
	_spawn_jars(level_rng, layout["jar_spots"])
	return layout


func _spawn_jars(rng: RandomNumberGenerator, spots: Array[Vector3]) -> void:
	var count := mini(balance.base_jar_count + balance.jars_per_night * (night - 1), spots.size())
	var value_scale := 1.0 + balance.value_growth_per_night * (night - 1)
	for i in count:
		var rare := rng.randf() < balance.rare_chance
		var value_range := balance.rare_value_range if rare else balance.common_value_range
		var jar := GhostJar.new()
		jar.setup(int(rng.randi_range(value_range.x, value_range.y) * value_scale), rare)
		jar.position = spots[i] + Vector3(0, 0.31, 0)
		jar.escaped.connect(_on_jar_escaped)
		level.add_child(jar)


## 2 夜目以降は、最初から刑務所をさまよう幽霊が出る。
func _spawn_wanderers(spots: Array[Vector3]) -> void:
	for i in mini(mini(night - 1, balance.max_wanderers), spots.size()):
		var ghost := Ghost.new()
		ghost.position = spots[i]
		ghost.target = player
		level.add_child(ghost)


func _process(delta: float) -> void:
	if state == State.TITLE:
		if is_instance_valid(_title_camera):
			_title_camera.rotate_y(delta * TITLE_CAMERA_SPEED)
		return
	if state == State.PLAYING:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			end_night()
	hud.set_stats(night, quota, earned, time_left, player.hp)
	hud.set_hint(_current_hint())


func _current_hint() -> String:
	if state != State.PLAYING:
		return ""
	if player.held and is_instance_valid(player.held):
		return "[E] 離す   [右クリック] 投げる   封印 %d%%" % int(player.held.seal)
	var jar := player.get_aimed_jar()
	if jar:
		return "[E] 掴む   霊瓶%s   価値 ¥%d   封印 %d%%" % [
			"（レア）" if jar.is_rare else "", jar.sale_value(), int(jar.seal)
		]
	if zone.player_inside and earned >= quota:
		return "[F] 夜を終える"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and (state == State.PLAYING or state == State.NIGHT_CLEAR):
		set_paused(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("end_night") and state == State.PLAYING and zone.player_inside and earned >= quota:
		end_night()
	elif event.is_action_pressed("restart") and state == State.GAME_OVER:
		start_game()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	hud.visible = not paused and state != State.TITLE
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		menu.show_pause()
	elif state == State.PLAYING or state == State.NIGHT_CLEAR:
		menu.hide_all()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func end_night() -> void:
	if state != State.PLAYING:
		return
	if earned < quota:
		_game_over("ノルマ未達成……")
		return
	state = State.NIGHT_CLEAR
	player.controls_enabled = false
	Sfx.play(self, &"night_clear")
	hud.show_message("夜 %d 突破！\n収益 ¥%d / ノルマ ¥%d" % [night, earned, quota], CLEAR_DELAY)
	# 一時停止中はタイマーも止める
	await get_tree().create_timer(CLEAR_DELAY, false).timeout
	if state != State.NIGHT_CLEAR:
		return
	night += 1
	quota = int(round(quota * balance.quota_growth / 10.0)) * 10
	start_night()


func _game_over(reason: String) -> void:
	state = State.GAME_OVER
	player.controls_enabled = false
	if night > best_night:
		best_night = night
		_save_best()
	Sfx.play(self, &"game_over")
	hud.show_message("", 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show_game_over("%s\n到達：夜 %d（最高記録：夜 %d）" % [reason, night, best_night])


func _on_jar_sold(amount: int) -> void:
	if state != State.PLAYING:
		return
	earned += amount
	Sfx.play(self, &"sell")
	hud.show_message("+¥%d" % amount, 1.5)


func _on_jar_escaped(jar: GhostJar) -> void:
	var ghost := Ghost.new()
	ghost.position = jar.global_position + Vector3(0, 0.5, 0)
	ghost.target = player
	ghost.hostile = true
	ghost.chase_speed = balance.escaped_chase_speed
	ghost.emerge_time = ESCAPE_EMERGE_TIME
	level.add_child(ghost)
	Sfx.play_at(level, &"escape", jar.global_position)
	if state == State.PLAYING:
		hud.show_message("封印が破れた！", 1.5)


func _on_player_died() -> void:
	if state == State.PLAYING:
		_game_over("霊に取り憑かれた……")


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		best_night = config.get_value("record", "best_night", 0)


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("record", "best_night", best_night)
	config.save(save_path)
