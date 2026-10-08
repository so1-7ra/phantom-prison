class_name GameBalance
extends Resource
## 難易度と手触りの調整用パラメータ。
## Godot で data/balance.tres を選ぶと、インスペクタから数値を変えられる。

const PATH := "res://data/balance.tres"

static var _current: GameBalance


## ゲーム中で使う調整値（data/balance.tres）を返す。
static func current() -> GameBalance:
	if _current == null:
		_current = load(PATH)
	return _current


@export_group("夜とノルマ")
## 1 晩の制限時間（秒）
@export var night_duration := 180.0
## 夜 1 のノルマ
@export var base_quota := 300
## 夜ごとのノルマの倍率
@export var quota_growth := 1.35

@export_group("霊瓶")
@export var base_jar_count := 6
@export var jars_per_night := 2
@export_range(0.0, 1.0) var rare_chance := 0.15
@export var common_value_range := Vector2i(60, 120)
@export var rare_value_range := Vector2i(200, 320)
## 夜ごとの霊瓶の価値の上がり幅（0.15 なら 1 晩ごとに +15%）
@export var value_growth_per_night := 0.15
## 1 物理フレームでこれ以上速度が変わると封印にダメージが入る (m/s)
@export var seal_dv_threshold := 1.0
## 閾値を超えた速度変化 1 m/s あたりの封印ダメージ
@export var seal_dv_damage := 8.0
@export var rare_fragility := 1.6

@export_group("幽霊")
@export var max_wanderers := 4
@export var wanderer_chase_speed := 2.6
@export var escaped_chase_speed := 3.2
@export var ghost_aggro_range := 10.0
@export var ghost_damage_per_second := 30.0

@export_group("プレイヤー")
@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var carry_speed_factor := 0.75
@export var max_hp := 100.0
