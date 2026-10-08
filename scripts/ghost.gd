class_name Ghost
extends Node3D
## 刑務所をさまよう幽霊。壁をすり抜けてプレイヤーを追う。
## 瓶から逃げ出した幽霊は常に敵対し、徘徊霊は近づいたときだけ追ってくる。

const CONTACT_RANGE := 1.2
const WANDER_RADIUS := 6.0

var target: Node3D
var hostile := false
var chase_speed: float = GameBalance.current().wanderer_chase_speed
var wander_speed := 1.2
var aggro_range: float = GameBalance.current().ghost_aggro_range
var damage_per_second: float = GameBalance.current().ghost_damage_per_second
var home := Vector3.ZERO
## 出現してから動き出すまでの秒数。逃げ出した直後はその場で膨らむだけで、プレイヤーに逃げる猶予を与える
var emerge_time := 0.0

var _wander_goal := Vector3.ZERO
var _wander_timer := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _material := StandardMaterial3D.new()
var _body := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _wail := AudioStreamPlayer3D.new()


func _ready() -> void:
	_rng.randomize()
	home = position
	_wander_goal = home
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.1
	mesh.material = _material
	_body.mesh = mesh
	add_child(_body)
	_light.omni_range = 4.0
	_light.light_energy = 1.2
	add_child(_light)
	_wail.stream = Sfx.get_stream(&"ghost_wail")
	_wail.max_distance = 20.0
	_wail.unit_size = 3.0
	add_child(_wail)
	_wail.play(_rng.randf() * _wail.stream.get_length())
	_apply_color()


func _physics_process(delta: float) -> void:
	_time += delta
	if emerge_time > 0.0:
		emerge_time -= delta
		_body.scale = Vector3.ONE * clampf(1.0 - emerge_time, 0.2, 1.0)
		_apply_color()
		return
	_body.scale = Vector3.ONE
	var chasing := _is_chasing()
	var goal: Vector3
	var speed: float
	if chasing:
		goal = _target_point()
		speed = chase_speed
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0 or global_position.distance_to(_wander_goal) < 0.3:
			_wander_timer = _rng.randf_range(2.0, 5.0)
			_wander_goal = home + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * WANDER_RADIUS
		goal = _wander_goal
		speed = wander_speed

	var to_goal := goal - global_position
	if to_goal.length() > 0.05:
		global_position += to_goal.normalized() * minf(speed * delta, to_goal.length())
	_body.position.y = sin(_time * 2.0) * 0.15

	if chasing and global_position.distance_to(_target_point()) < CONTACT_RANGE and target.has_method("take_damage"):
		target.take_damage(damage_per_second * delta)
	_apply_color()


func _is_chasing() -> bool:
	if not is_instance_valid(target):
		return false
	return hostile or global_position.distance_to(_target_point()) < aggro_range


func _target_point() -> Vector3:
	return target.global_position + Vector3(0, 1.2, 0)


func _apply_color() -> void:
	var chasing := _is_chasing()
	_wail.volume_db = -4.0 if chasing else -14.0
	_wail.pitch_scale = 1.15 if chasing else 1.0
	var color := Color(1.0, 0.25, 0.2) if chasing else Color(0.75, 0.85, 1.0)
	color.a = 0.35 + 0.2 * sin(_time * 7.0) * sin(_time * 3.1)
	_material.albedo_color = color
	_light.light_color = color
