extends Node2D

# Scale-aware entity drawing:
# Scale 0-1: Quantum (flickering dots, quark triplets, nuclei)
# Scale 2: Atomic (nucleus + electron orbits)
# Scale 3: Molecular (H2, H2O, benzene)
# Scale 4: Cellular (cells, organelles, neurons)
# Scale 5+: Human/Animal (stick figures, detailed humans)
# Also handles toxic entities and per-type visuals as fallback

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
	# Categorize entity size relative to scale
	var thresholds: Array[float] = [12.0, 22.0]  # small < 12, medium < 22, large >= 22
	match scale_idx:
		0, 1:
			thresholds = [8.0, 16.0]
		2:
			thresholds = [10.0, 20.0]
		3:
			thresholds = [12.0, 24.0]
		4:
			thresholds = [15.0, 28.0]
		_:
			thresholds = [18.0, 32.0]

	if radius < thresholds[0]:
		return 0
	elif radius < thresholds[1]:
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
			_draw_cellular(center, radius, size_cat, color, phase)
		_:
			if scale_idx >= 5:
				_draw_human(center, radius, size_cat, color, phase)
			else:
				_draw_fallback(center, radius, color, etype, phase)

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

# ── Scale 4: Cellular ───────────────────────────────────────────

func _draw_cellular(center: Vector2, r: float, size_cat: int, color: Color, phase: float) -> void:
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

# ── Scale 5+: Human/Animal ──────────────────────────────────────

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
