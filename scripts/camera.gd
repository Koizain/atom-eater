extends Camera2D

func shake(strength: float, duration: float) -> void:
	var tween: Tween = create_tween()
	var steps: int = int(duration / 0.05)
	for i in range(steps):
		var t: float = float(i) / float(steps)
		var s: float = strength * (1.0 - t)
		var off: Vector2 = Vector2(
			randf_range(-s, s),
			randf_range(-s, s)
		)
		tween.tween_property(self, "offset", off, 0.05)
	tween.tween_property(self, "offset", Vector2.ZERO, 0.05)
