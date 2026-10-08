class_name LevelGenerator
extends RefCounted
## 刑務所フロアをランダム生成する。
## グリッド状の監房ブロックを迷路として掘り、ところどころに抜け道（ループ）を足す。

const CELL_SIZE := 8.0
const WALL_HEIGHT := 3.6
const WALL_THICKNESS := 0.4
const DOOR_WIDTH := 2.4
const EXTRA_OPENING_CHANCE := 0.15
const LIGHT_CHANCE := 0.35
const GHOST_MIN_DISTANCE := 4
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var width: int
var height: int

var _rng: RandomNumberGenerator
var _open_edges := {}
var _wall_material := StandardMaterial3D.new()
var _floor_material := StandardMaterial3D.new()


func _init(rng: RandomNumberGenerator, grid_width := 5, grid_height := 5) -> void:
	_rng = rng
	width = grid_width
	height = grid_height
	_wall_material.albedo_color = Color(0.32, 0.34, 0.33)
	_wall_material.roughness = 0.95
	_floor_material.albedo_color = Color(0.18, 0.17, 0.16)
	_floor_material.roughness = 1.0


## 親ノードの下にフロアを組み立て、出現位置などの情報を返す。
func build(parent: Node3D) -> Dictionary:
	_carve_maze()
	_build_floor_and_ceiling(parent)
	_build_walls(parent)
	_build_lights(parent)
	return {
		"start": cell_center(Vector2i.ZERO),
		"jar_spots": _jar_spots(),
		"ghost_spots": _ghost_spots(),
	}


func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func _edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return Vector4i(a.x, a.y, b.x, b.y)
	return Vector4i(b.x, b.y, a.x, a.y)


func _is_open(a: Vector2i, b: Vector2i) -> bool:
	return _open_edges.has(_edge_key(a, b))


func _carve_maze() -> void:
	_open_edges.clear()
	var visited := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for dir in DIRECTIONS:
			var next := current + dir
			if _in_bounds(next) and not visited.has(next):
				options.append(next)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen := options[_rng.randi_range(0, options.size() - 1)]
		_open_edges[_edge_key(current, chosen)] = true
		visited[chosen] = true
		stack.push_back(chosen)

	# 一本道だけだと逃げ場がないので、ランダムに抜け道を追加する
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var next := cell + dir
				if _in_bounds(next) and _rng.randf() < EXTRA_OPENING_CHANCE:
					_open_edges[_edge_key(cell, next)] = true


func _build_floor_and_ceiling(parent: Node3D) -> void:
	var size := Vector3(width * CELL_SIZE, 0.2, height * CELL_SIZE)
	var center := Vector3((width - 1) * CELL_SIZE / 2.0, 0.0, (height - 1) * CELL_SIZE / 2.0)
	_add_box(parent, size, center + Vector3(0, -0.1, 0), _floor_material)
	_add_box(parent, size, center + Vector3(0, WALL_HEIGHT + 0.1, 0), _wall_material)


func _build_walls(parent: Node3D) -> void:
	var half := CELL_SIZE / 2.0
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			var center := cell_center(cell)
			_build_edge(parent, center + Vector3(half, 0, 0), true, _is_open(cell, cell + Vector2i.RIGHT))
			_build_edge(parent, center + Vector3(0, 0, half), false, _is_open(cell, cell + Vector2i.DOWN))
			if x == 0:
				_build_edge(parent, center - Vector3(half, 0, 0), true, false)
			if y == 0:
				_build_edge(parent, center - Vector3(0, 0, half), false, false)


## 2つの監房の境目に壁を立てる。通れる場合は中央に戸口を空ける。
func _build_edge(parent: Node3D, mid: Vector3, along_z: bool, open: bool) -> void:
	if not open:
		_add_wall(parent, mid, CELL_SIZE + WALL_THICKNESS, along_z)
		return
	var inner := DOOR_WIDTH / 2.0
	var outer := CELL_SIZE / 2.0 + WALL_THICKNESS / 2.0
	var axis := Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	var offset := (inner + outer) / 2.0
	_add_wall(parent, mid + axis * offset, outer - inner, along_z)
	_add_wall(parent, mid - axis * offset, outer - inner, along_z)


func _add_wall(parent: Node3D, mid: Vector3, length: float, along_z: bool) -> void:
	var size := Vector3(WALL_THICKNESS, WALL_HEIGHT, length) if along_z else Vector3(length, WALL_HEIGHT, WALL_THICKNESS)
	_add_box(parent, size, mid + Vector3(0, WALL_HEIGHT / 2.0, 0), _wall_material)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _build_lights(parent: Node3D) -> void:
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			if cell == Vector2i.ZERO or _rng.randf() > LIGHT_CHANCE:
				continue
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.78, 0.55)
			light.light_energy = 0.7
			light.omni_range = 6.0
			light.position = cell_center(cell) + Vector3(0, WALL_HEIGHT - 0.4, 0)
			parent.add_child(light)


func _jar_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var margin := CELL_SIZE / 2.0 - 1.2
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			if cell == Vector2i.ZERO:
				continue
			for i in _rng.randi_range(1, 2):
				var jitter := Vector3(_rng.randf_range(-margin, margin), 0, _rng.randf_range(-margin, margin))
				spots.append(cell_center(cell) + jitter)
	_shuffle(spots)
	return spots


func _ghost_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for x in width:
		for y in height:
			if x + y >= GHOST_MIN_DISTANCE:
				spots.append(cell_center(Vector2i(x, y)) + Vector3(0, 1.4, 0))
	_shuffle(spots)
	return spots


## Array.shuffle() はグローバル乱数を使うので、シード再現のため自前で混ぜる。
func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
