extends Node2D

# Draws the player circle with:
# - Inner white core that dims toward edges
# - HP-reactive outer halo (green → yellow → red)
# - Max combo crown/aura effect
# - Translucent absorption radius ring
# - Squish/stretch deformation + organic breathing

var player_node: Area2D = null
var pulse_time: float = 0.0

# Spring-driven squish/stretch
var _stretch_velocity: float = 0.0
var _display_stretch: float = 0.0
const STRETCH_SPRING: float = 200.0
const STRETCH_DAMP: float = 14.0
const MAX_STRETCH: float = 0.3
const MAX_COMPRESS: float = 0.2
const SPEED_FOR_FULL_STRETCH: float = 300.0

# Smooth movement angle
var _move_angle: float = 0.0

# Combo crown effect
var _crown_timer: float = 0.0
var _crown_active: bool = false
var _prev_combo: int = 0

func _process(delta: float) -> void:
	pulse_time += delta

	# Drive spring toward speed-based target stretch
	var target_stretch: float = 0.0
	if player_node and "velocity" in player_node:
		var vel: Vector2 = player_node.velocity
		var speed: float = vel.length()
		target_stretch = clampf(speed / SPEED_FOR_FULL_STRETCH, 0.0, 1.0) * MAX_STRETCH

		if speed > 10.0:
			_move_angle = lerp_angle(_move_angle, vel.angle(), 8.0 * delta)

	# Damped spring
	var spring_force: float = (target_stretch - _display_stretch) * STRETCH_SPRING - _stretch_velocity * STRETCH_DAMP
	_stretch_velocity += spring_force * delta
	_display_stretch += _stretch_velocity * delta

	# Track combo for crown effect
	if player_node and "combo_count" in player_node:
		var combo: int = player_node.combo_count
		if combo >= 10 and _prev_combo < 10:
			_crown_active = true
			_crown_timer = 3.0
		_prev_combo = combo

	if _crown_timer > 0.0:
		_crown_timer -= delta
		if _crown_timer <= 0.0:
			_crown_active = false

	queue_redraw()

func _draw() -> void:
	if not player_node:
		player_node = get_parent() as Area2D

	var radius: float = 16.0
	if player_node and player_node.has_method("get_player_radius"):
		radius = player_node.get_player_radius()

	# Organic idle breathing
	var breath: float = 1.0 + 0.012 * sin(pulse_time * 1.8) + 0.007 * sin(pulse_time * 3.7 + 0.5)
	radius *= breath

	var scale_color: Color = GameData.get_scale_color()

	# Compute deformation axes
	var stretch_x: float = 1.0 + _display_stretch
	var stretch_y: float = 1.0 - _display_stretch * (MAX_COMPRESS / MAX_STRETCH)

	# Apply squish/stretch transform aligned to movement direction
	draw_set_transform(Vector2.ZERO, _move_angle, Vector2(stretch_x, stretch_y))

	# === HP-reactive outer halo ===
	var hp_ratio: float = float(GameData.player_hp) / float(GameData.max_hp)
	var halo_color: Color
	if hp_ratio > 0.65:
		# Green (full health)
		halo_color = Color(0.2, 0.9, 0.3, 0.08)
	elif hp_ratio > 0.35:
		# Yellow (mid health)
		halo_color = Color(0.9, 0.8, 0.1, 0.10)
	else:
		# Red (low health) with urgent pulse
		var urgency: float = 0.5 + 0.5 * sin(pulse_time * 6.0)
		halo_color = Color(1.0, 0.15, 0.1, 0.08 + 0.06 * urgency)

	# Wide outer halo (HP reactive)
	draw_circle(Vector2.ZERO, radius * 2.8, Color(halo_color.r, halo_color.g, halo_color.b, halo_color.a * 0.4))
	draw_circle(Vector2.ZERO, radius * 2.2, Color(halo_color.r, halo_color.g, halo_color.b, halo_color.a * 0.7))

	# Neon outer glow layers
	draw_circle(Vector2.ZERO, radius * 2.0, Color(scale_color.r, scale_color.g, scale_color.b, 0.03))
	draw_circle(Vector2.ZERO, radius * 1.7, Color(scale_color.r, scale_color.g, scale_color.b, 0.06))
	draw_circle(Vector2.ZERO, radius * 1.45, Color(scale_color.r, scale_color.g, scale_color.b, 0.12))
	draw_circle(Vector2.ZERO, radius * 1.2, Color(scale_color.r, scale_color.g, scale_color.b, 0.22))

	# Core body — bright with edge-dim gradient (layered circles)
	draw_circle(Vector2.ZERO, radius, Color(scale_color.r * 0.7 + 0.3, scale_color.g * 0.7 + 0.3, scale_color.b * 0.7 + 0.3, 0.95))
	draw_circle(Vector2.ZERO, radius * 0.75, Color(scale_color.r * 0.5 + 0.5, scale_color.g * 0.5 + 0.5, scale_color.b * 0.5 + 0.5, 0.85))

	# Inner white core — bright center that dims toward edges
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 1.0, 1.0, 0.75))
	draw_circle(Vector2.ZERO, radius * 0.35, Color(1.0, 1.0, 1.0, 0.85))
	draw_circle(Vector2.ZERO, radius * 0.15, Color(1.0, 1.0, 1.0, 0.95))

	# Reset transform for indicators
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# === Absorption radius indicator (translucent ring) ===
	var abs_radius: float = radius * 1.2
	if player_node and player_node.has_method("get_absorption_radius"):
		abs_radius = player_node.get_absorption_radius()

	# Dashed-feel ring: draw segmented arcs
	var seg_count: int = 16
	var seg_gap: float = TAU / float(seg_count) * 0.3
	var seg_arc: float = TAU / float(seg_count) - seg_gap
	var ring_pulse: float = 0.08 + 0.04 * sin(pulse_time * 2.0)
	for i in range(seg_count):
		var start_angle: float = (TAU / float(seg_count)) * float(i) + pulse_time * 0.3
		draw_arc(Vector2.ZERO, abs_radius, start_angle, start_angle + seg_arc, 8, Color(scale_color.r, scale_color.g, scale_color.b, ring_pulse), 1.5)

	# === HP indicator rings (when damaged) ===
	if GameData.player_hp < GameData.max_hp:
		var hp_color: Color = Color(1.0, 0.2, 0.2, 0.3 + 0.2 * sin(pulse_time * 4.0))
		draw_arc(Vector2.ZERO, radius * 1.1, 0.0, TAU, 36, hp_color, 2.0)

	# === Crown/aura effect at max combo ===
	if _crown_active or _crown_timer > 0.0:
		var crown_alpha: float = 1.0
		if _crown_timer < 0.5:
			crown_alpha = _crown_timer / 0.5

		# Radiating aura spikes
		var spike_count: int = 8
		for i in range(spike_count):
			var angle: float = (TAU / float(spike_count)) * float(i) + pulse_time * 1.5
			var inner_r: float = radius * 1.3
			var outer_r: float = radius * 2.0 + radius * 0.3 * sin(pulse_time * 4.0 + float(i))
			var spike_start: Vector2 = Vector2(cos(angle), sin(angle)) * inner_r
			var spike_end: Vector2 = Vector2(cos(angle), sin(angle)) * outer_r
			draw_line(spike_start, spike_end, Color(1.0, 0.85, 0.2, 0.5 * crown_alpha), 2.0)

		# Golden halo ring
		draw_arc(Vector2.ZERO, radius * 1.4, 0.0, TAU, 48, Color(1.0, 0.85, 0.2, 0.3 * crown_alpha), 2.5)
		draw_arc(Vector2.ZERO, radius * 1.6, 0.0, TAU, 48, Color(1.0, 0.9, 0.3, 0.15 * crown_alpha), 1.5)
