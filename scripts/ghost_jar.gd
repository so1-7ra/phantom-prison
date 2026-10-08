class_name GhostJar
extends RigidBody3D
## 幽霊を封じた瓶。速度が急に変わる（ぶつける・振り回す・投げる）と封印が弱まり、
## 0 になると中の幽霊が逃げ出して襲ってくる。

signal escaped(jar: GhostJar)

## 1 物理フレームでこれ以上速度が変わると封印にダメージが入る (m/s)
const DV_THRESHOLD := 1.0
const DV_DAMAGE := 8.0
const RATTLE_SEAL := 50.0
const CALM_COLOR := Color(0.45, 0.85, 1.0)
const RARE_COLOR := Color(0.8, 0.5, 1.0)
const ANGRY_COLOR := Color(1.0, 0.15, 0.1)

var value := 100
var is_rare := false
var fragility := 1.0
var seal := 100.0
var held := false

var _prev_velocity := Vector3.ZERO
var _settle_frames := 15
var _finished := false
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _core_material := StandardMaterial3D.new()
var _light := OmniLight3D.new()


## add_child() の前に呼ぶ。
func setup(jar_value: int, rare: bool) -> void:
	value = jar_value
	is_rare = rare
	fragility = 1.6 if rare else 1.0


func _ready() -> void:
	_rng.randomize()
	mass = 2.0
	var shape := CylinderShape3D.new()
	shape.radius = 0.25
	shape.height = 0.6
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var glass_material := StandardMaterial3D.new()
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.albedo_color = Color(0.7, 0.85, 0.9, 0.25)
	glass_material.roughness = 0.1
	var glass := CylinderMesh.new()
	glass.top_radius = 0.25
	glass.bottom_radius = 0.25
	glass.height = 0.6
	glass.material = glass_material
	_add_mesh(glass, Vector3.ZERO)

	var lid_material := StandardMaterial3D.new()
	lid_material.albedo_color = Color(0.25, 0.2, 0.15)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.22
	lid.bottom_radius = 0.26
	lid.height = 0.08
	lid.material = lid_material
	_add_mesh(lid, Vector3(0, 0.34, 0))

	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var core := SphereMesh.new()
	core.radius = 0.13
	core.height = 0.26
	core.material = _core_material
	_add_mesh(core, Vector3.ZERO)

	_light.omni_range = 2.5
	_light.light_energy = 0.8
	add_child(_light)
	_update_visuals()


func _add_mesh(mesh: Mesh, offset: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	add_child(instance)


func _physics_process(delta: float) -> void:
	_time += delta
	var dv := (linear_velocity - _prev_velocity).length()
	_prev_velocity = linear_velocity
	if _settle_frames > 0:
		_settle_frames -= 1
	elif dv > DV_THRESHOLD:
		damage((dv - DV_THRESHOLD) * DV_DAMAGE * fragility)

	# 封印が弱ると中の幽霊が暴れて瓶がガタつく
	if seal < RATTLE_SEAL and not held and _rng.randf() < delta * 0.5:
		sleeping = false
		apply_central_impulse(Vector3(_rng.randf_range(-1, 1), 1.0, _rng.randf_range(-1, 1)) * 1.2)
	_update_visuals()


func damage(amount: float) -> void:
	if _finished or amount <= 0.0:
		return
	seal = maxf(seal - amount, 0.0)
	if seal <= 0.0:
		_finished = true
		escaped.emit(self)
		queue_free()


func sale_value() -> int:
	return int(round(value * (0.5 + 0.5 * seal / 100.0)))


## 搬出口で売却されたときに呼ぶ。二重売却を防ぐため true を返したときだけ有効。
func collect() -> bool:
	if _finished:
		return false
	_finished = true
	queue_free()
	return true


func _update_visuals() -> void:
	var anger := 1.0 - seal / 100.0
	var color := (RARE_COLOR if is_rare else CALM_COLOR).lerp(ANGRY_COLOR, anger)
	_core_material.albedo_color = color
	_light.light_color = color
	var flicker := 1.0 - anger * 0.6 * absf(sin(_time * (4.0 + anger * 20.0)))
	_light.light_energy = 0.8 * flicker
