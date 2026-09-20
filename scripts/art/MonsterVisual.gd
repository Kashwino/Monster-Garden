extends Node3D
## Cosmetic motion only. Growth never depends on frame time or animation.
var pulse_speed: float = 1.0
var _motion: Tween

func _ready() -> void:
	_motion = create_tween().set_loops()
	_motion.tween_property(self, "rotation:z", 0.035, 1.7 / pulse_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(self, "rotation:z", -0.035, 1.7 / pulse_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
