extends SceneTree
## ヘッドレスで一晩の流れを確認するスモークテスト。
## 実行: godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd

var _main: Node
var _frame := 0
var _failures: Array[String] = []
var _earned_before := 0
var _ghosts_before := 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		10:
			_check(_main.level != null, "フロアが生成されている")
			_check(_count(GhostJar) >= _main.BASE_JAR_COUNT, "霊瓶が %d 個以上ある" % _main.BASE_JAR_COUNT)
			_check(_main.player.is_on_floor(), "プレイヤーが床に立っている")
			var jar: GhostJar = _find(GhostJar)
			jar.global_position = _main.zone.global_position + Vector3(0, 0.5, 0)
		40:
			_check(_main.earned > 0, "搬出口で霊瓶が売れる")
			var min_seal := 100.0
			for node in _main.level.get_children():
				if node is GhostJar:
					min_seal = minf(min_seal, node.seal)
			_check(min_seal > 95.0, "置いてあるだけの霊瓶は封印が減らない")
			_ghosts_before = _count(Ghost)
			_find(GhostJar).damage(1000.0)
		45:
			_check(_count(Ghost) == _ghosts_before + 1, "封印が破れると幽霊が出る")
			_main.earned = _main.quota
			_main.end_night()
		250:
			_check(_main.night == 2, "ノルマ達成で次の夜へ進む")
			_check(_main.state == _main.State.PLAYING, "次の夜がプレイ中になる")
			_check(_count(Ghost) >= 1, "2夜目は徘徊霊がいる")
			_main.player.take_damage(1000.0)
		255:
			_check(_main.state == _main.State.GAME_OVER, "HP 0 でゲームオーバー")
			_main.restart()
		260:
			_check(_main.night == 1 and _main.state == _main.State.PLAYING, "リスタートで夜1に戻る")
			for failure in _failures:
				printerr("FAIL: " + failure)
			print("smoke test: %s" % ("OK" if _failures.is_empty() else "%d failure(s)" % _failures.size()))
			quit(0 if _failures.is_empty() else 1)
	return false


func _check(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + label)
	if not condition:
		_failures.append(label)


func _count(type: Variant) -> int:
	var total := 0
	for node in _main.level.get_children():
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			total += 1
	return total


func _find(type: Variant) -> Node:
	for node in _main.level.get_children():
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			return node
	return null
