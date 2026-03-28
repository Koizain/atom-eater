extends Node2D

# Draws the player circle with neon glow effect

var player_node: Area2D = null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not player_node:
		# Try to find player in parent
		player_node = get_parent() as Area2D

	var radius: float = 16.0
	if player_node and player_node.has_method("get_player_radius"):
		radius = player_node.get_player_radius()

	var scale_color: Color = GameData.get_scale_color()

	# Outer glow layers (additive blending via modulate alpha)
	draw_circle(Vector2.ZERO, radius * 1.8, Color(scale_color.r, scale_color.g, scale_color.b, 0.06))
	draw_circle(Vector2.ZERO, radius * 1.5, Color(scale_color.r, scale_color.g, scale_color.b, 0.12))
	draw_circle(Vector2.ZERO, radius * 1.25, Color(scale_color.r, scale_color.g, scale_color.b, 0.2))

	# Core white circle
	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.95, 1.0, 0.95))

	# Inner bright highlight
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 1.0, 1.0, 0.85))

	# Absorption radius indicator (very faint)
	var abs_radius: float = radius * 1.2
	if player_node and player_node.has_method("get_absorption_radius"):
		abs_radius = player_node.get_absorption_radius()
	draw_arc(Vector2.ZERO, abs_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.08), 1.0)
