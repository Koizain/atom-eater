extends Camera2D

# Smooth follow with slight lag
var target: Node2D = null
const FOLLOW_LERP: float = 8.0

# Zoom composition: final zoom = base_zoom * juice_zoom * punch_zoom
var base_zoom: float = 1.0
var juice_zoom: float = 1.0
var punch_zoom: float = 1.0

# Dynamic speed-reactive zoom
const ZOOM_IDLE: float = 1.025
const ZOOM_FAST: float = 0.96
const SPEED_FOR_ZOOM: float = 300.0
const ZOOM_LERP: float = 2.5

# Shake state
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

func _ready() -> void:
	# Disable built-in smoothing — we handle it manually for more control
	position_smoothing_enabled = false

func _process(delta: float) -> void:
	# Smooth follow with slight lag behind target
	if target:
		global_position = global_position.lerp(target.global_position, FOLLOW_LERP * delta)

	# Speed-reactive zoom: zoom in when idle, zoom out when fast
	if target and "velocity" in target:
		var speed: float = target.velocity.length()
		var t: float = clampf(speed / SPEED_FOR_ZOOM, 0.0, 1.0)
		var target_juice: float = lerpf(ZOOM_IDLE, ZOOM_FAST, t)
		juice_zoom = lerpf(juice_zoom, target_juice, ZOOM_LERP * delta)

	# Compose final zoom from all layers
	var z: float = base_zoom * juice_zoom * punch_zoom
	zoom = Vector2(z, z)

	# Screen shake with quadratic falloff
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var falloff: float = _shake_timer / maxf(_shake_duration, 0.001)
		var s: float = _shake_strength * falloff * falloff
		offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	elif offset.length() > 0.5:
		offset = offset.lerp(Vector2.ZERO, 15.0 * delta)
	else:
		offset = Vector2.ZERO

func shake(strength: float, duration: float) -> void:
	# Only override if incoming shake is stronger than remaining current shake
	var current: float = _shake_strength * (_shake_timer / maxf(_shake_duration, 0.001))
	if strength > current:
		_shake_strength = strength
		_shake_duration = duration
		_shake_timer = duration

func zoom_punch(amount: float) -> void:
	punch_zoom = 1.0 + amount
	var tween: Tween = create_tween()
	tween.tween_property(self, "punch_zoom", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
