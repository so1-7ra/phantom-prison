class_name ExtractionZone
extends Area3D
## 搬出口。霊瓶を運び込むとその場で研究所に売却される。

signal jar_sold(amount: int)

const SIZE := Vector3(4.0, 3.0, 4.0)

var player_inside := false


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = SIZE
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = SIZE.y / 2.0
	add_child(collision)

	var pad_material := StandardMaterial3D.new()
	pad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad_material.albedo_color = Color(0.2, 1.0, 0.5, 0.25)
	var pad := BoxMesh.new()
	pad.size = Vector3(SIZE.x, 0.02, SIZE.z)
	pad.material = pad_material
	var pad_instance := MeshInstance3D.new()
	pad_instance.mesh = pad
	pad_instance.position.y = 0.02
	add_child(pad_instance)

	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.55)
	light.light_energy = 1.0
	light.omni_range = 6.0
	light.position.y = 2.5
	add_child(light)

	var label := Label3D.new()
	label.text = "搬出口"
	label.font = preload("res://fonts/DotGothic16-Regular.ttf")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.5, 1.0, 0.7)
	label.font_size = 96
	label.position.y = 2.8
	add_child(label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is GhostJar:
		var amount: int = body.sale_value()
		if body.collect():
			jar_sold.emit(amount)
	elif body is Player:
		player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_inside = false
