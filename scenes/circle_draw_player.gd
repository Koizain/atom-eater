extends Node2D

# Player drawn as a BLACK HOLE:
# - Event horizon (perfect black circle)
# - Tilted accretion disk (white → orange → red, rotating)
# - Gravitational lensing arcs
# - Event horizon glow (purple/blue)
# - HP shown as accretion disk intensity
# - Absorption radius as dashed gravitational field

var player_node: Area2D = null
var time: float = 0.0

# Spring-driven squish/stretch (kept for movement feel)
var _stretch_velocity: float = 0.0
var _display_stretch: float = 0.0
const STRETCH_SPRING: float = 200.0
const STRETCH_DAMP: float = 14.0
const MAX_STRETCH: float = 0.3
const MAX_COMPRESS: float = 0.2
const SPEED_FOR_FULL_STRETCH: float = 300.0

var _move_angle: float = 0.0

# Combo crown effect
var _crown_timer: float = 0.0
var _crown_active: bool = false
var _prev_combo: int = 0

func _process(delta: float) -> void:
	time += delta

	var target_stretch: float = 0.0
	if player_node and "velocity" in player_node:
		var vel: Vector2 = player_node.velocity
		var speed: float = vel.length()
		target_stretch = clampf(speed / SPEED_FOR_FULL_STRETCH, 0.0, 1.0) * MAX_STRETCH
		if speed > 10.0:
			_move_angle = lerp_angle(_move_angle, vel.angle(), 8.0 * delta)

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

	var hp_ratio: float = float(GameData.player_hp) / float(GameData.max_hp)

	# Compute deformation
	var stretch_x: float = 1.0 + _display_stretch
	var stretch_y: float = 1.0 - _display_stretch * (MAX_COMPRESS / MAX_STRETCH)
	draw_set_transform(Vector2.ZERO, _move_angle, Vector2(stretch_x, stretch_y))

	# === Event horizon glow (purple/blue aura) ===
	var glow_pulse: float = 0.8 + 0.2 * sin(time * 1.5)
	draw_circle(Vector2.ZERO, radius * 2.2, Color(0.3, 0.1, 0.6, 0.03 * glow_pulse))
	draw_circle(Vector2.ZERO, radius * 1.8, Color(0.35, 0.15, 0.7, 0.06 * glow_pulse))
	draw_circle(Vector2.ZERO, radius * 1.5, Color(0.4, 0.2, 0.8, 0.10 * glow_pulse))
	draw_circle(Vector2.ZERO, radius * 1.25, Color(0.3, 0.15, 0.9, 0.15 * glow_pulse))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0.2, 0.1, 0.5, 0.25 * glow_pulse))

	# === Event horizon (perfect black circle) ===
	draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, 1.0))
	draw_circle(Vector2.ZERO, radius * 0.85, Color(0.02, 0.0, 0.05, 1.0))

	# === Accretion disk (tilted elliptical ring) ===
	# HP controls brightness: full HP = bright, low HP = dim/flickering
	var disk_brightness: float = 0.4 + 0.6 * hp_ratio
	if hp_ratio < 0.35:
		# Low HP: flickering
		disk_brightness *= 0.5 + 0.5 * sin(time * 8.0 + sin(time * 13.0))
		disk_brightness = maxf(disk_brightness, 0.1)

	var disk_rotation: float = time * 0.6
	var disk_radius: float = radius * 1.6
	var disk_tilt: float = 0.35  # Y-scale for tilt effect

	# Draw multiple layers of the accretion disk
	# Back half (behind the black hole)
	_draw_accretion_half(Vector2.ZERO, disk_radius, disk_tilt, disk_rotation, disk_brightness, true, radius)
	# Front half (in front — drawn after event horizon to overlay)
	# The front half is already handled by drawing full arcs

	# === Gravitational lensing arcs ===
	draw_set_transform(Vector2.ZERO, _move_angle, Vector2(stretch_x, stretch_y))
	var lens_alpha: float = 0.08 + 0.04 * sin(time * 0.7)
	for i in range(4):
		var arc_offset: float = float(i) * TAU / 4.0 + time * 0.15 + float(i) * 0.8
		var arc_radius: float = radius * (1.8 + float(i) * 0.4)
		var arc_length: float = PI * (0.3 + 0.1 * sin(time * 0.5 + float(i)))
		var arc_alpha: float = lens_alpha * (1.0 - float(i) * 0.2)
		draw_arc(Vector2.ZERO, arc_radius, arc_offset, arc_offset + arc_length, 12,
			Color(0.8, 0.85, 1.0, arc_alpha), 1.0)

	# Reset transform for indicators
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# === Absorption radius indicator (dashed gravitational field) ===
	var abs_radius: float = radius * 1.2
	if player_node and player_node.has_method("get_absorption_radius"):
		abs_radius = player_node.get_absorption_radius()

	var seg_count: int = 16
	var seg_gap: float = TAU / float(seg_count) * 0.3
	var seg_arc: float = TAU / float(seg_count) - seg_gap
	var ring_pulse: float = 0.06 + 0.03 * sin(time * 2.0)
	for i in range(seg_count):
		var start_angle: float = (TAU / float(seg_count)) * float(i) + time * 0.3
		draw_arc(Vector2.ZERO, abs_radius, start_angle, start_angle + seg_arc, 8,
			Color(0.5, 0.3, 0.8, ring_pulse), 1.0)

	# === Crown/aura effect at max combo ===
	if _crown_active or _crown_timer > 0.0:
		var crown_alpha: float = 1.0
		if _crown_timer < 0.5:
			crown_alpha = _crown_timer / 0.5

		var spike_count: int = 8
		for i in range(spike_count):
			var angle: float = (TAU / float(spike_count)) * float(i) + time * 1.5
			var inner_r: float = radius * 1.3
			var outer_r: float = radius * 2.0 + radius * 0.3 * sin(time * 4.0 + float(i))
			var spike_start: Vector2 = Vector2(cos(angle), sin(angle)) * inner_r
			var spike_end: Vector2 = Vector2(cos(angle), sin(angle)) * outer_r
			draw_line(spike_start, spike_end, Color(1.0, 0.85, 0.2, 0.5 * crown_alpha), 2.0)

		draw_arc(Vector2.ZERO, radius * 1.4, 0.0, TAU, 48, Color(1.0, 0.85, 0.2, 0.3 * crown_alpha), 2.5)
		draw_arc(Vector2.ZERO, radius * 1.6, 0.0, TAU, 48, Color(1.0, 0.9, 0.3, 0.15 * crown_alpha), 1.5)

func _draw_accretion_half(center: Vector2, disk_r: float, tilt: float, rot: float, brightness: float, _is_back: bool, event_r: float) -> void:
	# Draw the accretion disk as tilted arcs with color gradient
	# Inner: white/yellow → orange → red at outer edge
	var layers: int = 5
	for layer in range(layers):
		var t: float = float(layer) / float(layers - 1)  # 0 = inner, 1 = outer
		var layer_r: float = event_r * 1.15 + (disk_r - event_r * 1.15) * t
		var thickness: float = lerpf(3.0, 5.0, t)

		# Color gradient: white → orange → red
		var col: Color
		if t < 0.3:
			col = Color(1.0, 1.0, 0.95, brightness * 0.7)  # White-hot inner
		elif t < 0.6:
			var u: float = (t - 0.3) / 0.3
			col = Color(1.0, lerpf(0.85, 0.5, u), lerpf(0.4, 0.1, u), brightness * 0.6)  # Orange
		else:
			var u: float = (t - 0.6) / 0.4
			col = Color(lerpf(1.0, 0.7, u), lerpf(0.3, 0.1, u), 0.05, brightness * (0.5 - 0.2 * u))  # Red

		# Draw tilted elliptical arcs (simulate tilt by scaling Y)
		# Upper arc
		var seg_points: int = 20
		for seg in range(seg_points):
			var a1: float = rot + (TAU / float(seg_points)) * float(seg)
			var a2: float = rot + (TAU / float(seg_points)) * float(seg + 1)
			var p1: Vector2 = center + Vector2(cos(a1) * layer_r, sin(a1) * layer_r * tilt)
			var p2: Vector2 = center + Vector2(cos(a2) * layer_r, sin(a2) * layer_r * tilt)

			# Only draw segments that aren't hidden behind the event horizon
			var mid: Vector2 = (p1 + p2) * 0.5
			if mid.length() > event_r * 0.7 or sin((a1 + a2) * 0.5 - rot) < 0:
				draw_line(p1, p2, col, thickness)
