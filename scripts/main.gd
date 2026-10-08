extends Node3D
## ゲーム全体の進行。夜ごとに刑務所を生成し、ノルマを達成すれば次の夜へ、
## 未達成か取り憑かれたら収監（ゲームオーバー）になる。全クリはなく、記録は「到達した夜」。

enum State { PLAYING, NIGHT_CLEAR, GAME_OVER }

const NIGHT_DURATION := 180.0
const BASE_QUOTA := 300
const QUOTA_GROWTH := 1.35
const BASE_JAR_COUNT := 6
const JARS_PER_NIGHT := 2
const RARE_CHANCE := 0.15
const VALUE_GROWTH_PER_NIGHT := 0.15
const MAX_WANDERERS := 4
const CLEAR_DELAY := 3.0
const SAVE_PATH := "user://save.cfg"

var night := 1
var quota := BASE_QUOTA
var earned := 0
var time_left := NIGHT_DURATION
var best_night := 0
var state := State.PLAYING

var level: Node3D
var player: Player
var zone: ExtractionZone
var hud := Hud.new()

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	InputSetup.register()
	_setup_environment()
	add_child(hud)
	_load_best()
	_rng.randomize()
	start_night()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_density = 0.03
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func start_night() -> void:
	if level:
		remove_child(level)
		level.queue_free()
	var level_rng := RandomNumberGenerator.new()
	level_rng.seed = _rng.randi()

	level = Node3D.new()
	level.name = "Level"
	add_child(level)
	var layout := LevelGenerator.new(level_rng).build(level)
	var start: Vector3 = layout["start"]

	zone = ExtractionZone.new()
	zone.position = start
	zone.jar_sold.connect(_on_jar_sold)
	level.add_child(zone)

	player = Player.new()
	player.position = start + Vector3(0, 0.1, 0)
	player.damaged.connect(hud.flash_damage)
	player.died.connect(_on_player_died)
	level.add_child(player)

	_spawn_jars(level_rng, layout["jar_spots"])
	_spawn_wanderers(layout["ghost_spots"])

	earned = 0
	time_left = NIGHT_DURATION
	state = State.PLAYING
	hud.show_message("夜 %d\nノルマ ¥%d" % [night, quota], 3.0)


func _spawn_jars(rng: RandomNumberGenerator, spots: Array[Vector3]) -> void:
	var count := mini(BASE_JAR_COUNT + JARS_PER_NIGHT * (night - 1), spots.size())
	var value_scale := 1.0 + VALUE_GROWTH_PER_NIGHT * (night - 1)
	for i in count:
		var rare := rng.randf() < RARE_CHANCE
		var base_value := rng.randi_range(200, 320) if rare else rng.randi_range(60, 120)
		var jar := GhostJar.new()
		jar.setup(int(base_value * value_scale), rare)
		jar.position = spots[i] + Vector3(0, 0.31, 0)
		jar.escaped.connect(_on_jar_escaped)
		level.add_child(jar)


## 2夜目以降は、最初から刑務所をさまよう幽霊が出る。
func _spawn_wanderers(spots: Array[Vector3]) -> void:
	for i in mini(mini(night - 1, MAX_WANDERERS), spots.size()):
		var ghost := Ghost.new()
		ghost.position = spots[i]
		ghost.target = player
		level.add_child(ghost)


func _process(delta: float) -> void:
	if state == State.PLAYING:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			end_night()
	hud.set_stats(night, quota, earned, time_left, player.hp)
	hud.set_hint(_current_hint())


func _current_hint() -> String:
	match state:
		State.GAME_OVER:
			return "[R] もう一度"
		State.NIGHT_CLEAR:
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
	if event.is_action_pressed("end_night") and state == State.PLAYING and zone.player_inside and earned >= quota:
		end_night()
	elif event.is_action_pressed("restart") and state == State.GAME_OVER:
		restart()


func end_night() -> void:
	if state != State.PLAYING:
		return
	if earned < quota:
		_game_over("ノルマ未達成……あなたは収監された")
		return
	state = State.NIGHT_CLEAR
	player.controls_enabled = false
	hud.show_message("夜 %d 突破！\n収益 ¥%d / ノルマ ¥%d" % [night, earned, quota], CLEAR_DELAY)
	await get_tree().create_timer(CLEAR_DELAY).timeout
	if state != State.NIGHT_CLEAR:
		return
	night += 1
	quota = int(round(quota * QUOTA_GROWTH / 10.0)) * 10
	start_night()


func restart() -> void:
	night = 1
	quota = BASE_QUOTA
	start_night()


func _game_over(reason: String) -> void:
	state = State.GAME_OVER
	player.controls_enabled = false
	if night > best_night:
		best_night = night
		_save_best()
	hud.show_message("%s\n到達：夜 %d（最高記録：夜 %d）" % [reason, night, best_night], 0.0)


func _on_jar_sold(amount: int) -> void:
	if state != State.PLAYING:
		return
	earned += amount
	hud.show_message("+¥%d" % amount, 1.5)


func _on_jar_escaped(jar: GhostJar) -> void:
	var ghost := Ghost.new()
	ghost.position = jar.global_position + Vector3(0, 0.5, 0)
	ghost.target = player
	ghost.hostile = true
	ghost.chase_speed = 3.2
	level.add_child(ghost)
	hud.show_message("封印が破れた！", 1.5)


func _on_player_died() -> void:
	if state == State.PLAYING:
		_game_over("霊に取り憑かれた……")


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_night = config.get_value("record", "best_night", 0)


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("record", "best_night", best_night)
	config.save(SAVE_PATH)
