class_name Player
extends CharacterBody3D
## 一人称視点の回収業者。霊瓶を掴んで運ぶ・投げる。懐中電灯を持っている。

signal damaged(amount: float)
signal died

const ACCELERATION := 40.0
const JUMP_VELOCITY := 4.5
const BASE_MOUSE_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.6
const GRAB_DISTANCE := 3.0
const HOLD_DISTANCE := 1.6
const HOLD_STIFFNESS := 12.0
const MAX_HOLD_SPEED := 10.0
const DROP_DISTANCE := 2.5
const THROW_IMPULSE := 8.0
const STEP_LENGTH := 2.2

var balance: GameBalance = GameBalance.current()
var hp := balance.max_hp
var controls_enabled := true
var held: GhostJar = null

var camera := Camera3D.new()
var _ray := RayCast3D.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _dead := false
var _step_distance := 0.0


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)

	camera.position.y = EYE_HEIGHT
	camera.current = true
	add_child(camera)

	_ray.target_position = Vector3(0, 0, -GRAB_DISTANCE)
	_ray.add_exception(self)
	camera.add_child(_ray)

	var flashlight := SpotLight3D.new()
	flashlight.spot_range = 18.0
	flashlight.spot_angle = 28.0
	flashlight.light_energy = 2.5
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.2, -0.2, 0)
	camera.add_child(flashlight)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# 画面を粗くしても感度が変わらないよう、拡大前の移動量（screen_relative）を使う
		var sensitivity := BASE_MOUSE_SENSITIVITY * Config.mouse_sensitivity
		rotate_y(-event.screen_relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.screen_relative.y * sensitivity, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed and controls_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint")
	var speed := balance.sprint_speed if sprinting else balance.walk_speed
	if held:
		speed *= balance.carry_speed_factor
	# 加速を緩やかにして、急発進で瓶が揺れすぎないようにする
	velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
	move_and_slide()
	_update_footsteps(delta, sprinting)

	_update_held()
	if controls_enabled:
		_handle_interaction()


func _update_footsteps(delta: float, sprinting: bool) -> void:
	if not is_on_floor():
		return
	_step_distance += Vector2(velocity.x, velocity.z).length() * delta
	if _step_distance >= STEP_LENGTH:
		_step_distance = 0.0
		Sfx.play(self, &"footstep", -9.0 if sprinting else -14.0, randf_range(0.85, 1.1))


func _handle_interaction() -> void:
	if Input.is_action_just_pressed("grab"):
		if held:
			release()
		else:
			var jar := get_aimed_jar()
			if jar:
				_hold(jar)
	elif Input.is_action_just_pressed("throw") and held:
		var jar := held
		release()
		jar.apply_central_impulse(-camera.global_basis.z * THROW_IMPULSE)


func get_aimed_jar() -> GhostJar:
	_ray.force_raycast_update()
	var collider := _ray.get_collider()
	if collider is GhostJar and not collider.is_queued_for_deletion():
		return collider
	return null


func _hold(jar: GhostJar) -> void:
	held = jar
	jar.held = true
	jar.gravity_scale = 0.0
	jar.add_collision_exception_with(self)
	add_collision_exception_with(jar)


func release() -> void:
	if held and is_instance_valid(held):
		held.held = false
		held.gravity_scale = 1.0
		held.remove_collision_exception_with(self)
		remove_collision_exception_with(held)
	held = null


## 掴んだ瓶を視線の先へバネのように引き寄せる。
func _update_held() -> void:
	if held == null:
		return
	if not is_instance_valid(held) or held.is_queued_for_deletion():
		held = null
		return
	var target := camera.global_position - camera.global_basis.z * HOLD_DISTANCE
	var to_target := target - held.global_position
	if to_target.length() > DROP_DISTANCE:
		release()
		return
	held.linear_velocity = (to_target * HOLD_STIFFNESS).limit_length(MAX_HOLD_SPEED)
	held.angular_velocity = held.angular_velocity.lerp(Vector3.ZERO, 0.3)


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount)
	if hp <= 0.0:
		_dead = true
		controls_enabled = false
		release()
		died.emit()
