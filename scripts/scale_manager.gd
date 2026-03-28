extends Node

signal transition_started(new_scale: int)
signal transition_finished(new_scale: int)

@export var camera: Camera2D
@export var entity_spawner: Node

var is_transitioning: bool = false
var invincibility_timer: float = 0.0
var INVINCIBILITY_DURATION: float = 2.5

func _process(delta: float) -> void:
	if invincibility_timer > 0.0:
		invincibility_timer -= delta

func is_player_invincible() -> bool:
	return invincibility_timer > 0.0

func check_scale_transition(player_mass: float) -> void:
	if is_transitioning:
		return
	var threshold: float = GameData.get_scale_threshold()
	if player_mass >= threshold and GameData.current_scale < 2:
		start_transition()

func start_transition() -> void:
	is_transitioning = true
	var new_scale: int = GameData.current_scale + 1
	transition_started.emit(new_scale)
	_do_zoom_out(new_scale)

func _do_zoom_out(new_scale: int) -> void:
	# Animate camera zoom out, then transition
	if camera:
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(camera, "zoom", Vector2(0.4, 0.4), 0.6)
		tween.tween_interval(0.3)
		tween.tween_callback(_apply_scale_change.bind(new_scale))
		tween.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.5)
		tween.tween_callback(_finish_transition.bind(new_scale))
	else:
		_apply_scale_change(new_scale)
		_finish_transition(new_scale)

func _apply_scale_change(new_scale: int) -> void:
	GameData.current_scale = new_scale
	# Reset player mass to a relative starting point for new scale
	GameData.player_mass = GameData.SCALE_THRESHOLDS[new_scale - 1] * 0.15
	# Refresh spawner with new scale settings
	if entity_spawner and entity_spawner.has_method("refresh_for_scale"):
		entity_spawner.refresh_for_scale(new_scale)
	GameData.scale_changed.emit(new_scale)

func _finish_transition(new_scale: int) -> void:
	invincibility_timer = INVINCIBILITY_DURATION
	is_transitioning = false
	transition_finished.emit(new_scale)
