extends Node2D

# Draws the player circle with neon glow effect and pulse

var player_node: Area2D = null
var pulse_time: float = 0.0

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	if not player_node:
		player_node = get_parent() as Area2D

	var radius: float = 16.0
	if player_node and player_node.has_method("get_player_radius"):
		radius = player_node.get_player_radius()

	# Slow pulse: scale between 0.95 and 1.05 over 2s period
	var pulse: float = 1.0 + 0.05 * sin(pulse_time * PI)  # period = 2s
	radius *= pulse

	var scale_color: Color = GameData.get_scale_color()

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

	# Absorption radius indicator (faint ring)
	var abs_radius: float = radius * 1.2
	if player_node and player_node.has_method("get_absorption_radius"):
		abs_radius = player_node.get_absorption_radius()
	draw_arc(Vector2.ZERO, abs_radius, 0.0, TAU, 48, Color(scale_color.r, scale_color.g, scale_color.b, 0.1), 1.5)

	# HP indicator rings
	if GameData.player_hp < GameData.MAX_HP:
		var hp_color: Color = Color(1.0, 0.2, 0.2, 0.3 + 0.2 * sin(pulse_time * 4.0))
		draw_arc(Vector2.ZERO, radius * 1.1, 0.0, TAU, 36, hp_color, 2.0)
