extends Node2D

# Draws an entity circle with neon glow

var entity_node: Area2D = null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not entity_node:
		entity_node = get_parent() as Area2D

	if not entity_node:
		return

	var data: Dictionary = {}
	if entity_node.has_method("get_entity_data"):
		data = entity_node.get_entity_data()

	var radius: float = data.get("radius", 10.0)
	var color: Color = data.get("color", Color(0.2, 0.9, 0.3))
	var is_toxic: bool = data.get("is_toxic", false)

	if is_toxic:
		# Pulsing toxic effect with dashed ring
		var t: float = Time.get_ticks_msec() / 1000.0
		var pulse: float = 0.7 + 0.3 * sin(t * 4.0)
		draw_circle(Vector2.ZERO, radius * 1.5, Color(0.5, 0.0, 0.7, 0.07 * pulse))
		draw_circle(Vector2.ZERO, radius * 1.25, Color(0.5, 0.0, 0.8, 0.14 * pulse))
		draw_circle(Vector2.ZERO, radius, Color(0.45, 0.0, 0.75, 0.85))
		draw_circle(Vector2.ZERO, radius * 0.5, Color(0.7, 0.0, 1.0, 0.9))
		# Toxic symbol - X shape
		var x_size: float = radius * 0.35
		draw_line(Vector2(-x_size, -x_size), Vector2(x_size, x_size), Color(1.0, 0.5, 1.0, 0.9), 2.0)
		draw_line(Vector2(x_size, -x_size), Vector2(-x_size, x_size), Color(1.0, 0.5, 1.0, 0.9), 2.0)
	else:
		# Normal entity — glow layers
		draw_circle(Vector2.ZERO, radius * 1.6, Color(color.r, color.g, color.b, 0.05))
		draw_circle(Vector2.ZERO, radius * 1.3, Color(color.r, color.g, color.b, 0.12))
		draw_circle(Vector2.ZERO, radius * 1.1, Color(color.r, color.g, color.b, 0.22))
		# Core
		draw_circle(Vector2.ZERO, radius, Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.9))
		# Bright center
		draw_circle(Vector2.ZERO, radius * 0.45, color)
		# Specular
		draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.15, Color(1.0, 1.0, 1.0, 0.4))
