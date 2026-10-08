extends SceneTree
## ヘッドレスでタイトルから一晩の流れまでを確認するスモークテスト。
## 実行: godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd

const SOUNDS: Array[StringName] = [
	&"footstep", &"clink", &"jar_hum", &"ghost_wail", &"ambient",
	&"sell", &"night_clear", &"escape", &"game_over", &"ui_click",
]

var _main: Node
var _frame := 0
var _failures: Array[String] = []
var _ghosts_before := 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	# 本物の最高記録を上書きしないよう、テスト用の保存先を使う
	_main.save_path = "user://test_save.cfg"
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		5:
			_check(_main.state == _main.State.TITLE, "タイトル画面から始まる")
			_check(_main.menu.is_open(), "タイトルメニューが表示されている")
			for sound in SOUNDS:
				_check(Sfx.get_stream(sound).data.size() > 0, "効果音 %s が合成できる" % sound)
			_main.start_game()
		15:
			var balance := GameBalance.current()
			_check(not _main.menu.is_open(), "ゲーム開始でメニューが閉じる")
			_check(_count(GhostJar) >= balance.base_jar_count, "霊瓶が %d 個以上ある" % balance.base_jar_count)
			_check(_main.player.is_on_floor(), "プレイヤーが床に立っている")
			_find(GhostJar).global_position = _main.zone.global_position + Vector3(0, 0.5, 0)
		45:
			_check(_main.earned > 0, "搬出口で霊瓶が売れる")
			var min_seal := 100.0
			for node in _main.level.get_children():
				if node is GhostJar:
					min_seal = minf(min_seal, node.seal)
			_check(min_seal > 95.0, "置いてあるだけの霊瓶は封印が減らない")
			_ghosts_before = _count(Ghost)
			_find(GhostJar).damage(1000.0)
		50:
			_check(_count(Ghost) == _ghosts_before + 1, "封印が破れると幽霊が出る")
			_main.set_paused(true)
		51:
			_check(paused and _main.menu.is_open(), "一時停止でメニューが開く")
			_main.set_paused(false)
			_check(not paused and not _main.menu.is_open(), "再開でメニューが閉じる")
			_main.earned = _main.quota
			_main.end_night()
		260:
			_check(_main.night == 2, "ノルマ達成で次の夜へ進む")
			_check(_main.state == _main.State.PLAYING, "次の夜がプレイ中になる")
			_check(_count(Ghost) >= 1, "2 夜目は徘徊霊がいる")
			_main.player.take_damage(1000.0)
		265:
			_check(_main.state == _main.State.GAME_OVER, "HP 0 でゲームオーバー")
			_check(_main.menu.is_open(), "ゲームオーバー画面が出る")
			_main.start_game()
		270:
			_check(_main.night == 1 and _main.state == _main.State.PLAYING, "もう一度で夜 1 に戻る")
			_main.show_title()
		275:
			_check(_main.state == _main.State.TITLE and _main.player == null, "タイトルへ戻れる")
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
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
