extends Node2D

# Draws the player circle with neon glow, squish/stretch deformation,
# settling wobble, and organic idle breathing.

var player_node: Area2D = null
var pulse_time: float = 0.0

# Spring-driven squish/stretch
var _stretch_velocity: float = 0.0
var _display_stretch: float = 0.0
const STRETCH_SPRING: float = 200.0
const STRETCH_DAMP: float = 14.0
const MAX_STRETCH: float = 0.3      # 1.3x along movement
const MAX_COMPRESS: float = 0.2     # 0.8x perpendicular
const SPEED_FOR_FULL_STRETCH: float = 300.0

# Smooth movement angle (avoids snapping)
var _move_angle: float = 0.0

func _process(delta: float) -> void:
	pulse_time += delta

	# Drive spring toward speed-based target stretch
	var target_stretch: float = 0.0
	if player_node and "velocity" in player_node:
		var vel: Vector2 = player_node.velocity
		var speed: float = vel.length()
		target_stretch = clampf(speed / SPEED_FOR_FULL_STRETCH, 0.0, 1.0) * MAX_STRETCH

		# Smooth angle tracking — only update when moving
		if speed > 10.0:
			_move_angle = lerp_angle(_move_angle, vel.angle(), 8.0 * delta)

	# Damped spring: overshoots when decelerating → settling wobble
	var spring_force: float = (target_stretch - _display_stretch) * STRETCH_SPRING - _stretch_velocity * STRETCH_DAMP
	_stretch_velocity += spring_force * delta
	_display_stretch += _stretch_velocity * delta

	queue_redraw()

func _draw() -> void:
	if not player_node:
		player_node = get_parent() as Area2D

	var radius: float = 16.0
	if player_node and player_node.has_method("get_player_radius"):
		radius = player_node.get_player_radius()

	# Organic idle breathing — two incommensurate frequencies
	var breath: float = 1.0 + 0.012 * sin(pulse_time * 1.8) + 0.007 * sin(pulse_time * 3.7 + 0.5)
	radius *= breath

	var scale_color: Color = GameData.get_scale_color()

	# Compute deformation axes
	var stretch_x: float = 1.0 + _display_stretch
	var stretch_y: float = 1.0 - _display_stretch * (MAX_COMPRESS / MAX_STRETCH)

	# Apply squish/stretch transform aligned to movement direction
	draw_set_transform(Vector2.ZERO, _move_angle, Vector2(stretch_x, stretch_y))

	# Outer glow layers (neon glow effect)
	draw_circle(Vector2.ZERO, radius * 2.0, Color(scale_color.r, scale_color.g, scale_color.b, 0.03))
	draw_circle(Vector2.ZERO, radius * 1.7, Color(scale_color.r, scale_color.g, scale_color.b, 0.06))
	draw_circle(Vector2.ZERO, radius * 1.45, Color(scale_color.r, scale_color.g, scale_color.b, 0.12))
	draw_circle(Vector2.ZERO, radius * 1.2, Color(scale_color.r, scale_color.g, scale_color.b, 0.22))

	# Core bright circle
	draw_circle(Vector2.ZERO, radius, Color(scale_color.r * 0.8 + 0.2, scale_color.g * 0.8 + 0.2, scale_color.b * 0.8 + 0.2, 0.95))

	# Inner highlight
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 1.0, 1.0, 0.7))

	# Bright center dot
	draw_circle(Vector2.ZERO, radius * 0.2, Color(1.0, 1.0, 1.0, 0.9))

	# Reset transform — indicators stay perfectly circular
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Absorption radius indicator (faint ring)
	var abs_radius: float = radius * 1.2
	if player_node and player_node.has_method("get_absorption_radius"):
		abs_radius = player_node.get_absorption_radius()
	draw_arc(Vector2.ZERO, abs_radius, 0.0, TAU, 48, Color(scale_color.r, scale_color.g, scale_color.b, 0.1), 1.5)

	# HP indicator rings
	if GameData.player_hp < GameData.MAX_HP:
		var hp_color: Color = Color(1.0, 0.2, 0.2, 0.3 + 0.2 * sin(pulse_time * 4.0))
		draw_arc(Vector2.ZERO, radius * 1.1, 0.0, TAU, 36, hp_color, 2.0)
