extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D
@onready var entity_spawner = $EntitySpawner
@onready var scale_manager = $ScaleManager
@onready var hud = $HUD
@onready var game_over_screen = $GameOverScreen
@onready var background: ColorRect = $BackgroundLayer/Background
@onready var scale_label_flash: Label = $UIOverlay/ScaleTransitionLabel
@onready var screen_flash_rect: ColorRect = $UIOverlay/ScreenFlashRect

var is_game_over: bool = false

# ── Parallax star system (3 layers) ──────────────────────────────
# Layer 0: distant (tiny, slow), Layer 1: mid, Layer 2: near (larger, fast)
const STAR_COUNTS: Array[int] = [80, 50, 30]
const STAR_PARALLAX: Array[float] = [0.03, 0.08, 0.18]
const STAR_SIZE_MIN: Array[float] = [0.3, 0.8, 1.5]
const STAR_SIZE_MAX: Array[float] = [0.8, 1.8, 3.0]
const STAR_BRIGHTNESS_MIN: Array[float] = [0.15, 0.25, 0.4]
const STAR_BRIGHTNESS_MAX: Array[float] = [0.4, 0.65, 1.0]
const STAR_COLORS: Array[Color] = [
	Color(0.6, 0.65, 0.9),   # Distant: cool blue-white
	Color(0.75, 0.8, 1.0),   # Mid: white-blue
	Color(0.9, 0.92, 1.0),   # Near: bright white
]
const STAR_FIELD_SIZE: float = 2800.0

var star_layers: Array[Array] = [[], [], []]  # Each: Array of {pos, size, brightness, phase}

# Shooting star system
var shooting_stars: Array[Dictionary] = []
var shooting_star_timer: float = 0.0
const SHOOTING_STAR_INTERVAL_MIN: float = 8.0
const SHOOTING_STAR_INTERVAL_MAX: float = 15.0

# Nebula wisps
var nebula_wisps: Array[Dictionary] = []

# Floating text pool
var floating_texts: Array[Label] = []
const FLOAT_TEXT_POOL_SIZE: int = 15

# Afterimage system — drawn in _draw(), no extra nodes
var afterimages: Array[Dictionary] = []

# Shockwave system — expanding rings drawn in _draw()
var shockwaves: Array[Dictionary] = []

# Death particle system
var death_particles: Array[Dictionary] = []

# Entity sparkle trails
var sparkle_trails: Array[Dictionary] = []

# Background colors per scale — deep space feel (NOT pure black)
const BG_COLORS: Array[Color] = [
	Color(0.020, 0.020, 0.063),   # Subatomic: deep blue-black
	Color(0.015, 0.040, 0.035),   # Atomic: dark teal
	Color(0.040, 0.015, 0.050),   # Molecular: dark purple
	Color(0.035, 0.015, 0.028),   # Cellular: dark rose
	Color(0.018, 0.018, 0.050),   # Planetary: deep indigo
]

# ── Upgrade selection UI ─────────────────────────────────────────
var upgrade_overlay: ColorRect = null
var upgrade_cards: Array[Panel] = []
var upgrade_container: HBoxContainer = null
var upgrade_title_label: Label = null
var is_upgrade_active: bool = false

func _ready() -> void:
	GameData.reset_run()

	# Wire scale manager
	scale_manager.camera = camera
	scale_manager.entity_spawner = entity_spawner
	scale_manager.transition_started.connect(_on_transition_started)
	scale_manager.transition_finished.connect(_on_transition_finished)
	scale_manager.upgrade_selection_requested.connect(_on_upgrade_selection_requested)

	# Wire player
	player.scale_manager = scale_manager
	player.entity_spawner = entity_spawner
	player.eaten_entity.connect(_on_player_eaten)
	player.player_died_signal.connect(_on_player_died)

	# Wire HUD
	hud.set_player(player)

	# Wire entity spawner
	entity_spawner.player = player

	# Wire camera to follow player with lag
	camera.target = player

	set_process(true)

	game_over_screen.hide()

	if scale_label_flash:
		scale_label_flash.modulate.a = 0.0

	if screen_flash_rect:
		screen_flash_rect.modulate.a = 0.0

	_update_background()
	_generate_stars()
	_generate_nebula_wisps()
	_create_floating_text_pool()
	_build_upgrade_ui()
	shooting_star_timer = randf_range(SHOOTING_STAR_INTERVAL_MIN, SHOOTING_STAR_INTERVAL_MAX)

func _process(delta: float) -> void:
	if is_game_over:
		return

	_update_afterimages(delta)
	_update_shockwaves(delta)
	_update_shooting_stars(delta)
	_update_nebula_wisps(delta)
	_update_death_particles(delta)
	_update_sparkle_trails(delta)
	_update_background()

# ── Upgrade UI construction ───────────────────────────────────────

func _build_upgrade_ui() -> void:
	var ui_layer: CanvasLayer = $UIOverlay

	# Dark overlay background
	upgrade_overlay = ColorRect.new()
	upgrade_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	upgrade_overlay.anchors_preset = 15  # Full rect
	upgrade_overlay.anchor_right = 1.0
	upgrade_overlay.anchor_bottom = 1.0
	upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade_overlay.visible = false
	ui_layer.add_child(upgrade_overlay)

	# VBox to hold title + cards
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchors_preset = 8  # Center
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -450.0
	vbox.offset_top = -200.0
	vbox.offset_right = 450.0
	vbox.offset_bottom = 200.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 30)
	upgrade_overlay.add_child(vbox)

	# Title
	upgrade_title_label = Label.new()
	upgrade_title_label.text = "CHOOSE AN UPGRADE"
	upgrade_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title_label.add_theme_font_size_override("font_size", 36)
	upgrade_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(upgrade_title_label)

	# Card container
	upgrade_container = HBoxContainer.new()
	upgrade_container.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_container.add_theme_constant_override("separation", 20)
	vbox.add_child(upgrade_container)

func _show_upgrade_selection() -> void:
	var upgrades: Array[Dictionary] = GameData.get_random_upgrades(3)
	if upgrades.is_empty():
		return  # No upgrades available

	is_upgrade_active = true

	# Clear old cards
	for card in upgrade_cards:
		if is_instance_valid(card):
			card.queue_free()
	upgrade_cards.clear()

	# Update title color to current scale
	if upgrade_title_label:
		upgrade_title_label.add_theme_color_override("font_color", GameData.get_scale_color().lightened(0.3))

	# Create cards
	for i in range(upgrades.size()):
		var upg: Dictionary = upgrades[i]
		var card: Panel = _create_upgrade_card(upg, i)
		upgrade_container.add_child(card)
		upgrade_cards.append(card)

	upgrade_overlay.visible = true
	upgrade_overlay.modulate.a = 0.0

	# Animate in
	var tween: Tween = create_tween()
	tween.tween_property(upgrade_overlay, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# Pause the game tree (but keep UI responding)
	get_tree().paused = true
	upgrade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS

func _create_upgrade_card(upg: Dictionary, _index: int) -> Panel:
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(250, 160)
	card.process_mode = Node.PROCESS_MODE_ALWAYS

	# Card background style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var sc: Color = GameData.get_scale_color()
	style.bg_color = Color(sc.r * 0.15, sc.g * 0.15, sc.b * 0.15, 0.9)
	style.border_color = Color(sc.r * 0.5, sc.g * 0.5, sc.b * 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)

	# Inner VBox
	var inner: VBoxContainer = VBoxContainer.new()
	inner.anchors_preset = 15
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.offset_left = 16.0
	inner.offset_top = 16.0
	inner.offset_right = -16.0
	inner.offset_bottom = -16.0
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	# Name label
	var name_label: Label = Label.new()
	name_label.text = upg.name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", sc.lightened(0.4))
	inner.add_child(name_label)

	# Description label
	var desc_label: Label = Label.new()
	desc_label.text = upg.desc
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc_label)

	# Stack count
	var current_stacks: int = GameData.get_upgrade_count(upg.id)
	if upg.max_stacks > 1:
		var stack_label: Label = Label.new()
		stack_label.text = "[%d / %d]" % [current_stacks, upg.max_stacks]
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack_label.add_theme_font_size_override("font_size", 12)
		stack_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.7))
		inner.add_child(stack_label)

	# Select button
	var btn: Button = Button.new()
	btn.text = "SELECT"
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(sc.r * 0.3, sc.g * 0.3, sc.b * 0.3, 0.9)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(sc.r * 0.5, sc.g * 0.5, sc.b * 0.5, 0.95)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_upgrade_selected.bind(upg.id))
	inner.add_child(btn)

	return card

func _on_upgrade_selected(upgrade_id: String) -> void:
	if not is_upgrade_active:
		return
	is_upgrade_active = false

	# Apply upgrade to player
	player.apply_upgrade(upgrade_id)

	# Animate out
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(upgrade_overlay, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(_hide_upgrade_ui)

func _hide_upgrade_ui() -> void:
	upgrade_overlay.visible = false
	get_tree().paused = false

	# Flash to confirm selection
	screen_flash(GameData.get_scale_color() * Color(1, 1, 1, 0.3), 0.2)

func _on_upgrade_selection_requested() -> void:
	# Short delay before showing upgrades
	await get_tree().create_timer(0.5).timeout
	_show_upgrade_selection()

# ── Afterimage system ──────────────────────────────────────────────

func add_afterimage(pos: Vector2, radius: float, color: Color) -> void:
	afterimages.append({
		"position": pos,
		"radius": radius,
		"color": color,
		"timer": 0.3,
		"lifetime": 0.3,
	})

func _update_afterimages(delta: float) -> void:
	for i in range(afterimages.size() - 1, -1, -1):
		afterimages[i].timer -= delta
		if afterimages[i].timer <= 0.0:
			afterimages.remove_at(i)

# ── Shockwave system ──────────────────────────────────────────────

func spawn_shockwave(pos: Vector2) -> void:
	shockwaves.append({
		"position": pos,
		"radius": 0.0,
		"max_radius": 200.0,
		"speed": 600.0,
	})

func _update_shockwaves(delta: float) -> void:
	for i in range(shockwaves.size() - 1, -1, -1):
		shockwaves[i].radius += shockwaves[i].speed * delta
		if shockwaves[i].radius >= shockwaves[i].max_radius:
			shockwaves.remove_at(i)

# ── Death particle system ─────────────────────────────────────────

func spawn_death_particles(pos: Vector2, color: Color, radius: float) -> void:
	var count: int = randi_range(4, 6)
	for i in range(count):
		var angle: float = randf() * TAU
		var speed: float = randf_range(80.0, 220.0)
		var frag_size: float = radius * randf_range(0.15, 0.35)
		death_particles.append({
			"position": pos,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"color": color,
			"size": frag_size,
			"timer": randf_range(0.4, 0.8),
			"lifetime": 0.8,
			"rotation": randf() * TAU,
			"rot_speed": randf_range(-8.0, 8.0),
		})

func _update_death_particles(delta: float) -> void:
	for i in range(death_particles.size() - 1, -1, -1):
		var p: Dictionary = death_particles[i]
		p.timer -= delta
		p.position += p.velocity * delta
		p.velocity *= 0.96  # drag
		p.rotation += p.rot_speed * delta
		p.size *= 0.98  # shrink
		if p.timer <= 0.0:
			death_particles.remove_at(i)

# ── Sparkle trail system ──────────────────────────────────────────

func add_sparkle(pos: Vector2, color: Color) -> void:
	sparkle_trails.append({
		"position": pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
		"color": color,
		"size": randf_range(1.0, 2.5),
		"timer": randf_range(0.15, 0.3),
		"lifetime": 0.3,
	})

func _update_sparkle_trails(delta: float) -> void:
	for i in range(sparkle_trails.size() - 1, -1, -1):
		sparkle_trails[i].timer -= delta
		if sparkle_trails[i].timer <= 0.0:
			sparkle_trails.remove_at(i)

# ── Drawing ────────────────────────────────────────────────────────

func _draw() -> void:
	var cam_pos: Vector2 = camera.global_position if camera else Vector2.ZERO

	# Draw nebula wisps (behind stars)
	for neb in nebula_wisps:
		var npos: Vector2 = neb.position - cam_pos * 0.02
		# Wrap nebula
		npos.x = fmod(npos.x + STAR_FIELD_SIZE, STAR_FIELD_SIZE * 2.0) - STAR_FIELD_SIZE + cam_pos.x
		npos.y = fmod(npos.y + STAR_FIELD_SIZE, STAR_FIELD_SIZE * 2.0) - STAR_FIELD_SIZE + cam_pos.y
		var nc: Color = neb.color
		var breath: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.0003 + neb.phase)
		# Draw as layered soft circles for nebula cloud effect
		var nr: float = neb.radius
		draw_circle(npos, nr * 1.2, Color(nc.r, nc.g, nc.b, 0.012 * breath))
		draw_circle(npos, nr, Color(nc.r, nc.g, nc.b, 0.025 * breath))
		draw_circle(npos, nr * 0.7, Color(nc.r, nc.g, nc.b, 0.04 * breath))
		draw_circle(npos, nr * 0.4, Color(nc.r, nc.g, nc.b, 0.05 * breath))

	# Draw parallax stars (3 layers: distant, mid, near)
	for layer_idx in range(3):
		var parallax: float = STAR_PARALLAX[layer_idx]
		var base_color: Color = STAR_COLORS[layer_idx]
		for star in star_layers[layer_idx]:
			var star_pos: Vector2 = star.pos - cam_pos * parallax
			# Wrap stars
			star_pos.x = fmod(star_pos.x + STAR_FIELD_SIZE, STAR_FIELD_SIZE * 2.0) - STAR_FIELD_SIZE + cam_pos.x
			star_pos.y = fmod(star_pos.y + STAR_FIELD_SIZE, STAR_FIELD_SIZE * 2.0) - STAR_FIELD_SIZE + cam_pos.y

			# Twinkle: random-phase flicker
			var twinkle: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.002 * star.twinkle_speed + star.phase)
			var brightness: float = star.brightness * twinkle
			var size: float = star.size * (0.85 + 0.15 * twinkle)

			var sc: Color = Color(base_color.r, base_color.g, base_color.b, brightness)
			# Near stars get a tiny glow halo
			if layer_idx == 2:
				draw_circle(star_pos, size * 2.5, Color(sc.r, sc.g, sc.b, brightness * 0.08))
			draw_circle(star_pos, size, sc)

	# Draw shooting stars
	for ss in shooting_stars:
		var t: float = ss.timer / ss.lifetime
		var head_alpha: float = t
		var head_pos: Vector2 = ss.position
		# Draw streak tail
		var tail_len: int = 8
		for i in range(tail_len):
			var frac: float = float(i) / float(tail_len)
			var tail_pos: Vector2 = head_pos - ss.velocity.normalized() * (frac * ss.trail_length)
			var tail_alpha: float = head_alpha * (1.0 - frac) * 0.6
			var tail_size: float = ss.size * (1.0 - frac * 0.7)
			draw_circle(tail_pos, tail_size, Color(0.9, 0.95, 1.0, tail_alpha))
		# Bright head
		draw_circle(head_pos, ss.size * 1.3, Color(1.0, 1.0, 1.0, head_alpha))

	# Draw sparkle trails
	for sp in sparkle_trails:
		var t: float = sp.timer / sp.lifetime
		var sc: Color = sp.color
		draw_circle(sp.position, sp.size * t, Color(sc.r, sc.g, sc.b, t * 0.7))
		draw_circle(sp.position, sp.size * t * 0.5, Color(1.0, 1.0, 1.0, t * 0.5))

	# Draw death particles
	for dp in death_particles:
		var t: float = dp.timer / dp.lifetime
		var dc: Color = dp.color
		# Draw as small rotated fragment (diamond shape using two triangles via circles for simplicity)
		draw_circle(dp.position, dp.size * t, Color(dc.r, dc.g, dc.b, t * 0.9))
		draw_circle(dp.position, dp.size * t * 0.5, Color(1.0, 1.0, 1.0, t * 0.6))
		# Tiny glow around fragment
		draw_circle(dp.position, dp.size * t * 2.0, Color(dc.r, dc.g, dc.b, t * 0.15))

	# Draw afterimages (dash ghosts)
	for ai in afterimages:
		var c: Color = ai.color
		var t: float = ai.timer / ai.lifetime
		var a: float = t * 0.6
		var r: float = ai.radius
		draw_circle(ai.position, r * 1.3, Color(c.r, c.g, c.b, a * 0.12))
		draw_circle(ai.position, r, Color(c.r, c.g, c.b, a * 0.35))
		draw_circle(ai.position, r * 0.5, Color(c.r, c.g, c.b, a * 0.55))

	# Draw shockwaves (expanding rings)
	for sw in shockwaves:
		var t: float = 1.0 - (sw.radius / sw.max_radius)
		var sc: Color = GameData.get_scale_color()
		draw_arc(sw.position, sw.radius, 0.0, TAU, 64, Color(sc.r, sc.g, sc.b, t * 0.5), 3.0)
		draw_arc(sw.position, sw.radius * 0.85, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, t * 0.25), 1.5)

	# Draw hex pattern overlay during scale transition
	if scale_manager and scale_manager.hex_pattern_alpha > 0.01:
		_draw_hex_grid(cam_pos, scale_manager.hex_pattern_color, scale_manager.hex_pattern_alpha)

# ── Hex grid overlay ───────────────────────────────────────────────

func _draw_hex_grid(cam_pos: Vector2, color: Color, alpha: float) -> void:
	var hex_size: float = 60.0
	var vp: Vector2 = get_viewport_rect().size
	var cols: int = int(vp.x / (hex_size * 1.5)) + 4
	var rows: int = int(vp.y / (hex_size * 1.732)) + 4

	var start_x: float = cam_pos.x - vp.x * 0.5 - hex_size * 2.0
	var start_y: float = cam_pos.y - vp.y * 0.5 - hex_size * 2.0

	for row in range(rows):
		for col in range(cols):
			var cx: float = start_x + col * hex_size * 1.5
			var cy: float = start_y + row * hex_size * 1.732
			if col % 2 == 1:
				cy += hex_size * 0.866

			# Distance fade from center of screen
			var d: float = Vector2(cx, cy).distance_to(cam_pos)
			var dist_fade: float = clampf(1.0 - d / (vp.x * 0.6), 0.0, 1.0)
			if dist_fade < 0.01:
				continue

			var hex_alpha: float = alpha * dist_fade
			_draw_hexagon(Vector2(cx, cy), hex_size * 0.45, Color(color.r, color.g, color.b, hex_alpha), 1.5)

func _draw_hexagon(center: Vector2, size: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(7):
		var angle: float = PI / 3.0 * float(i) + PI / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	for i in range(6):
		draw_line(points[i], points[i + 1], color, width)

# ── Shooting stars ─────────────────────────────────────────────────

func _update_shooting_stars(delta: float) -> void:
	shooting_star_timer -= delta
	if shooting_star_timer <= 0.0:
		_spawn_shooting_star()
		shooting_star_timer = randf_range(SHOOTING_STAR_INTERVAL_MIN, SHOOTING_STAR_INTERVAL_MAX)

	for i in range(shooting_stars.size() - 1, -1, -1):
		var ss: Dictionary = shooting_stars[i]
		ss.timer -= delta
		ss.position += ss.velocity * delta
		if ss.timer <= 0.0:
			shooting_stars.remove_at(i)

func _spawn_shooting_star() -> void:
	var cam_pos: Vector2 = camera.global_position if camera else Vector2.ZERO
	var vp: Vector2 = get_viewport_rect().size
	# Start from random edge of screen
	var start_x: float = cam_pos.x + randf_range(-vp.x * 0.6, vp.x * 0.6)
	var start_y: float = cam_pos.y - vp.y * 0.5
	var angle: float = randf_range(PI * 0.15, PI * 0.4) * (1.0 if randf() > 0.5 else -1.0) + PI * 0.5
	var speed: float = randf_range(600.0, 1200.0)
	shooting_stars.append({
		"position": Vector2(start_x, start_y),
		"velocity": Vector2(cos(angle), sin(angle)) * speed,
		"size": randf_range(1.0, 2.0),
		"trail_length": randf_range(40.0, 80.0),
		"timer": randf_range(0.6, 1.2),
		"lifetime": 1.2,
	})

# ── Nebula wisps ───────────────────────────────────────────────────

func _generate_nebula_wisps() -> void:
	var wisp_colors: Array[Color] = [
		Color(0.35, 0.15, 0.55),  # Purple
		Color(0.1, 0.2, 0.55),    # Deep blue
		Color(0.1, 0.45, 0.45),   # Teal
		Color(0.25, 0.1, 0.45),   # Violet
	]
	for i in range(4):
		nebula_wisps.append({
			"position": Vector2(randf_range(-STAR_FIELD_SIZE, STAR_FIELD_SIZE), randf_range(-STAR_FIELD_SIZE, STAR_FIELD_SIZE)),
			"radius": randf_range(200.0, 450.0),
			"color": wisp_colors[i],
			"drift": Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
			"phase": randf() * TAU,
		})

func _update_nebula_wisps(delta: float) -> void:
	for neb in nebula_wisps:
		neb.position += neb.drift * delta

# ── Background & stars ─────────────────────────────────────────────

func _update_background() -> void:
	if background and GameData.current_scale < BG_COLORS.size():
		var target_color: Color = BG_COLORS[GameData.current_scale]
		background.color = background.color.lerp(target_color, 0.02)
	queue_redraw()

func _generate_stars() -> void:
	for layer_idx in range(3):
		star_layers[layer_idx] = []
		var count: int = STAR_COUNTS[layer_idx]
		for i in range(count):
			star_layers[layer_idx].append({
				"pos": Vector2(randf_range(-STAR_FIELD_SIZE, STAR_FIELD_SIZE), randf_range(-STAR_FIELD_SIZE, STAR_FIELD_SIZE)),
				"size": randf_range(STAR_SIZE_MIN[layer_idx], STAR_SIZE_MAX[layer_idx]),
				"brightness": randf_range(STAR_BRIGHTNESS_MIN[layer_idx], STAR_BRIGHTNESS_MAX[layer_idx]),
				"phase": randf() * TAU * 10.0,
				"twinkle_speed": randf_range(0.5, 2.5),
			})

# ── Floating text pool ─────────────────────────────────────────────

func _create_floating_text_pool() -> void:
	var overlay: CanvasLayer = $UIOverlay
	if not overlay:
		return
	for i in range(FLOAT_TEXT_POOL_SIZE):
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5, 1.0))
		label.modulate.a = 0.0
		label.z_index = 100
		add_child(label)
		floating_texts.append(label)

func spawn_floating_text(world_pos: Vector2, text: String, is_big: bool) -> void:
	var label: Label = null
	for l in floating_texts:
		if l.modulate.a <= 0.01:
			label = l
			break
	if label == null:
		return

	label.text = text
	label.global_position = world_pos - Vector2(40, 20)
	label.modulate.a = 1.0
	label.scale = Vector2.ONE

	if is_big:
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
	else:
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.6, 1.0))

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", world_pos.y - 60.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	if is_big:
		tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15)

# ── Screen flash ───────────────────────────────────────────────────

func screen_flash(color: Color, duration: float) -> void:
	if not screen_flash_rect:
		return
	screen_flash_rect.color = Color(color.r, color.g, color.b, 1.0)
	screen_flash_rect.modulate.a = color.a
	var tween: Tween = create_tween()
	tween.tween_property(screen_flash_rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)

# ── Signal handlers ────────────────────────────────────────────────

func _on_player_eaten(_mass_gained: float) -> void:
	pass

func _on_transition_started(new_scale: int) -> void:
	# Flash with the NEW scale's color instead of white
	var new_color: Color = GameData.SCALE_COLORS[new_scale] if new_scale < GameData.SCALE_COLORS.size() else Color.WHITE

	if scale_label_flash:
		# Letter-by-letter animation for scale name
		var full_text: String = "SCALE UP!\n" + GameData.SCALE_DISPLAY[new_scale]
		scale_label_flash.text = ""
		scale_label_flash.modulate.a = 1.0
		scale_label_flash.add_theme_color_override("font_color", new_color)

		var letter_tween: Tween = create_tween()
		for i in range(full_text.length()):
			var partial: String = full_text.substr(0, i + 1)
			letter_tween.tween_callback(func(): scale_label_flash.text = partial)
			letter_tween.tween_interval(0.03)
		# Hold, then fade
		letter_tween.tween_property(scale_label_flash, "scale", Vector2(1.2, 1.2), 0.15)
		letter_tween.tween_property(scale_label_flash, "scale", Vector2(1.0, 1.0), 0.1)
		letter_tween.tween_interval(1.0)
		letter_tween.tween_property(scale_label_flash, "modulate:a", 0.0, 0.5)

	# Colored flash instead of white
	screen_flash(Color(new_color.r, new_color.g, new_color.b, 0.6), 0.5)

	# Screen shake
	shake_camera(15.0, 0.7)

func _on_transition_finished(_new_scale: int) -> void:
	_update_background()

func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true

	# Death effects
	shake_camera(25.0, 1.0)

	await get_tree().create_timer(1.2).timeout
	game_over_screen.show_game_over()
	game_over_screen.show()

func shake_camera(strength: float, duration: float) -> void:
	if camera:
		camera.shake(strength, duration)
