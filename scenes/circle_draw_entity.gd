extends Node2D

# Draws an entity circle with neon glow

var entity_node: Area2D = null
var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
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

	# Subtle bob animation
	var bob: float = 1.0 + 0.03 * sin(time * 2.5 + entity_node.get_instance_id() * 0.1)
	radius *= bob

	if is_toxic:
		# Pulsing toxic effect
		var pulse: float = 0.7 + 0.3 * sin(time * 4.0)
		draw_circle(Vector2.ZERO, radius * 1.6, Color(0.5, 0.0, 0.7, 0.05 * pulse))
		draw_circle(Vector2.ZERO, radius * 1.3, Color(0.5, 0.0, 0.8, 0.12 * pulse))
		draw_circle(Vector2.ZERO, radius, Color(0.45, 0.0, 0.75, 0.85))
		draw_circle(Vector2.ZERO, radius * 0.5, Color(0.7, 0.0, 1.0, 0.9))
		# Toxic X symbol
		var x_size: float = radius * 0.35
		draw_line(Vector2(-x_size, -x_size), Vector2(x_size, x_size), Color(1.0, 0.5, 1.0, 0.9), 2.0)
		draw_line(Vector2(x_size, -x_size), Vector2(-x_size, x_size), Color(1.0, 0.5, 1.0, 0.9), 2.0)
	else:
		# Neon glow layers
		draw_circle(Vector2.ZERO, radius * 1.8, Color(color.r, color.g, color.b, 0.03))
		draw_circle(Vector2.ZERO, radius * 1.5, Color(color.r, color.g, color.b, 0.07))
		draw_circle(Vector2.ZERO, radius * 1.25, Color(color.r, color.g, color.b, 0.14))
		draw_circle(Vector2.ZERO, radius * 1.1, Color(color.r, color.g, color.b, 0.22))
		# Core
		draw_circle(Vector2.ZERO, radius, Color(color.r * 0.5 + 0.1, color.g * 0.5 + 0.1, color.b * 0.5 + 0.1, 0.9))
		# Bright center
		draw_circle(Vector2.ZERO, radius * 0.5, color)
		# Specular highlight
		draw_circle(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.15, Color(1.0, 1.0, 1.0, 0.35))

		# Entity type visual hints
		if entity_node.has_method("get_entity_data") and "entity_type" in entity_node:
			var etype = entity_node.entity_type
			if etype == 1:  # ORBITER - small orbit ring
				draw_arc(Vector2.ZERO, radius * 1.3, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.15), 1.0)
			elif etype == 2:  # CHASER - chevron marks
				var sz: float = radius * 0.3
				draw_line(Vector2(-sz, -sz * 0.5), Vector2(0, -sz), Color(1.0, 0.3, 0.3, 0.5), 1.5)
				draw_line(Vector2(0, -sz), Vector2(sz, -sz * 0.5), Color(1.0, 0.3, 0.3, 0.5), 1.5)
