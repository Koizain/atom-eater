extends Node2D

# Draws an entity circle with distinct visuals per type:
# - Wanderer: round with soft pulse
# - Orbiter: ring-shaped (hollow circle with thin ring)
# - Chaser: angular with 'eyes' (two bright spots)
# - Absorber: large gravity well with swirling rings
# - Splitter: diamond-shaped with split-line markings
# Plus: sparkle trails, tremble when near player, neon glow

var entity_node: Area2D = null
var time: float = 0.0

# Sparkle emission
var sparkle_timer: float = 0.0
const SPARKLE_INTERVAL: float = 0.08

# Tremble state
var tremble_offset: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	time += delta

	if not entity_node:
		entity_node = get_parent() as Area2D
	if not entity_node:
		return

	# Sparkle trail emission
	sparkle_timer -= delta
	if sparkle_timer <= 0.0 and entity_node.visible:
		sparkle_timer = SPARKLE_INTERVAL
		_emit_sparkle()

	# Tremble when player is nearby (about to be absorbed)
	_update_tremble()

	queue_redraw()

func _emit_sparkle() -> void:
	if not entity_node or not entity_node.is_active:
		return
	var main_node: Node = entity_node.get_parent()
	if main_node == null:
		main_node = entity_node.get_parent()
	# Walk up to find main scene with add_sparkle method
	var root: Node = main_node
	var _iter1: int = 0
	while root and not root.has_method("add_sparkle") and _iter1 < 20:
		root = root.get_parent()
		_iter1 += 1
	if root and root.has_method("add_sparkle"):
		var data: Dictionary = entity_node.get_entity_data() if entity_node.has_method("get_entity_data") else {}
		var color: Color = data.get("color", Color.WHITE)
		root.add_sparkle(entity_node.global_position, color)

func _update_tremble() -> void:
	if not entity_node:
		tremble_offset = Vector2.ZERO
		return

	# Find player distance
	var player: Node2D = null
	var tree: SceneTree = entity_node.get_tree()
	if tree:
		var players = tree.get_nodes_in_group("player") if tree.has_method("get_nodes_in_group") else []
		if players.is_empty():
			# Try to find player by traversal
			var main_node: Node = entity_node.get_parent()
			var _iter2: int = 0
			while main_node and not main_node.has_method("shake_camera") and _iter2 < 20:
				main_node = main_node.get_parent()
				_iter2 += 1
			if main_node:
				var p = main_node.get_node_or_null("Player")
				if p:
					player = p

	if not player or not is_instance_valid(player):
		tremble_offset = Vector2.ZERO
		return

	var dist: float = entity_node.global_position.distance_to(player.global_position)
	var player_radius: float = 16.0
	if player.has_method("get_absorption_radius"):
		player_radius = player.get_absorption_radius()

	# Tremble when within 1.5x absorption radius
	if dist < player_radius * 1.5 and dist > 0.0:
		var intensity: float = (1.0 - dist / (player_radius * 1.5)) * 2.5
		tremble_offset = Vector2(
			sin(time * 45.0) * intensity,
			cos(time * 52.0 + 1.3) * intensity
		)
	else:
		tremble_offset = tremble_offset.lerp(Vector2.ZERO, 0.2)

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

	# Phase-offset bob
	var phase: float = float(entity_node.get_instance_id()) * 0.1
	var bob: float = 1.0 + 0.03 * sin(time * 2.5 + phase)
	radius *= bob

	# Apply tremble offset
	var center: Vector2 = tremble_offset

	if is_toxic:
		_draw_toxic(center, radius, color)
	else:
		var etype: int = data.get("entity_type", 0)
		match etype:
			0:  # WANDERER
				_draw_wanderer(center, radius, color, phase)
			1:  # ORBITER
				_draw_orbiter(center, radius, color, phase)
			2:  # CHASER
				_draw_chaser(center, radius, color, phase)
			3:  # ABSORBER
				_draw_absorber(center, radius, color, phase)
			4:  # SPLITTER
				_draw_splitter(center, radius, color, phase)
			_:
				_draw_wanderer(center, radius, color, phase)

func _draw_toxic(center: Vector2, radius: float, _color: Color) -> void:
	var pulse: float = 0.7 + 0.3 * sin(time * 4.0)
	# Toxic outer glow
	draw_circle(center, radius * 1.8, Color(0.5, 0.0, 0.7, 0.04 * pulse))
	draw_circle(center, radius * 1.5, Color(0.5, 0.0, 0.8, 0.08 * pulse))
	draw_circle(center, radius * 1.3, Color(0.5, 0.0, 0.8, 0.14 * pulse))
	draw_circle(center, radius, Color(0.45, 0.0, 0.75, 0.85))
	draw_circle(center, radius * 0.5, Color(0.7, 0.0, 1.0, 0.9))
	# Toxic X symbol
	var x_size: float = radius * 0.35
	draw_line(center + Vector2(-x_size, -x_size), center + Vector2(x_size, x_size), Color(1.0, 0.5, 1.0, 0.9), 2.0)
	draw_line(center + Vector2(x_size, -x_size), center + Vector2(-x_size, x_size), Color(1.0, 0.5, 1.0, 0.9), 2.0)

func _draw_wanderer(center: Vector2, radius: float, color: Color, phase: float) -> void:
	# Wanderer: Round with soft pulse — organic, gentle
	var soft_pulse: float = 1.0 + 0.06 * sin(time * 3.0 + phase)
	var r: float = radius * soft_pulse

	# Wide soft outer glow
	draw_circle(center, r * 2.0, Color(color.r, color.g, color.b, 0.025))
	draw_circle(center, r * 1.6, Color(color.r, color.g, color.b, 0.06))
	draw_circle(center, r * 1.3, Color(color.r, color.g, color.b, 0.12))
	# Main body
	draw_circle(center, r * 1.1, Color(color.r, color.g, color.b, 0.22))
	draw_circle(center, r, Color(color.r * 0.5 + 0.15, color.g * 0.5 + 0.15, color.b * 0.5 + 0.15, 0.9))
	# Bright center
	draw_circle(center, r * 0.5, color)
	# White specular
	draw_circle(center + Vector2(-r * 0.2, -r * 0.2), r * 0.15, Color(1.0, 1.0, 1.0, 0.4))

func _draw_orbiter(center: Vector2, radius: float, color: Color, phase: float) -> void:
	# Orbiter: Ring-shaped — hollow circle with rotating ring
	var ring_pulse: float = 1.0 + 0.04 * sin(time * 2.0 + phase)
	var r: float = radius * ring_pulse

	# Outer glow
	draw_circle(center, r * 1.8, Color(color.r, color.g, color.b, 0.03))
	draw_circle(center, r * 1.4, Color(color.r, color.g, color.b, 0.07))

	# Main ring (thick arc = full circle)
	var ring_width: float = maxf(r * 0.3, 1.5)
	draw_arc(center, r, 0.0, TAU, 48, Color(color.r * 0.6 + 0.15, color.g * 0.6 + 0.15, color.b * 0.6 + 0.15, 0.85), ring_width)
	# Inner bright ring
	draw_arc(center, r * 0.7, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.35), maxf(ring_width * 0.4, 1.0))
	# Outer bright ring
	draw_arc(center, r * 1.15, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.2), maxf(ring_width * 0.3, 1.0))

	# Faint orbit trail — draw arc behind the orbiter
	if entity_node and "orbit_angle" in entity_node:
		var trail_start: float = entity_node.orbit_angle - PI * 0.6
		var trail_end: float = entity_node.orbit_angle
		draw_arc(center, r * 0.9, trail_start, trail_end, 16, Color(color.r, color.g, color.b, 0.12), maxf(ring_width * 0.2, 1.0))

	# Rotating bright dot on the ring
	var dot_angle: float = time * 2.5 + phase
	var dot_pos: Vector2 = center + Vector2(cos(dot_angle), sin(dot_angle)) * r
	draw_circle(dot_pos, maxf(r * 0.12, 1.5), Color(1.0, 1.0, 1.0, 0.7))
	draw_circle(dot_pos, maxf(r * 0.2, 2.0), Color(color.r, color.g, color.b, 0.3))

	# Small core dot
	draw_circle(center, r * 0.15, Color(color.r, color.g, color.b, 0.5))

func _draw_chaser(center: Vector2, radius: float, color: Color, phase: float) -> void:
	# Chaser: Angular/aggressive — circle with 'eyes' (two bright spots)
	var aggro_pulse: float = 1.0 + 0.08 * sin(time * 5.0 + phase)
	var r: float = radius * aggro_pulse

	# Check if fleeing
	var is_fleeing: bool = false
	if entity_node and "is_fleeing" in entity_node:
		is_fleeing = entity_node.is_fleeing

	# Aggressive glow (slightly reddish tint, or blue when fleeing)
	var glow_color: Color
	if is_fleeing:
		glow_color = Color(color.r * 0.6, color.g * 0.6, minf(color.b + 0.3, 1.0))
	else:
		glow_color = Color(minf(color.r + 0.15, 1.0), color.g * 0.8, color.b * 0.8)
	draw_circle(center, r * 1.8, Color(glow_color.r, glow_color.g, glow_color.b, 0.035))
	draw_circle(center, r * 1.4, Color(glow_color.r, glow_color.g, glow_color.b, 0.08))

	# Body with slight angular feel (draw slightly flattened)
	draw_circle(center, r * 1.1, Color(color.r, color.g, color.b, 0.2))
	draw_circle(center, r, Color(color.r * 0.4 + 0.1, color.g * 0.4 + 0.1, color.b * 0.4 + 0.1, 0.9))

	# Two 'eyes' — bright spots that look toward movement direction
	var eye_dir: Vector2 = Vector2.RIGHT
	if "drift_velocity" in entity_node and entity_node.drift_velocity.length() > 1.0:
		eye_dir = entity_node.drift_velocity.normalized()
	var eye_perp: Vector2 = Vector2(-eye_dir.y, eye_dir.x)

	var eye_offset: float = r * 0.3
	var eye_forward: float = r * 0.25
	var eye_size: float = maxf(r * 0.18, 1.5)
	var eye1: Vector2 = center + eye_dir * eye_forward + eye_perp * eye_offset
	var eye2: Vector2 = center + eye_dir * eye_forward - eye_perp * eye_offset

	var eye_color: Color = Color(1.0, 0.3, 0.2, 0.3) if not is_fleeing else Color(0.3, 0.3, 1.0, 0.3)
	var eye_core_color: Color = Color(1.0, 0.5, 0.3, 0.9) if not is_fleeing else Color(0.4, 0.4, 1.0, 0.9)

	# Eye glow
	draw_circle(eye1, eye_size * 2.0, eye_color)
	draw_circle(eye2, eye_size * 2.0, eye_color)
	# Eye cores
	draw_circle(eye1, eye_size, eye_core_color)
	draw_circle(eye2, eye_size, eye_core_color)
	# Eye pupils (bright white)
	draw_circle(eye1, eye_size * 0.5, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(eye2, eye_size * 0.5, Color(1.0, 1.0, 1.0, 0.9))

	# Angry chevron marks above (or worried marks when fleeing)
	var chev_y: float = -r * 0.55
	var chev_w: float = r * 0.25
	if is_fleeing:
		# Worried eyebrows (curved down)
		draw_line(center + Vector2(-chev_w, chev_y - r * 0.1), center + Vector2(0, chev_y), Color(0.4, 0.4, 1.0, 0.6), maxf(1.5, r * 0.05))
		draw_line(center + Vector2(0, chev_y), center + Vector2(chev_w, chev_y - r * 0.1), Color(0.4, 0.4, 1.0, 0.6), maxf(1.5, r * 0.05))
	else:
		draw_line(center + Vector2(-chev_w, chev_y), center + Vector2(0, chev_y - r * 0.15), Color(1.0, 0.4, 0.3, 0.6), maxf(1.5, r * 0.05))
		draw_line(center + Vector2(0, chev_y - r * 0.15), center + Vector2(chev_w, chev_y), Color(1.0, 0.4, 0.3, 0.6), maxf(1.5, r * 0.05))

func _draw_absorber(center: Vector2, radius: float, color: Color, phase: float) -> void:
	# Absorber: Large gravity well — dark core with swirling gravitational rings
	var pulse: float = 1.0 + 0.04 * sin(time * 1.5 + phase)
	var r: float = radius * pulse

	# Wide gravity well visual (pull zone indicator)
	var pull_r: float = r * 6.0
	var pull_alpha: float = 0.015 + 0.01 * sin(time * 2.0)
	draw_circle(center, pull_r, Color(color.r, color.g, color.b, pull_alpha * 0.3))
	draw_circle(center, pull_r * 0.7, Color(color.r, color.g, color.b, pull_alpha * 0.5))
	draw_circle(center, pull_r * 0.4, Color(color.r, color.g, color.b, pull_alpha * 0.8))

	# Swirling gravitational rings
	for i in range(3):
		var ring_r: float = r * (1.5 + float(i) * 0.8)
		var ring_angle_offset: float = time * (0.8 + float(i) * 0.3) * (1.0 if i % 2 == 0 else -1.0)
		var ring_alpha: float = 0.15 - float(i) * 0.04
		var arc_length: float = PI * 0.8
		draw_arc(center, ring_r, ring_angle_offset, ring_angle_offset + arc_length, 24,
			Color(color.r, color.g, color.b, ring_alpha), maxf(2.0, r * 0.06))

	# Dark menacing core
	draw_circle(center, r * 1.4, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.3))
	draw_circle(center, r * 1.1, Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.6))
	draw_circle(center, r, Color(color.r * 0.15 + 0.05, color.g * 0.15 + 0.05, color.b * 0.15 + 0.05, 0.9))

	# Inner bright singularity
	var sing_pulse: float = 0.6 + 0.4 * sin(time * 3.0 + phase)
	draw_circle(center, r * 0.35, Color(color.r, color.g, color.b, 0.7 * sing_pulse))
	draw_circle(center, r * 0.15, Color(1.0, 1.0, 1.0, 0.5 * sing_pulse))

func _draw_splitter(center: Vector2, radius: float, color: Color, phase: float) -> void:
	# Splitter: Geometric with visible split-line — shows it will break apart
	var pulse: float = 1.0 + 0.05 * sin(time * 3.5 + phase)
	var r: float = radius * pulse

	# Outer glow
	draw_circle(center, r * 1.8, Color(color.r, color.g, color.b, 0.03))
	draw_circle(center, r * 1.4, Color(color.r, color.g, color.b, 0.08))

	# Main body
	draw_circle(center, r * 1.1, Color(color.r, color.g, color.b, 0.2))
	draw_circle(center, r, Color(color.r * 0.5 + 0.15, color.g * 0.5 + 0.15, color.b * 0.5 + 0.15, 0.9))

	# Split line through center (rotating slowly)
	var split_angle: float = time * 0.8 + phase
	var split_dir: Vector2 = Vector2(cos(split_angle), sin(split_angle))
	var line_start: Vector2 = center - split_dir * r * 1.1
	var line_end: Vector2 = center + split_dir * r * 1.1
	var split_glow: float = 0.5 + 0.3 * sin(time * 4.0)
	draw_line(line_start, line_end, Color(1.0, 1.0, 1.0, 0.4 * split_glow), maxf(1.5, r * 0.06))

	# Two bright dots on either side of the split (showing the two halves)
	var half_offset: float = r * 0.35
	var perp: Vector2 = Vector2(-split_dir.y, split_dir.x)
	draw_circle(center + perp * half_offset, r * 0.25, Color(color.r, color.g, color.b, 0.8))
	draw_circle(center - perp * half_offset, r * 0.25, Color(color.r, color.g, color.b, 0.8))
	draw_circle(center + perp * half_offset, r * 0.12, Color(1.0, 1.0, 1.0, 0.6))
	draw_circle(center - perp * half_offset, r * 0.12, Color(1.0, 1.0, 1.0, 0.6))

	# Generation indicator: small dots showing how many splits remain
	var generation: int = 0
	if entity_node and "generation" in entity_node:
		generation = entity_node.generation
	var remaining: int = 2 - generation
	for i in range(remaining):
		var dot_y: float = -r * 0.8 - float(i) * r * 0.25
		draw_circle(center + Vector2(0, dot_y), maxf(1.5, r * 0.08), Color(1.0, 1.0, 1.0, 0.5))
