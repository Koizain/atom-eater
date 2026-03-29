extends Node2D

# Scale-aware entity drawing — 18 scales:
# 0-1: Quantum Foam/Subatomic  2: Atomic  3: Molecular  4: Viral
# 5: Bacterial  6: Microorganism  7: Insect  8: Small Animal
# 9: Human  10: Vehicle  11: City  12: Geographic
# 13: Planetary  14: Stellar  15: Galactic  16-17: Cosmic/Universal

var entity_node: Area2D = null
var time: float = 0.0

# Sparkle emission
var sparkle_timer: float = 0.0
const SPARKLE_INTERVAL: float = 0.15

# Tremble state
var tremble_offset: Vector2 = Vector2.ZERO

# Cached references
var _cached_main: Node = null
var _cached_player: Node2D = null
var _cache_checked: bool = false

# Throttle redraw
var _frame_counter: int = 0
const REDRAW_EVERY_N_FRAMES: int = 2

func _process(delta: float) -> void:
	if not entity_node:
		entity_node = get_parent() as Area2D
	if not entity_node:
		return

	if not entity_node.visible:
		return

	time += delta

	if not _cache_checked:
		_cache_checked = true
		_find_and_cache_refs()

	sparkle_timer -= delta
	if sparkle_timer <= 0.0:
		sparkle_timer = SPARKLE_INTERVAL
		_emit_sparkle()

	_update_tremble()

	_frame_counter += 1
	if _frame_counter >= REDRAW_EVERY_N_FRAMES:
		_frame_counter = 0
		queue_redraw()

func _find_and_cache_refs() -> void:
	if not entity_node:
		return
	var node: Node = entity_node.get_parent()
	var _iter: int = 0
	while node and not node.has_method("add_sparkle") and _iter < 20:
		node = node.get_parent()
		_iter += 1
	if node and node.has_method("add_sparkle"):
		_cached_main = node
		var p = node.get_node_or_null("Player")
		if p:
			_cached_player = p

func _emit_sparkle() -> void:
	if not entity_node or not entity_node.is_active:
		return
	if _cached_main and is_instance_valid(_cached_main):
		_cached_main.add_sparkle(entity_node.global_position, entity_node.entity_color)

func _update_tremble() -> void:
	if not entity_node:
		tremble_offset = Vector2.ZERO
		return

	if not _cached_player or not is_instance_valid(_cached_player):
		tremble_offset = Vector2.ZERO
		return

	var dist: float = entity_node.global_position.distance_to(_cached_player.global_position)
	var player_radius: float = 16.0
	if _cached_player.has_method("get_absorption_radius"):
		player_radius = _cached_player.get_absorption_radius()

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

	if not entity_node or not entity_node.visible:
		return

	var radius: float = entity_node.entity_radius
	var color: Color = entity_node.entity_color
	var is_toxic: bool = entity_node.is_toxic

	# Phase-offset bob
	var phase: float = float(entity_node.get_instance_id()) * 0.1
	var bob: float = 1.0 + 0.03 * sin(time * 2.5 + phase)
	radius *= bob

	var center: Vector2 = tremble_offset

	if is_toxic:
		_draw_toxic(center, radius, color)
		return

	# Use scale-aware drawing
	var scale_idx: int = entity_node.scale_index
	var etype: int = entity_node.entity_type

	# Determine size category: 0=small, 1=medium, 2=large
	var size_cat: int = _get_size_category(radius, scale_idx)

	draw_scale_entity(scale_idx, radius, size_cat, etype, color, center, phase)

func _get_size_category(radius: float, scale_idx: int) -> int:
	var lo: float = 12.0
	var hi: float = 22.0
	if scale_idx <= 1:
		lo = 8.0; hi = 16.0
	elif scale_idx == 2:
		lo = 10.0; hi = 20.0
	elif scale_idx == 3:
		lo = 12.0; hi = 24.0
	elif scale_idx <= 5:
		lo = 14.0; hi = 26.0
	elif scale_idx <= 8:
		lo = 16.0; hi = 30.0
	else:
		lo = 18.0; hi = 32.0
	if radius < lo:
		return 0
	elif radius < hi:
		return 1
	else:
		return 2

func draw_scale_entity(scale_idx: int, radius: float, size_cat: int, etype: int, color: Color, center: Vector2, phase: float) -> void:
	match scale_idx:
		0, 1:
			_draw_quantum(center, radius, size_cat, color, phase)
		2:
			_draw_atomic(center, radius, size_cat, color, phase)
		3:
			_draw_molecular(center, radius, size_cat, color, phase)
		4:
			_draw_viral(center, radius, size_cat, color, phase)
		5:
			_draw_bacterial(center, radius, size_cat, color, phase)
		6:
			_draw_microorganism(center, radius, size_cat, color, phase)
		7:
			_draw_insect(center, radius, size_cat, color, phase)
		8:
			_draw_small_animal(center, radius, size_cat, color, phase)
		9:
			_draw_human(center, radius, size_cat, color, phase)
		10:
			_draw_vehicle(center, radius, size_cat, color, phase)
		11:
			_draw_city(center, radius, size_cat, color, phase)
		12:
			_draw_geographic(center, radius, size_cat, color, phase)
		13:
			_draw_planetary(center, radius, size_cat, color, phase)
		14:
			_draw_stellar(center, radius, size_cat, color, phase)
		15:
			_draw_galactic(center, radius, size_cat, color, phase)
		_:
			_draw_cosmic(center, radius, size_cat, color, phase)

# ── Scale 0-1: Quantum/Subatomic ────────────────────────────────

func _draw_quantum(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	var flicker: float = 0.6 + 0.4 * sin(time * 12.0 + phase)

	match size_cat:
		0:
			# Small: flickering point, 2-3 tiny dots
			for i in range(3):
				var offset: Vector2 = Vector2(
					sin(time * 8.0 + float(i) * 2.1) * r * 0.3,
					cos(time * 9.5 + float(i) * 1.7) * r * 0.3
				)
				var dot_alpha: float = flicker * (0.5 + 0.5 * sin(time * 15.0 + float(i) * 3.0))
				draw_circle(center + offset, maxf(r * 0.2, 1.5), Color(color.r, color.g, color.b, dot_alpha))
			# Central glow
			draw_circle(center, r * 0.4, Color(color.r, color.g, color.b, 0.3 * flicker))
		1:
			# Medium: quark triplet — 3 circles in triangle connected by lines
			var tri_r: float = r * 0.45
			var points: Array[Vector2] = []
			for i in range(3):
				var angle: float = TAU / 3.0 * float(i) + time * 0.5
				var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * tri_r
				points.append(p)

			# Gluon lines (wiggly)
			for i in range(3):
				var next: int = (i + 1) % 3
				draw_line(points[i], points[next], Color(color.r, color.g, color.b, 0.3 * flicker), 1.0)

			# Quarks
			for i in range(3):
				var qcolor: Color
				match i:
					0: qcolor = Color(1.0, 0.3, 0.3, 0.8 * flicker)  # red
					1: qcolor = Color(0.3, 1.0, 0.3, 0.8 * flicker)  # green
					_: qcolor = Color(0.3, 0.3, 1.0, 0.8 * flicker)  # blue
				draw_circle(points[i], maxf(r * 0.18, 2.0), qcolor)
				draw_circle(points[i], maxf(r * 0.1, 1.0), Color(1.0, 1.0, 1.0, 0.4 * flicker))

			# Confinement glow
			draw_arc(center, tri_r * 1.3, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.1 * flicker), 1.0)
		2, _:
			# Large: nucleus — dense cluster of 6-8 circles
			var cluster_count: int = 7
			for i in range(cluster_count):
				var angle: float = TAU / float(cluster_count) * float(i) + sin(time * 0.3) * 0.2
				var dist: float = r * 0.35 * (0.6 + 0.4 * sin(float(i) * 1.3))
				var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
				var nuc_r: float = maxf(r * 0.22, 2.0)
				# Alternate proton (red) and neutron (blue)
				var nuc_color: Color
				if i % 2 == 0:
					nuc_color = Color(0.9, 0.3, 0.3, 0.7 * flicker)
				else:
					nuc_color = Color(0.3, 0.4, 0.9, 0.7 * flicker)
				draw_circle(p, nuc_r, nuc_color)

			# Nuclear glow
			draw_circle(center, r * 0.6, Color(color.r, color.g, color.b, 0.15 * flicker))
			# Outer field
			draw_arc(center, r, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.08), 1.0)

# ── Scale 2: Atomic ─────────────────────────────────────────────

func _draw_atomic(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	match size_cat:
		0:
			# Small: 1 nucleus + 1 electron orbit + 1 electron
			var nuc_r: float = r * 0.3
			draw_circle(center, nuc_r, Color(color.r * 0.6 + 0.2, color.g * 0.6 + 0.2, color.b * 0.6 + 0.2, 0.9))
			draw_circle(center, nuc_r * 0.5, Color(1.0, 1.0, 1.0, 0.5))

			# Electron orbit
			var orbit_r: float = r * 0.85
			draw_arc(center, orbit_r, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.2), 1.0)

			# Electron
			var e_angle: float = time * 3.0 + phase
			var e_pos: Vector2 = center + Vector2(cos(e_angle), sin(e_angle)) * orbit_r
			draw_circle(e_pos, maxf(r * 0.1, 1.5), Color(0.4, 0.7, 1.0, 0.9))
			draw_circle(e_pos, maxf(r * 0.15, 2.0), Color(0.4, 0.7, 1.0, 0.3))
		1:
			# Medium: nucleus + 2 electron orbits at angles + 2 electrons
			var nuc_r: float = r * 0.35
			draw_circle(center, nuc_r, Color(color.r * 0.5 + 0.3, color.g * 0.5 + 0.3, color.b * 0.5 + 0.3, 0.9))
			draw_circle(center, nuc_r * 0.5, Color(1.0, 1.0, 1.0, 0.4))

			# Two tilted orbits
			for i in range(2):
				var tilt: float = float(i) * PI / 3.0  # 60 degrees apart
				var orbit_r: float = r * 0.8
				# Draw tilted orbit as elliptical arc
				var seg_count: int = 24
				for seg in range(seg_count):
					var a1: float = TAU / float(seg_count) * float(seg)
					var a2: float = TAU / float(seg_count) * float(seg + 1)
					var p1: Vector2 = center + Vector2(cos(a1) * orbit_r, sin(a1) * orbit_r * cos(tilt))
					var p2: Vector2 = center + Vector2(cos(a2) * orbit_r, sin(a2) * orbit_r * cos(tilt))
					draw_line(p1, p2, Color(color.r, color.g, color.b, 0.15), 1.0)

				# Electron on this orbit
				var e_angle: float = time * (2.5 + float(i) * 0.7) + phase + float(i) * PI
				var e_pos: Vector2 = center + Vector2(cos(e_angle) * orbit_r, sin(e_angle) * orbit_r * cos(tilt))
				draw_circle(e_pos, maxf(r * 0.09, 1.5), Color(0.4, 0.7, 1.0, 0.9))
		2, _:
			# Large: nucleus + 3-4 electron shells + multiple electrons
			var nuc_r: float = r * 0.25
			# Nucleus with proton/neutron detail
			draw_circle(center, nuc_r, Color(0.8, 0.3, 0.3, 0.8))
			draw_circle(center + Vector2(nuc_r * 0.3, 0), nuc_r * 0.6, Color(0.3, 0.4, 0.8, 0.6))
			draw_circle(center, nuc_r * 0.4, Color(1.0, 1.0, 1.0, 0.3))

			var shell_count: int = 3
			for shell in range(shell_count):
				var shell_r: float = r * (0.45 + float(shell) * 0.2)
				var tilt: float = float(shell) * PI / float(shell_count + 1)

				# Orbit ring
				draw_arc(center, shell_r, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.12 - float(shell) * 0.02), 1.0)

				# Electrons per shell: 2, 4, 6
				var electron_count: int = (shell + 1) * 2
				for e in range(electron_count):
					var e_angle: float = time * (2.0 - float(shell) * 0.4) + float(e) * TAU / float(electron_count) + phase
					var e_pos: Vector2 = center + Vector2(cos(e_angle), sin(e_angle)) * shell_r
					draw_circle(e_pos, maxf(r * 0.06, 1.0), Color(0.4, 0.7, 1.0, 0.8))

# ── Scale 3: Molecular ──────────────────────────────────────────

func _draw_molecular(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	var wobble: float = sin(time * 1.5 + phase) * 0.02

	match size_cat:
		0:
			# Small: H2 molecule — 2 circles connected by a line
			var sep: float = r * 0.6
			var p1: Vector2 = center + Vector2(-sep, 0)
			var p2: Vector2 = center + Vector2(sep, 0)

			# Bond line
			draw_line(p1, p2, Color(color.r, color.g, color.b, 0.5), 2.0)

			# Atoms
			var atom_r: float = maxf(r * 0.35, 3.0)
			draw_circle(p1, atom_r, Color(color.r * 0.6 + 0.3, color.g * 0.6 + 0.3, color.b * 0.6 + 0.3, 0.85))
			draw_circle(p2, atom_r, Color(color.r * 0.6 + 0.3, color.g * 0.6 + 0.3, color.b * 0.6 + 0.3, 0.85))
			draw_circle(p1, atom_r * 0.5, Color(1.0, 1.0, 1.0, 0.4))
			draw_circle(p2, atom_r * 0.5, Color(1.0, 1.0, 1.0, 0.4))
		1:
			# Medium: H2O — bent V-shape (104.5 degree angle)
			var bond_len: float = r * 0.55
			var angle_half: float = (104.5 / 2.0) * PI / 180.0

			var oxygen: Vector2 = center
			var h1: Vector2 = center + Vector2(cos(-angle_half + wobble), sin(-angle_half + wobble)) * bond_len
			var h2: Vector2 = center + Vector2(cos(angle_half + wobble), sin(angle_half + wobble)) * bond_len

			# Bonds
			draw_line(oxygen, h1, Color(color.r, color.g, color.b, 0.5), 2.0)
			draw_line(oxygen, h2, Color(color.r, color.g, color.b, 0.5), 2.0)

			# Oxygen (larger, red-tinted)
			var o_r: float = maxf(r * 0.3, 3.0)
			draw_circle(oxygen, o_r, Color(0.9, 0.2, 0.2, 0.85))
			draw_circle(oxygen, o_r * 0.5, Color(1.0, 0.5, 0.5, 0.5))

			# Hydrogens (smaller, white)
			var h_r: float = maxf(r * 0.2, 2.0)
			draw_circle(h1, h_r, Color(0.9, 0.9, 0.9, 0.85))
			draw_circle(h2, h_r, Color(0.9, 0.9, 0.9, 0.85))
		2, _:
			# Large: Benzene ring — 6 circles in hexagonal ring with alternating bonds
			var hex_r: float = r * 0.55
			var atom_r: float = maxf(r * 0.15, 2.0)
			var hex_points: Array[Vector2] = []

			for i in range(6):
				var angle: float = TAU / 6.0 * float(i) - PI / 6.0 + wobble
				hex_points.append(center + Vector2(cos(angle), sin(angle)) * hex_r)

			# Bonds — alternating single/double
			for i in range(6):
				var next: int = (i + 1) % 6
				var p1: Vector2 = hex_points[i]
				var p2: Vector2 = hex_points[next]
				# Single bond
				draw_line(p1, p2, Color(color.r, color.g, color.b, 0.6), 1.5)
				# Double bond on even indices
				if i % 2 == 0:
					var inward: Vector2 = (center - (p1 + p2) * 0.5).normalized() * 3.0
					draw_line(p1 + inward, p2 + inward, Color(color.r, color.g, color.b, 0.35), 1.0)

			# Carbon atoms at vertices
			for i in range(6):
				draw_circle(hex_points[i], atom_r, Color(0.3, 0.3, 0.3, 0.85))
				draw_circle(hex_points[i], atom_r * 0.5, Color(0.6, 0.6, 0.6, 0.5))

			# Inner ring glow (delocalized electrons)
			draw_arc(center, hex_r * 0.55, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.15), 1.5)

# ── Scale 4: Viral ──────────────────────────────────────────────

func _draw_viral(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	var pulse: float = 0.9 + 0.1 * sin(time * 3.0 + phase)
	match size_cat:
		0:
			# Icosahedral shape — hexagon with spike triangles
			var hex_r: float = r * 0.6
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var a: float = TAU / 6.0 * float(i) - PI / 6.0
				pts.append(center + Vector2(cos(a), sin(a)) * hex_r)
			draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.6 * pulse))
			# Spike triangles on each edge
			for i in range(6):
				var next: int = (i + 1) % 6
				var mid: Vector2 = (pts[i] + pts[next]) * 0.5
				var outward: Vector2 = (mid - center).normalized() * r * 0.25
				var spike: Vector2 = mid + outward
				draw_line(pts[i], spike, Color(color.r, color.g, color.b, 0.5 * pulse), 1.0)
				draw_line(spike, pts[next], Color(color.r, color.g, color.b, 0.5 * pulse), 1.0)
			draw_arc(center, hex_r, 0.0, TAU, 12, Color(color.r, color.g, color.b, 0.3), 1.0)
		1:
			# Bacteriophage — hexagon head + tail + leg lines
			var head_r: float = r * 0.35
			var head_pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var a: float = TAU / 6.0 * float(i) - PI / 6.0
				head_pts.append(center + Vector2(0, -r * 0.2) + Vector2(cos(a), sin(a)) * head_r)
			draw_colored_polygon(head_pts, Color(color.r, color.g, color.b, 0.65 * pulse))
			# Tail
			var tail_top: Vector2 = center + Vector2(0, -r * 0.2 + head_r)
			var tail_bot: Vector2 = center + Vector2(0, r * 0.55)
			draw_line(tail_top, tail_bot, Color(color.r, color.g, color.b, 0.7 * pulse), 2.0)
			# Legs at bottom
			for i in range(3):
				var angle: float = -PI / 3.0 + float(i) * PI / 3.0
				var leg_end: Vector2 = tail_bot + Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5)) * r * 0.3
				draw_line(tail_bot, leg_end, Color(color.r, color.g, color.b, 0.5 * pulse), 1.5)
		2, _:
			# Complex virus — two overlapping pentagons + spike proteins
			for p in range(2):
				var rot: float = float(p) * PI / 5.0
				var pent_r: float = r * 0.5
				var pts: PackedVector2Array = PackedVector2Array()
				for i in range(5):
					var a: float = TAU / 5.0 * float(i) + rot
					pts.append(center + Vector2(cos(a), sin(a)) * pent_r)
				draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.35 * pulse))
				for i in range(5):
					draw_line(pts[i], pts[(i + 1) % 5], Color(color.r, color.g, color.b, 0.5), 1.0)
			# Spike proteins — 8 radiating lines
			for i in range(8):
				var a: float = TAU / 8.0 * float(i) + time * 0.3
				var spike_start: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.55
				var spike_end: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.9
				draw_line(spike_start, spike_end, Color(color.r, color.g, color.b, 0.6 * pulse), 1.5)
				draw_circle(spike_end, maxf(r * 0.05, 1.0), Color(color.r, color.g, color.b, 0.5))

# ── Scale 5: Bacterial ─────────────────────────────────────────

func _draw_bacterial(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	match size_cat:
		0:
			# Coccus — circle with 1-2 flagellum lines
			draw_circle(center, r * 0.6, Color(color.r, color.g, color.b, 0.75))
			draw_circle(center, r * 0.35, Color(color.r * 0.5 + 0.4, color.g * 0.5 + 0.4, color.b * 0.5 + 0.4, 0.4))
			# Flagellum — sinusoidal polyline
			var flag_pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var t: float = float(i) / 9.0
				var x: float = r * 0.6 + t * r * 0.5
				var y: float = sin(t * TAU * 1.5 + time * 4.0 + phase) * r * 0.12
				flag_pts.append(center + Vector2(x, y))
			draw_polyline(flag_pts, Color(color.r, color.g, color.b, 0.4), 1.0)
		1:
			# Bacillus — rounded rectangle + multiple flagella
			var hw: float = r * 0.7
			var hh: float = r * 0.3
			var body_pts: PackedVector2Array = PackedVector2Array()
			for i in range(12):
				var a: float = TAU / 12.0 * float(i)
				body_pts.append(center + Vector2(cos(a) * hw, sin(a) * hh))
			draw_colored_polygon(body_pts, Color(color.r, color.g, color.b, 0.7))
			draw_polyline(body_pts, Color(color.r, color.g, color.b, 0.4), 1.0)
			# Multiple flagella
			for f in range(3):
				var flag_pts: PackedVector2Array = PackedVector2Array()
				var start_y: float = (float(f) - 1.0) * hh * 0.5
				for i in range(8):
					var t: float = float(i) / 7.0
					var x: float = hw + t * r * 0.5
					var y: float = start_y + sin(t * TAU * 1.2 + time * 5.0 + phase + float(f)) * r * 0.1
					flag_pts.append(center + Vector2(x, y))
				draw_polyline(flag_pts, Color(color.r, color.g, color.b, 0.35), 1.0)
		2, _:
			# Spirochete — wavy sinusoidal body
			var wave_pts: PackedVector2Array = PackedVector2Array()
			var seg: int = 20
			for i in range(seg):
				var t: float = float(i) / float(seg - 1) - 0.5
				var x: float = t * r * 1.8
				var y: float = sin(t * TAU * 2.0 + time * 3.0 + phase) * r * 0.3
				wave_pts.append(center + Vector2(x, y))
			draw_polyline(wave_pts, Color(color.r, color.g, color.b, 0.8), maxf(r * 0.15, 2.0))
			# Inner highlight
			var inner_pts: PackedVector2Array = PackedVector2Array()
			for i in range(seg):
				var t: float = float(i) / float(seg - 1) - 0.5
				var x: float = t * r * 1.8
				var y: float = sin(t * TAU * 2.0 + time * 3.0 + phase) * r * 0.3
				inner_pts.append(center + Vector2(x, y))
			draw_polyline(inner_pts, Color(1.0, 1.0, 1.0, 0.2), maxf(r * 0.06, 1.0))

# ── Scale 6: Microorganism ──────────────────────────────────────

func _draw_microorganism(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	match size_cat:
		0:
			# Small cell: membrane + nucleus + 2-3 mitochondria
			# Cell membrane
			draw_arc(center, r * 0.95, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.4), 1.5)
			draw_circle(center, r * 0.9, Color(color.r * 0.3 + 0.1, color.g * 0.3 + 0.1, color.b * 0.3 + 0.1, 0.5))

			# Nucleus
			var nuc_pos: Vector2 = center + Vector2(r * 0.1, -r * 0.05)
			draw_circle(nuc_pos, r * 0.3, Color(0.4, 0.2, 0.5, 0.7))
			draw_circle(nuc_pos, r * 0.15, Color(0.6, 0.3, 0.7, 0.5))

			# Mitochondria (small ovals)
			for i in range(3):
				var angle: float = phase + float(i) * TAU / 3.0 + sin(time * 0.5) * 0.3
				var m_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * r * 0.55
				var m_angle: float = angle + PI / 4.0
				# Draw as two offset circles for oval effect
				var offset: Vector2 = Vector2(cos(m_angle), sin(m_angle)) * r * 0.06
				draw_circle(m_pos - offset, r * 0.1, Color(0.8, 0.4, 0.2, 0.6))
				draw_circle(m_pos + offset, r * 0.1, Color(0.8, 0.4, 0.2, 0.6))
				draw_circle(m_pos, r * 0.08, Color(0.9, 0.5, 0.3, 0.4))
		1:
			# Medium cell: larger with more organelles
			# Cell membrane (double layer)
			draw_arc(center, r, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.3), 2.0)
			draw_circle(center, r * 0.92, Color(color.r * 0.2 + 0.05, color.g * 0.2 + 0.05, color.b * 0.2 + 0.1, 0.45))

			# Nucleus with nucleolus
			var nuc_pos: Vector2 = center + Vector2(r * 0.05, r * 0.05)
			draw_circle(nuc_pos, r * 0.35, Color(0.35, 0.15, 0.45, 0.7))
			draw_arc(nuc_pos, r * 0.35, 0.0, TAU, 16, Color(0.5, 0.3, 0.6, 0.4), 1.0)
			draw_circle(nuc_pos + Vector2(r * 0.05, -r * 0.05), r * 0.12, Color(0.6, 0.3, 0.7, 0.6))

			# Organelles scattered around
			var org_count: int = 5
			for i in range(org_count):
				var angle: float = phase + float(i) * TAU / float(org_count) + sin(time * 0.3 + float(i)) * 0.2
				var dist: float = r * (0.5 + 0.15 * sin(float(i) * 2.0))
				var o_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
				# Mix of organelle types
				if i < 2:
					# Mitochondria
					var m_dir: Vector2 = Vector2(cos(angle + 0.5), sin(angle + 0.5))
					draw_circle(o_pos - m_dir * r * 0.04, r * 0.08, Color(0.8, 0.4, 0.2, 0.6))
					draw_circle(o_pos + m_dir * r * 0.04, r * 0.08, Color(0.8, 0.4, 0.2, 0.6))
				elif i < 4:
					# ER (small circles in line)
					draw_circle(o_pos, r * 0.06, Color(0.3, 0.6, 0.4, 0.5))
				else:
					# Vesicle
					draw_circle(o_pos, r * 0.07, Color(0.5, 0.5, 0.7, 0.4))
					draw_arc(o_pos, r * 0.07, 0.0, TAU, 8, Color(0.6, 0.6, 0.8, 0.3), 1.0)
		2, _:
			# Large: Neuron — cell body + axon + dendrites
			# Cell body (soma)
			draw_circle(center, r * 0.4, Color(color.r * 0.5 + 0.2, color.g * 0.5 + 0.2, color.b * 0.5 + 0.2, 0.8))
			draw_circle(center, r * 0.25, Color(color.r * 0.3 + 0.4, color.g * 0.3 + 0.4, color.b * 0.3 + 0.4, 0.6))

			# Nucleus
			draw_circle(center + Vector2(0, -r * 0.05), r * 0.12, Color(0.4, 0.2, 0.5, 0.7))

			# Axon (long line going right)
			var axon_end: Vector2 = center + Vector2(r * 0.9, r * 0.1)
			draw_line(center + Vector2(r * 0.35, 0), axon_end, Color(color.r, color.g, color.b, 0.6), 2.0)

			# Axon terminal branches
			for i in range(3):
				var branch_angle: float = -PI / 6.0 + float(i) * PI / 6.0
				var branch_end: Vector2 = axon_end + Vector2(cos(branch_angle), sin(branch_angle)) * r * 0.2
				draw_line(axon_end, branch_end, Color(color.r, color.g, color.b, 0.4), 1.5)
				draw_circle(branch_end, maxf(r * 0.04, 1.5), Color(color.r, color.g, color.b, 0.6))

			# Dendrites (branching lines from top/left of soma)
			for i in range(4):
				var d_angle: float = PI + PI / 3.0 * float(i) - PI / 3.0
				var d_start: Vector2 = center + Vector2(cos(d_angle), sin(d_angle)) * r * 0.35
				var d_end: Vector2 = center + Vector2(cos(d_angle), sin(d_angle)) * r * 0.7
				draw_line(d_start, d_end, Color(color.r, color.g, color.b, 0.5), 1.5)
				# Sub-branches
				var sub_angle1: float = d_angle - 0.4
				var sub_angle2: float = d_angle + 0.4
				draw_line(d_end, d_end + Vector2(cos(sub_angle1), sin(sub_angle1)) * r * 0.2, Color(color.r, color.g, color.b, 0.3), 1.0)
				draw_line(d_end, d_end + Vector2(cos(sub_angle2), sin(sub_angle2)) * r * 0.2, Color(color.r, color.g, color.b, 0.3), 1.0)

			# Myelin sheaths on axon
			var axon_dir: Vector2 = (axon_end - center).normalized()
			for i in range(3):
				var sheath_pos: Vector2 = center + Vector2(r * 0.35, 0) + axon_dir * (float(i + 1) * r * 0.15)
				var perp: Vector2 = Vector2(-axon_dir.y, axon_dir.x)
				draw_line(sheath_pos + perp * r * 0.06, sheath_pos - perp * r * 0.06, Color(0.8, 0.8, 0.3, 0.3), 2.5)

# ── Scale 7: Insect ─────────────────────────────────────────────

func _draw_insect(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	var walk: float = sin(time * 5.0 + phase) * 0.15
	match size_cat:
		0:
			# Ant — 3 body circles + 6 legs + 2 antennae
			var head_p: Vector2 = center + Vector2(0, -r * 0.4)
			var thorax_p: Vector2 = center + Vector2(0, -r * 0.1)
			var abdomen_p: Vector2 = center + Vector2(0, r * 0.25)
			draw_circle(head_p, r * 0.2, Color(color.r, color.g, color.b, 0.85))
			draw_circle(thorax_p, r * 0.25, Color(color.r, color.g, color.b, 0.8))
			draw_circle(abdomen_p, r * 0.35, Color(color.r, color.g, color.b, 0.75))
			# Legs — 3 pairs from thorax
			for i in range(3):
				var ly: float = -r * 0.2 + float(i) * r * 0.15
				var lw: float = walk * (1.0 if i % 2 == 0 else -1.0)
				draw_line(center + Vector2(0, ly), center + Vector2(-r * 0.5, ly + r * 0.15 + lw * r * 0.1), Color(color.r, color.g, color.b, 0.6), 1.0)
				draw_line(center + Vector2(0, ly), center + Vector2(r * 0.5, ly + r * 0.15 - lw * r * 0.1), Color(color.r, color.g, color.b, 0.6), 1.0)
			# Antennae
			draw_line(head_p, head_p + Vector2(-r * 0.25, -r * 0.3), Color(color.r, color.g, color.b, 0.5), 1.0)
			draw_line(head_p, head_p + Vector2(r * 0.25, -r * 0.3), Color(color.r, color.g, color.b, 0.5), 1.0)
		1:
			# Beetle — oval body + wing line + 6 legs + head
			var body_pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var a: float = TAU / 16.0 * float(i)
				body_pts.append(center + Vector2(cos(a) * r * 0.45, sin(a) * r * 0.65))
			draw_colored_polygon(body_pts, Color(color.r, color.g, color.b, 0.75))
			# Wing line down center
			draw_line(center + Vector2(0, -r * 0.5), center + Vector2(0, r * 0.55), Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.5), 1.5)
			# Head
			draw_circle(center + Vector2(0, -r * 0.6), r * 0.18, Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.85))
			# 6 legs
			for i in range(3):
				var ly: float = -r * 0.3 + float(i) * r * 0.3
				var lw: float = walk * (1.0 if i % 2 == 0 else -1.0)
				draw_line(center + Vector2(-r * 0.4, ly), center + Vector2(-r * 0.75, ly + r * 0.15 + lw * r * 0.08), Color(color.r, color.g, color.b, 0.5), 1.5)
				draw_line(center + Vector2(r * 0.4, ly), center + Vector2(r * 0.75, ly + r * 0.15 - lw * r * 0.08), Color(color.r, color.g, color.b, 0.5), 1.5)
		2, _:
			# Bee — striped body + wings + stinger + antennae
			var body_pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var a: float = TAU / 16.0 * float(i)
				body_pts.append(center + Vector2(cos(a) * r * 0.4, sin(a) * r * 0.6))
			draw_colored_polygon(body_pts, Color(1.0, 0.85, 0.2, 0.75))
			# Black stripes
			for s in range(3):
				var sy: float = -r * 0.3 + float(s) * r * 0.3
				draw_line(center + Vector2(-r * 0.38, sy), center + Vector2(r * 0.38, sy), Color(0.1, 0.1, 0.1, 0.6), maxf(r * 0.1, 2.0))
			# Wings (triangles)
			var wing_l: PackedVector2Array = PackedVector2Array([
				center + Vector2(-r * 0.35, -r * 0.1),
				center + Vector2(-r * 0.85, -r * 0.45),
				center + Vector2(-r * 0.3, -r * 0.4),
			])
			var wing_r: PackedVector2Array = PackedVector2Array([
				center + Vector2(r * 0.35, -r * 0.1),
				center + Vector2(r * 0.85, -r * 0.45),
				center + Vector2(r * 0.3, -r * 0.4),
			])
			draw_colored_polygon(wing_l, Color(0.8, 0.9, 1.0, 0.3))
			draw_colored_polygon(wing_r, Color(0.8, 0.9, 1.0, 0.3))
			# Stinger
			draw_line(center + Vector2(0, r * 0.6), center + Vector2(0, r * 0.85), Color(0.2, 0.2, 0.2, 0.7), 1.5)
			# Head + antennae
			draw_circle(center + Vector2(0, -r * 0.55), r * 0.18, Color(0.2, 0.15, 0.05, 0.85))
			draw_line(center + Vector2(0, -r * 0.65), center + Vector2(-r * 0.2, -r * 0.85), Color(0.2, 0.15, 0.05, 0.5), 1.0)
			draw_line(center + Vector2(0, -r * 0.65), center + Vector2(r * 0.2, -r * 0.85), Color(0.2, 0.15, 0.05, 0.5), 1.0)

# ── Scale 8: Small Animal ──────────────────────────────────────

func _draw_small_animal(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	var swim: float = sin(time * 3.0 + phase) * 0.2
	match size_cat:
		0:
			# Fish — triangle body + tail + eye
			var body: PackedVector2Array = PackedVector2Array([
				center + Vector2(-r * 0.7, 0),
				center + Vector2(r * 0.4, -r * 0.3),
				center + Vector2(r * 0.4, r * 0.3),
			])
			draw_colored_polygon(body, Color(color.r, color.g, color.b, 0.75))
			# Tail
			draw_line(center + Vector2(r * 0.4, 0), center + Vector2(r * 0.75, -r * 0.25 + swim * r * 0.15), Color(color.r, color.g, color.b, 0.6), 1.5)
			draw_line(center + Vector2(r * 0.4, 0), center + Vector2(r * 0.75, r * 0.25 + swim * r * 0.15), Color(color.r, color.g, color.b, 0.6), 1.5)
			# Eye
			draw_circle(center + Vector2(-r * 0.35, -r * 0.05), maxf(r * 0.08, 1.5), Color(1.0, 1.0, 1.0, 0.9))
			draw_circle(center + Vector2(-r * 0.35, -r * 0.05), maxf(r * 0.04, 1.0), Color(0.0, 0.0, 0.0, 0.9))
		1:
			# Frog — round body + 4 bent limbs + 2 big eyes
			draw_circle(center, r * 0.5, Color(color.r, color.g, color.b, 0.7))
			draw_circle(center, r * 0.3, Color(color.r * 0.5 + 0.3, color.g * 0.5 + 0.3, color.b * 0.5 + 0.3, 0.4))
			# Big eyes on top
			var eye_l: Vector2 = center + Vector2(-r * 0.25, -r * 0.45)
			var eye_r_pos: Vector2 = center + Vector2(r * 0.25, -r * 0.45)
			draw_circle(eye_l, r * 0.15, Color(1.0, 1.0, 1.0, 0.9))
			draw_circle(eye_r_pos, r * 0.15, Color(1.0, 1.0, 1.0, 0.9))
			draw_circle(eye_l, r * 0.07, Color(0.0, 0.0, 0.0, 0.9))
			draw_circle(eye_r_pos, r * 0.07, Color(0.0, 0.0, 0.0, 0.9))
			# 4 bent limbs (L-shaped)
			var lw: float = maxf(r * 0.05, 1.0)
			# Front legs
			draw_line(center + Vector2(-r * 0.4, -r * 0.1), center + Vector2(-r * 0.7, 0), Color(color.r, color.g, color.b, 0.6), lw)
			draw_line(center + Vector2(-r * 0.7, 0), center + Vector2(-r * 0.75, r * 0.2 + swim * r * 0.1), Color(color.r, color.g, color.b, 0.6), lw)
			draw_line(center + Vector2(r * 0.4, -r * 0.1), center + Vector2(r * 0.7, 0), Color(color.r, color.g, color.b, 0.6), lw)
			draw_line(center + Vector2(r * 0.7, 0), center + Vector2(r * 0.75, r * 0.2 - swim * r * 0.1), Color(color.r, color.g, color.b, 0.6), lw)
			# Back legs
			draw_line(center + Vector2(-r * 0.35, r * 0.3), center + Vector2(-r * 0.65, r * 0.55), Color(color.r, color.g, color.b, 0.6), lw)
			draw_line(center + Vector2(-r * 0.65, r * 0.55), center + Vector2(-r * 0.5, r * 0.75 + swim * r * 0.1), Color(color.r, color.g, color.b, 0.6), lw)
			draw_line(center + Vector2(r * 0.35, r * 0.3), center + Vector2(r * 0.65, r * 0.55), Color(color.r, color.g, color.b, 0.6), lw)
			draw_line(center + Vector2(r * 0.65, r * 0.55), center + Vector2(r * 0.5, r * 0.75 - swim * r * 0.1), Color(color.r, color.g, color.b, 0.6), lw)
		2, _:
			# Bird — oval body + wings + head + beak + tail
			# Body oval
			var body_pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var a: float = TAU / 16.0 * float(i)
				body_pts.append(center + Vector2(cos(a) * r * 0.45, sin(a) * r * 0.3))
			draw_colored_polygon(body_pts, Color(color.r, color.g, color.b, 0.7))
			# Head
			var head_p: Vector2 = center + Vector2(-r * 0.5, -r * 0.15)
			draw_circle(head_p, r * 0.18, Color(color.r, color.g, color.b, 0.8))
			# Eye
			draw_circle(head_p + Vector2(-r * 0.06, -r * 0.04), maxf(r * 0.04, 1.0), Color(0.0, 0.0, 0.0, 0.9))
			# Beak
			var beak: PackedVector2Array = PackedVector2Array([
				head_p + Vector2(-r * 0.15, -r * 0.03),
				head_p + Vector2(-r * 0.35, r * 0.02),
				head_p + Vector2(-r * 0.15, r * 0.05),
			])
			draw_colored_polygon(beak, Color(1.0, 0.7, 0.2, 0.85))
			# Wings (arcs)
			var wing_flap: float = sin(time * 6.0 + phase) * 0.3
			draw_arc(center + Vector2(0, -r * 0.15), r * 0.5, -PI * 0.7 + wing_flap, -PI * 0.2 + wing_flap, 8, Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.6), 2.0)
			draw_arc(center + Vector2(0, -r * 0.15), r * 0.45, -PI * 0.7 + wing_flap, -PI * 0.2 + wing_flap, 8, Color(color.r, color.g, color.b, 0.3), 1.5)
			# Tail
			draw_line(center + Vector2(r * 0.4, 0), center + Vector2(r * 0.75, -r * 0.2), Color(color.r, color.g, color.b, 0.5), 1.5)
			draw_line(center + Vector2(r * 0.4, 0), center + Vector2(r * 0.8, 0), Color(color.r, color.g, color.b, 0.5), 1.5)
			draw_line(center + Vector2(r * 0.4, 0), center + Vector2(r * 0.75, r * 0.15), Color(color.r, color.g, color.b, 0.5), 1.5)

# ── Scale 9: Human ──────────────────────────────────────────────

func _draw_human(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	var body_color: Color = Color(color.r * 0.6 + 0.3, color.g * 0.6 + 0.3, color.b * 0.6 + 0.3, 0.85)
	var limb_width: float = maxf(r * 0.06, 1.5)
	var walk_cycle: float = sin(time * 3.0 + phase) * 0.3

	match size_cat:
		0:
			# Small: stick figure
			var head_r: float = r * 0.2
			var head_pos: Vector2 = center + Vector2(0, -r * 0.55)

			# Head
			draw_circle(head_pos, head_r, body_color)

			# Body line
			var body_top: Vector2 = center + Vector2(0, -r * 0.35)
			var body_bottom: Vector2 = center + Vector2(0, r * 0.1)
			draw_line(body_top, body_bottom, body_color, limb_width)

			# Arms
			var arm_y: Vector2 = center + Vector2(0, -r * 0.2)
			draw_line(arm_y, arm_y + Vector2(-r * 0.3, r * 0.15 + walk_cycle * r * 0.1), body_color, limb_width)
			draw_line(arm_y, arm_y + Vector2(r * 0.3, r * 0.15 - walk_cycle * r * 0.1), body_color, limb_width)

			# Legs
			draw_line(body_bottom, body_bottom + Vector2(-r * 0.2, r * 0.35 + walk_cycle * r * 0.1), body_color, limb_width)
			draw_line(body_bottom, body_bottom + Vector2(r * 0.2, r * 0.35 - walk_cycle * r * 0.1), body_color, limb_width)
		1:
			# Medium: more detailed
			var head_r: float = r * 0.18
			var head_pos: Vector2 = center + Vector2(0, -r * 0.5)

			# Head
			draw_circle(head_pos, head_r, body_color)
			# Eyes
			draw_circle(head_pos + Vector2(-head_r * 0.35, -head_r * 0.1), maxf(head_r * 0.15, 1.0), Color(0.1, 0.1, 0.1, 0.8))
			draw_circle(head_pos + Vector2(head_r * 0.35, -head_r * 0.1), maxf(head_r * 0.15, 1.0), Color(0.1, 0.1, 0.1, 0.8))

			# Torso (rectangle approximated by thick line)
			var torso_top: Vector2 = center + Vector2(0, -r * 0.32)
			var torso_bottom: Vector2 = center + Vector2(0, r * 0.05)
			draw_line(torso_top + Vector2(-r * 0.12, 0), torso_bottom + Vector2(-r * 0.1, 0), body_color, r * 0.24)

			# Arms with elbows
			var shoulder_l: Vector2 = torso_top + Vector2(-r * 0.15, r * 0.05)
			var shoulder_r_pos: Vector2 = torso_top + Vector2(r * 0.15, r * 0.05)
			var elbow_l: Vector2 = shoulder_l + Vector2(-r * 0.15, r * 0.15 + walk_cycle * r * 0.05)
			var elbow_r: Vector2 = shoulder_r_pos + Vector2(r * 0.15, r * 0.15 - walk_cycle * r * 0.05)
			var hand_l: Vector2 = elbow_l + Vector2(-r * 0.05, r * 0.12)
			var hand_r: Vector2 = elbow_r + Vector2(r * 0.05, r * 0.12)
			draw_line(shoulder_l, elbow_l, body_color, limb_width * 1.2)
			draw_line(elbow_l, hand_l, body_color, limb_width)
			draw_line(shoulder_r_pos, elbow_r, body_color, limb_width * 1.2)
			draw_line(elbow_r, hand_r, body_color, limb_width)

			# Legs with knees
			var hip_l: Vector2 = torso_bottom + Vector2(-r * 0.08, 0)
			var hip_r: Vector2 = torso_bottom + Vector2(r * 0.08, 0)
			var knee_l: Vector2 = hip_l + Vector2(-r * 0.03, r * 0.2 + walk_cycle * r * 0.05)
			var knee_r: Vector2 = hip_r + Vector2(r * 0.03, r * 0.2 - walk_cycle * r * 0.05)
			var foot_l: Vector2 = knee_l + Vector2(0, r * 0.2)
			var foot_r: Vector2 = knee_r + Vector2(0, r * 0.2)
			draw_line(hip_l, knee_l, body_color, limb_width * 1.3)
			draw_line(knee_l, foot_l, body_color, limb_width)
			draw_line(hip_r, knee_r, body_color, limb_width * 1.3)
			draw_line(knee_r, foot_r, body_color, limb_width)
		2, _:
			# Large: bigger human with face detail
			var head_r: float = r * 0.16
			var head_pos: Vector2 = center + Vector2(0, -r * 0.5)

			# Head
			draw_circle(head_pos, head_r, body_color)
			# Eyes
			var eye_r: float = maxf(head_r * 0.18, 1.0)
			draw_circle(head_pos + Vector2(-head_r * 0.35, -head_r * 0.05), eye_r, Color(1.0, 1.0, 1.0, 0.8))
			draw_circle(head_pos + Vector2(head_r * 0.35, -head_r * 0.05), eye_r, Color(1.0, 1.0, 1.0, 0.8))
			draw_circle(head_pos + Vector2(-head_r * 0.35, -head_r * 0.05), eye_r * 0.5, Color(0.1, 0.1, 0.1, 0.9))
			draw_circle(head_pos + Vector2(head_r * 0.35, -head_r * 0.05), eye_r * 0.5, Color(0.1, 0.1, 0.1, 0.9))
			# Mouth
			draw_arc(head_pos + Vector2(0, head_r * 0.3), head_r * 0.25, 0.2, PI - 0.2, 6, Color(0.2, 0.2, 0.2, 0.5), 1.0)

			# Torso
			var torso_top: Vector2 = center + Vector2(0, -r * 0.34)
			var torso_bottom: Vector2 = center + Vector2(0, r * 0.05)
			var torso_w: float = r * 0.15
			# Draw torso as two lines (sides)
			draw_line(torso_top + Vector2(-torso_w, 0), torso_bottom + Vector2(-torso_w * 0.8, 0), body_color, 2.0)
			draw_line(torso_top + Vector2(torso_w, 0), torso_bottom + Vector2(torso_w * 0.8, 0), body_color, 2.0)
			draw_line(torso_top + Vector2(-torso_w, 0), torso_top + Vector2(torso_w, 0), body_color, 2.0)
			draw_line(torso_bottom + Vector2(-torso_w * 0.8, 0), torso_bottom + Vector2(torso_w * 0.8, 0), body_color, 2.0)

			# Arms
			var shoulder_l: Vector2 = torso_top + Vector2(-torso_w, r * 0.03)
			var shoulder_r_pos: Vector2 = torso_top + Vector2(torso_w, r * 0.03)
			var elbow_l: Vector2 = shoulder_l + Vector2(-r * 0.13, r * 0.15 + walk_cycle * r * 0.05)
			var elbow_r: Vector2 = shoulder_r_pos + Vector2(r * 0.13, r * 0.15 - walk_cycle * r * 0.05)
			var hand_l: Vector2 = elbow_l + Vector2(-r * 0.04, r * 0.14)
			var hand_r: Vector2 = elbow_r + Vector2(r * 0.04, r * 0.14)
			draw_line(shoulder_l, elbow_l, body_color, limb_width * 1.3)
			draw_line(elbow_l, hand_l, body_color, limb_width)
			draw_line(shoulder_r_pos, elbow_r, body_color, limb_width * 1.3)
			draw_line(elbow_r, hand_r, body_color, limb_width)

			# Legs
			var hip_l: Vector2 = torso_bottom + Vector2(-torso_w * 0.5, 0)
			var hip_r: Vector2 = torso_bottom + Vector2(torso_w * 0.5, 0)
			var knee_l: Vector2 = hip_l + Vector2(0, r * 0.2 + walk_cycle * r * 0.04)
			var knee_r: Vector2 = hip_r + Vector2(0, r * 0.2 - walk_cycle * r * 0.04)
			var foot_l: Vector2 = knee_l + Vector2(-r * 0.02, r * 0.2)
			var foot_r: Vector2 = knee_r + Vector2(r * 0.02, r * 0.2)
			draw_line(hip_l, knee_l, body_color, limb_width * 1.5)
			draw_line(knee_l, foot_l, body_color, limb_width * 1.2)
			draw_line(hip_r, knee_r, body_color, limb_width * 1.5)
			draw_line(knee_r, foot_r, body_color, limb_width * 1.2)

# ── Scale 10: Vehicle/Structure ─────────────────────────────────

func _draw_vehicle(center: Vector2, r: float, size_cat: int, color: Color, _phase: float) -> void:
	match size_cat:
		0:
			# Car — rectangle body + 4 wheels + windshield
			var hw: float = r * 0.65
			var hh: float = r * 0.3
			var body: PackedVector2Array = PackedVector2Array([
				center + Vector2(-hw, -hh), center + Vector2(hw, -hh),
				center + Vector2(hw, hh), center + Vector2(-hw, hh),
			])
			draw_colored_polygon(body, Color(color.r, color.g, color.b, 0.7))
			# Windshield
			draw_line(center + Vector2(-hw * 0.2, -hh), center + Vector2(hw * 0.1, -hh), Color(0.6, 0.8, 1.0, 0.5), 2.0)
			# Wheels
			var wheel_r: float = maxf(r * 0.12, 2.0)
			draw_circle(center + Vector2(-hw * 0.6, hh), wheel_r, Color(0.15, 0.15, 0.15, 0.9))
			draw_circle(center + Vector2(hw * 0.6, hh), wheel_r, Color(0.15, 0.15, 0.15, 0.9))
			draw_circle(center + Vector2(-hw * 0.6, -hh), wheel_r, Color(0.15, 0.15, 0.15, 0.9))
			draw_circle(center + Vector2(hw * 0.6, -hh), wheel_r, Color(0.15, 0.15, 0.15, 0.9))
		1:
			# Bus — longer rectangle + 6 wheels + windows
			var hw: float = r * 0.8
			var hh: float = r * 0.3
			var body: PackedVector2Array = PackedVector2Array([
				center + Vector2(-hw, -hh), center + Vector2(hw, -hh),
				center + Vector2(hw, hh), center + Vector2(-hw, hh),
			])
			draw_colored_polygon(body, Color(color.r, color.g, color.b, 0.7))
			# Windows
			for i in range(5):
				var wx: float = -hw * 0.7 + float(i) * hw * 0.35
				draw_circle(center + Vector2(wx, -hh * 0.3), maxf(r * 0.06, 1.5), Color(0.6, 0.8, 1.0, 0.6))
			# 6 wheels
			var wr: float = maxf(r * 0.1, 2.0)
			for i in range(3):
				var wx: float = -hw * 0.65 + float(i) * hw * 0.65
				draw_circle(center + Vector2(wx, hh), wr, Color(0.15, 0.15, 0.15, 0.9))
				draw_circle(center + Vector2(wx, -hh), wr, Color(0.15, 0.15, 0.15, 0.9))
		2, _:
			# Building — tall rectangle + window grid + door
			var hw: float = r * 0.4
			var hh: float = r * 0.85
			var body: PackedVector2Array = PackedVector2Array([
				center + Vector2(-hw, -hh), center + Vector2(hw, -hh),
				center + Vector2(hw, hh), center + Vector2(-hw, hh),
			])
			draw_colored_polygon(body, Color(color.r * 0.5 + 0.25, color.g * 0.5 + 0.25, color.b * 0.5 + 0.25, 0.7))
			draw_polyline(PackedVector2Array([
				center + Vector2(-hw, -hh), center + Vector2(hw, -hh),
				center + Vector2(hw, hh), center + Vector2(-hw, hh), center + Vector2(-hw, -hh),
			]), Color(color.r, color.g, color.b, 0.5), 1.0)
			# Window grid
			for row in range(4):
				for col in range(3):
					var wx: float = -hw * 0.6 + float(col) * hw * 0.6
					var wy: float = -hh * 0.8 + float(row) * hh * 0.4
					draw_circle(center + Vector2(wx, wy), maxf(r * 0.04, 1.0), Color(1.0, 1.0, 0.7, 0.6))
			# Door
			var door: PackedVector2Array = PackedVector2Array([
				center + Vector2(-hw * 0.25, hh * 0.5),
				center + Vector2(hw * 0.25, hh * 0.5),
				center + Vector2(hw * 0.25, hh),
				center + Vector2(-hw * 0.25, hh),
			])
			draw_colored_polygon(door, Color(0.3, 0.2, 0.15, 0.7))

# ── Scale 11: City ─────────────────────────────────────────────

func _draw_city(center: Vector2, r: float, size_cat: int, color: Color, _phase: float) -> void:
	match size_cat:
		0:
			# City block — cluster of small rectangles
			for i in range(5):
				var bx: float = (randf_range(-0.5, 0.5) if i > 0 else 0.0)  # deterministic via index
				bx = (float(i) - 2.0) * r * 0.25
				var by: float = (float(i % 3) - 1.0) * r * 0.2
				var bw: float = r * 0.15
				var bh: float = r * (0.15 + float(i % 3) * 0.1)
				var rect: PackedVector2Array = PackedVector2Array([
					center + Vector2(bx - bw, by - bh),
					center + Vector2(bx + bw, by - bh),
					center + Vector2(bx + bw, by + bh),
					center + Vector2(bx - bw, by + bh),
				])
				draw_colored_polygon(rect, Color(color.r * 0.4 + 0.2, color.g * 0.4 + 0.2, color.b * 0.4 + 0.2, 0.6))
		1:
			# Stadium — large oval + inner oval + seating lines
			draw_arc(center, r * 0.75, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.6), 2.0)
			draw_arc(center, r * 0.5, 0.0, TAU, 20, Color(color.r, color.g, color.b, 0.4), 1.5)
			draw_arc(center, r * 0.62, 0.0, TAU, 20, Color(color.r, color.g, color.b, 0.2), 1.0)
			# Seating lines
			for i in range(8):
				var a: float = TAU / 8.0 * float(i)
				draw_line(center + Vector2(cos(a), sin(a)) * r * 0.5, center + Vector2(cos(a), sin(a)) * r * 0.75, Color(color.r, color.g, color.b, 0.3), 1.0)
		2, _:
			# Airport — terminal rectangle + 2 runway lines
			var tw: float = r * 0.5
			var th: float = r * 0.25
			var terminal: PackedVector2Array = PackedVector2Array([
				center + Vector2(-tw, -th), center + Vector2(tw, -th),
				center + Vector2(tw, th), center + Vector2(-tw, th),
			])
			draw_colored_polygon(terminal, Color(color.r * 0.4 + 0.3, color.g * 0.4 + 0.3, color.b * 0.4 + 0.3, 0.6))
			# Runways
			draw_line(center + Vector2(-tw, 0), center + Vector2(-r * 0.9, -r * 0.5), Color(0.4, 0.4, 0.4, 0.7), 3.0)
			draw_line(center + Vector2(tw, 0), center + Vector2(r * 0.9, -r * 0.4), Color(0.4, 0.4, 0.4, 0.7), 3.0)
			# Runway markings
			for i in range(4):
				var t: float = float(i + 1) / 5.0
				var p1: Vector2 = center + Vector2(-tw, 0).lerp(Vector2(-r * 0.9, -r * 0.5), t)
				draw_circle(p1, maxf(r * 0.02, 1.0), Color(1.0, 1.0, 1.0, 0.5))

# ── Scale 12: Geographic ───────────────────────────────────────

func _draw_geographic(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	match size_cat:
		0:
			# Island — irregular polygon
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var a: float = TAU / 6.0 * float(i) + phase * 0.1
				var dist: float = r * (0.5 + 0.2 * sin(float(i) * 2.3 + phase))
				pts.append(center + Vector2(cos(a), sin(a)) * dist)
			draw_colored_polygon(pts, Color(0.2, 0.6, 0.25, 0.7))
			# Beach outline
			draw_polyline(pts, Color(0.9, 0.85, 0.6, 0.5), 1.5)
			# Close the polyline
			draw_line(pts[pts.size() - 1], pts[0], Color(0.9, 0.85, 0.6, 0.5), 1.5)
		1:
			# Mountain range — jagged skyline + snow caps
			var pts: PackedVector2Array = PackedVector2Array()
			pts.append(center + Vector2(-r * 0.9, r * 0.4))
			var peaks: int = 5
			for i in range(peaks):
				var x: float = -r * 0.8 + float(i) * r * 0.4
				var h: float = r * (0.3 + 0.3 * sin(float(i) * 1.7 + phase))
				pts.append(center + Vector2(x, -h))
				if i < peaks - 1:
					pts.append(center + Vector2(x + r * 0.2, -h * 0.3))
			pts.append(center + Vector2(r * 0.9, r * 0.4))
			draw_polyline(pts, Color(color.r, color.g, color.b, 0.7), 2.0)
			# Snow caps
			for i in range(peaks):
				var x: float = -r * 0.8 + float(i) * r * 0.4
				var h: float = r * (0.3 + 0.3 * sin(float(i) * 1.7 + phase))
				var peak_p: Vector2 = center + Vector2(x, -h)
				var snow: PackedVector2Array = PackedVector2Array([
					peak_p,
					peak_p + Vector2(-r * 0.08, r * 0.1),
					peak_p + Vector2(r * 0.08, r * 0.1),
				])
				draw_colored_polygon(snow, Color(1.0, 1.0, 1.0, 0.6))
		2, _:
			# Continent — large irregular polygon + rivers
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var a: float = TAU / 10.0 * float(i) + phase * 0.05
				var dist: float = r * (0.6 + 0.25 * sin(float(i) * 1.9 + phase * 0.3))
				pts.append(center + Vector2(cos(a), sin(a)) * dist)
			draw_colored_polygon(pts, Color(0.2, 0.55, 0.2, 0.65))
			draw_polyline(pts, Color(0.15, 0.4, 0.15, 0.5), 1.5)
			draw_line(pts[pts.size() - 1], pts[0], Color(0.15, 0.4, 0.15, 0.5), 1.5)
			# Rivers
			var river_pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var t: float = float(i) / 5.0
				var x: float = lerpf(-r * 0.3, r * 0.4, t)
				var y: float = lerpf(-r * 0.2, r * 0.3, t) + sin(t * TAU + phase) * r * 0.1
				river_pts.append(center + Vector2(x, y))
			draw_polyline(river_pts, Color(0.2, 0.4, 0.9, 0.5), 1.5)

# ── Scale 13: Planetary ────────────────────────────────────────

func _draw_planetary(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	match size_cat:
		0:
			# Moon — gray circle + craters
			draw_circle(center, r * 0.7, Color(0.6, 0.6, 0.6, 0.75))
			draw_circle(center, r * 0.4, Color(0.7, 0.7, 0.7, 0.3))
			# Craters
			for i in range(4):
				var a: float = float(i) * 1.8 + phase
				var d: float = r * (0.2 + float(i % 3) * 0.12)
				var cp: Vector2 = center + Vector2(cos(a), sin(a)) * d
				draw_arc(cp, maxf(r * 0.08, 1.5), 0.0, TAU, 8, Color(0.4, 0.4, 0.4, 0.5), 1.0)
		1:
			# Rocky planet — circle + crack lines + atmosphere
			draw_circle(center, r * 0.65, Color(color.r * 0.6 + 0.2, color.g * 0.5 + 0.15, color.b * 0.4 + 0.1, 0.8))
			draw_circle(center, r * 0.4, Color(color.r * 0.4 + 0.3, color.g * 0.4 + 0.25, color.b * 0.3 + 0.15, 0.4))
			# Surface cracks
			for i in range(3):
				var a: float = float(i) * 2.1 + phase
				var p1: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.15
				var p2: Vector2 = center + Vector2(cos(a + 0.5), sin(a + 0.5)) * r * 0.55
				draw_line(p1, p2, Color(0.3, 0.2, 0.15, 0.4), 1.0)
			# Thin atmosphere
			draw_arc(center, r * 0.72, 0.0, TAU, 24, Color(0.5, 0.7, 1.0, 0.15), 2.0)
		2, _:
			# Gas giant — circle + bands + orbiting moons
			draw_circle(center, r * 0.6, Color(color.r, color.g, color.b, 0.7))
			# Horizontal band arcs
			for i in range(3):
				var y_off: float = (float(i) - 1.0) * r * 0.2
				var band_r: float = r * 0.58 * cos(asin(clampf(y_off / (r * 0.6), -1.0, 1.0)))
				if band_r > 0:
					draw_line(center + Vector2(-band_r, y_off), center + Vector2(band_r, y_off), Color(color.r * 0.7, color.g * 0.7, color.b * 0.5, 0.4), maxf(r * 0.06, 1.5))
			# Orbiting moons
			for i in range(2):
				var moon_a: float = time * (0.8 + float(i) * 0.3) + float(i) * PI + phase
				var moon_d: float = r * (0.8 + float(i) * 0.15)
				var moon_p: Vector2 = center + Vector2(cos(moon_a), sin(moon_a) * 0.3) * moon_d
				draw_circle(moon_p, maxf(r * 0.07, 1.5), Color(0.7, 0.7, 0.7, 0.7))

# ── Scale 14: Stellar ──────────────────────────────────────────

func _draw_stellar(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	var glow_pulse: float = 0.85 + 0.15 * sin(time * 2.0 + phase)
	match size_cat:
		0:
			# Red dwarf — small dim reddish circle + soft glow
			draw_circle(center, r * 0.8, Color(0.9, 0.2, 0.1, 0.12 * glow_pulse))
			draw_circle(center, r * 0.5, Color(0.9, 0.25, 0.1, 0.25 * glow_pulse))
			draw_circle(center, r * 0.3, Color(1.0, 0.35, 0.15, 0.7 * glow_pulse))
			draw_circle(center, r * 0.15, Color(1.0, 0.6, 0.4, 0.5))
		1:
			# Yellow star — circle + 8 flare lines + corona
			draw_circle(center, r * 0.7, Color(1.0, 0.95, 0.4, 0.1 * glow_pulse))
			draw_circle(center, r * 0.45, Color(1.0, 0.9, 0.3, 0.4 * glow_pulse))
			draw_circle(center, r * 0.3, Color(1.0, 1.0, 0.7, 0.8 * glow_pulse))
			# 8 flare lines
			for i in range(8):
				var a: float = TAU / 8.0 * float(i) + time * 0.2
				var flare_start: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.35
				var flare_end: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.85
				draw_line(flare_start, flare_end, Color(1.0, 0.9, 0.3, 0.3 * glow_pulse), 1.5)
			# Corona arc
			draw_arc(center, r * 0.55, 0.0, TAU, 20, Color(1.0, 0.85, 0.2, 0.15), 1.5)
		2, _:
			# Blue supergiant — large bright circle + 12 flares + solar wind
			draw_circle(center, r * 0.9, Color(0.5, 0.6, 1.0, 0.08 * glow_pulse))
			draw_circle(center, r * 0.6, Color(0.6, 0.7, 1.0, 0.25 * glow_pulse))
			draw_circle(center, r * 0.4, Color(0.7, 0.8, 1.0, 0.7 * glow_pulse))
			draw_circle(center, r * 0.25, Color(0.9, 0.95, 1.0, 0.9))
			# 12 flare lines
			for i in range(12):
				var a: float = TAU / 12.0 * float(i) + time * 0.15
				var len_mult: float = 0.7 + 0.3 * sin(float(i) * 2.3 + time)
				var flare_start: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.42
				var flare_end: Vector2 = center + Vector2(cos(a), sin(a)) * r * len_mult
				draw_line(flare_start, flare_end, Color(0.6, 0.7, 1.0, 0.35 * glow_pulse), 2.0)
			# Solar wind arcs
			for i in range(3):
				var arc_start: float = float(i) * TAU / 3.0 + time * 0.3
				draw_arc(center, r * 0.75, arc_start, arc_start + PI * 0.4, 8, Color(0.5, 0.6, 1.0, 0.12), 1.5)

# ── Scale 15: Galactic ─────────────────────────────────────────

func _draw_galactic(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	match size_cat:
		0:
			# Star cluster — 15-20 tiny dots
			for i in range(18):
				var a: float = float(i) * 2.39996 + phase  # golden angle
				var d: float = r * 0.15 + r * 0.5 * (float(i) / 18.0)
				var p: Vector2 = center + Vector2(cos(a), sin(a)) * d
				var brightness: float = 0.4 + 0.5 * sin(float(i) * 1.7 + time * 2.0)
				draw_circle(p, maxf(r * 0.04, 1.0), Color(1.0, 1.0, 0.9, brightness * 0.8))
		1:
			# Nebula — large semi-transparent irregular polygon
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(12):
				var a: float = TAU / 12.0 * float(i) + phase * 0.1
				var d: float = r * (0.5 + 0.3 * sin(float(i) * 1.5 + phase))
				pts.append(center + Vector2(cos(a), sin(a)) * d)
			draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.15))
			# Inner glow layers
			var inner_pts: PackedVector2Array = PackedVector2Array()
			for i in range(8):
				var a: float = TAU / 8.0 * float(i) + phase * 0.2
				var d: float = r * (0.25 + 0.15 * sin(float(i) * 2.0 + phase))
				inner_pts.append(center + Vector2(cos(a), sin(a)) * d)
			draw_colored_polygon(inner_pts, Color(color.r * 0.5 + 0.5, color.g * 0.5 + 0.5, color.b * 0.5 + 0.5, 0.12))
			# Embedded stars
			for i in range(6):
				var a: float = float(i) * 1.1 + phase
				var d: float = r * 0.3 * sin(float(i) * 0.7)
				draw_circle(center + Vector2(cos(a), sin(a)) * absf(d), maxf(r * 0.03, 1.0), Color(1.0, 1.0, 1.0, 0.5))
		2, _:
			# Spiral galaxy — center + 2 arms + scattered stars
			# Core
			draw_circle(center, r * 0.2, Color(1.0, 0.95, 0.7, 0.6))
			draw_circle(center, r * 0.35, Color(1.0, 0.9, 0.6, 0.15))
			# Spiral arms
			for arm in range(2):
				var arm_pts: PackedVector2Array = PackedVector2Array()
				var base_a: float = float(arm) * PI + time * 0.1
				for i in range(20):
					var t: float = float(i) / 19.0
					var spiral_a: float = base_a + t * TAU * 0.8
					var spiral_r: float = r * (0.15 + t * 0.65)
					arm_pts.append(center + Vector2(cos(spiral_a), sin(spiral_a)) * spiral_r)
				draw_polyline(arm_pts, Color(color.r, color.g, color.b, 0.35), maxf(r * 0.06, 1.5))
			# Scattered star dots
			for i in range(12):
				var a: float = float(i) * 2.39996 + phase
				var d: float = r * (0.2 + 0.55 * (float(i) / 12.0))
				var sp: Vector2 = center + Vector2(cos(a + time * 0.05), sin(a + time * 0.05)) * d
				draw_circle(sp, maxf(r * 0.025, 1.0), Color(1.0, 1.0, 0.95, 0.4))

# ── Scale 16-17: Cosmic/Universal ──────────────────────────────

func _draw_cosmic(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
	# Cosmic filament — bright line with node circles
	var node_count: int = 5 + size_cat * 3
	var filament_pts: PackedVector2Array = PackedVector2Array()
	for i in range(node_count):
		var t: float = float(i) / float(node_count - 1) - 0.5
		var x: float = t * r * 2.0
		var y: float = sin(t * PI * 2.0 + phase * 0.5) * r * 0.35 + cos(t * PI * 3.0 + time * 0.5) * r * 0.15
		filament_pts.append(center + Vector2(x, y))
	# Filament glow
	draw_polyline(filament_pts, Color(color.r, color.g, color.b, 0.12), maxf(r * 0.15, 3.0))
	draw_polyline(filament_pts, Color(color.r, color.g, color.b, 0.35), maxf(r * 0.06, 1.5))
	# Node circles
	for i in range(node_count):
		var node_r: float = maxf(r * (0.04 + 0.03 * sin(float(i) * 1.5)), 1.5)
		draw_circle(filament_pts[i], node_r, Color(color.r, color.g, color.b, 0.55))
		draw_circle(filament_pts[i], node_r * 2.0, Color(color.r, color.g, color.b, 0.1))
	# Scattered distant galaxy dots
	for i in range(8):
		var a: float = float(i) * 2.39996 + phase
		var d: float = r * 0.6 * (0.3 + 0.7 * (float(i) / 8.0))
		var brightness: float = 0.15 + 0.15 * sin(time * 1.5 + float(i) * 2.0)
		draw_circle(center + Vector2(cos(a), sin(a)) * d, maxf(r * 0.02, 1.0), Color(1.0, 1.0, 1.0, brightness))

# ── Toxic entity ────────────────────────────────────────────────

func _draw_toxic(center: Vector2, radius: float, _color: Color) -> void:
	var pulse: float = 0.7 + 0.3 * sin(time * 4.0)
	draw_circle(center, radius * 1.8, Color(0.5, 0.0, 0.7, 0.04 * pulse))
	draw_circle(center, radius * 1.5, Color(0.5, 0.0, 0.8, 0.08 * pulse))
	draw_circle(center, radius * 1.3, Color(0.5, 0.0, 0.8, 0.14 * pulse))
	draw_circle(center, radius, Color(0.45, 0.0, 0.75, 0.85))
	draw_circle(center, radius * 0.5, Color(0.7, 0.0, 1.0, 0.9))
	var x_size: float = radius * 0.35
	draw_line(center + Vector2(-x_size, -x_size), center + Vector2(x_size, x_size), Color(1.0, 0.5, 1.0, 0.9), 2.0)
	draw_line(center + Vector2(x_size, -x_size), center + Vector2(-x_size, x_size), Color(1.0, 0.5, 1.0, 0.9), 2.0)

# ── Fallback: original circle-based drawing ─────────────────────

func _draw_fallback(center: Vector2, radius: float, color: Color, etype: int, phase: float) -> void:
	var soft_pulse: float = 1.0 + 0.06 * sin(time * 3.0 + phase)
	var r: float = radius * soft_pulse
	draw_circle(center, r * 1.6, Color(color.r, color.g, color.b, 0.04))
	draw_circle(center, r * 1.3, Color(color.r, color.g, color.b, 0.1))
	draw_circle(center, r, Color(color.r * 0.5 + 0.15, color.g * 0.5 + 0.15, color.b * 0.5 + 0.15, 0.9))
	draw_circle(center, r * 0.5, color)
	draw_circle(center + Vector2(-r * 0.2, -r * 0.2), r * 0.15, Color(1.0, 1.0, 1.0, 0.4))
