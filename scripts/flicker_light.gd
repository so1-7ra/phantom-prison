class_name FlickerLight
extends OmniLight3D
## 切れかけの蛍光灯。ときどき不規則に明滅する。

var base_energy := 0.7

var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	base_energy = light_energy


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if _rng.randf() < 0.15:
		light_energy = base_energy * _rng.randf_range(0.0, 0.3)
		_timer = _rng.randf_range(0.03, 0.12)
	else:
		light_energy = base_energy
		_timer = _rng.randf_range(0.1, 1.5)
