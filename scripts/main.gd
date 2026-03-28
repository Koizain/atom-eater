extends Node2D

@onready var player: Area2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var entity_spawner: Node2D = $EntitySpawner
@onready var scale_manager: Node = $ScaleManager
@onready var hud: CanvasLayer = $HUD
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var background: ColorRect = $BackgroundLayer/Background
@onready var scale_label_flash: Label = $UIOverlay/ScaleTransitionLabel
@onready var screen_flash_rect: ColorRect = $UIOverlay/ScreenFlashRect

var is_game_over: bool = false

# Parallax stars
var star_positions: Array[Vector2] = []
var star_sizes: Array[float] = []
var star_brightnesses: Array[float] = []
const STAR_COUNT: int = 120
const STAR_FIELD_SIZE: float = 2400.0
var star_parallax_factor: float = 0.1

# Floating text pool
var floating_texts: Array[Label] = []
const FLOAT_TEXT_POOL_SIZE: int = 15

# Background colors per scale
const BG_COLORS: Array[Color] = [
	Color(0.039, 0.039, 0.059),   # Subatomic
	Color(0.02, 0.05, 0.04),      # Atomic
	Color(0.05, 0.02, 0.06),      # Molecular
	Color(0.04, 0.02, 0.03),      # Cellular
	Color(0.02, 0.02, 0.05),      # Planetary
]

func _ready() -> void:
	GameData.reset_run()

	# Wire scale manager
	scale_manager.camera = camera
	scale_manager.entity_spawner = entity_spawner
	scale_manager.transition_started.connect(_on_transition_started)
	scale_manager.transition_finished.connect(_on_transition_finished)

	# Wire player
	player.scale_manager = scale_manager
	player.eaten_entity.connect(_on_player_eaten)
	player.player_died_signal.connect(_on_player_died)

	# Wire HUD
	hud.set_player(player)

	# Wire entity spawner
	entity_spawner.player = player

	set_process(true)

	game_over_screen.hide()

	if scale_label_flash:
		scale_label_flash.modulate.a = 0.0

	if screen_flash_rect:
		screen_flash_rect.modulate.a = 0.0

	_update_background()
	_generate_stars()
	_create_floating_text_pool()

func _process(delta: float) -> void:
	if is_game_over:
		return

	# Keep camera following player
	camera.global_position = player.global_position

	_update_background()

func _draw() -> void:
	# Draw parallax stars
	var cam_pos: Vector2 = camera.global_position if camera else Vector2.ZERO
	for i in range(star_positions.size()):
		var star_pos: Vector2 = star_positions[i]
		# Parallax offset
		var parallax_pos: Vector2 = star_pos - cam_pos * star_parallax_factor
		# Wrap stars
		parallax_pos.x = fmod(parallax_pos.x + STAR_FIELD_SIZE, STAR_FIELD_SIZE * 2.0) - STAR_FIELD_SIZE + cam_pos.x
		parallax_pos.y = fmod(parallax_pos.y + STAR_FIELD_SIZE, STAR_FIELD_SIZE * 2.0) - STAR_FIELD_SIZE + cam_pos.y

		var brightness: float = star_brightnesses[i]
		# Subtle twinkle
		brightness *= (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.001 * (1.0 + i * 0.1)))
		var size: float = star_sizes[i]
		draw_circle(parallax_pos, size, Color(0.8, 0.85, 1.0, brightness * 0.5))

func _update_background() -> void:
	if background and GameData.current_scale < BG_COLORS.size():
		var target_color: Color = BG_COLORS[GameData.current_scale]
		background.color = background.color.lerp(target_color, 0.02)
	queue_redraw()  # Redraw stars

func _generate_stars() -> void:
	star_positions.clear()
	star_sizes.clear()
	star_brightnesses.clear()
	for i in range(STAR_COUNT):
		star_positions.append(Vector2(
			randf_range(-STAR_FIELD_SIZE, STAR_FIELD_SIZE),
			randf_range(-STAR_FIELD_SIZE, STAR_FIELD_SIZE)
		))
		star_sizes.append(randf_range(0.5, 2.0))
		star_brightnesses.append(randf_range(0.3, 1.0))

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
		# Add to main scene (world space), not overlay
		add_child(label)
		floating_texts.append(label)

func spawn_floating_text(world_pos: Vector2, text: String, is_big: bool) -> void:
	# Find an available floating text
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

	# Animate: float up and fade
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", world_pos.y - 60.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	if is_big:
		tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15)

func screen_flash(color: Color, duration: float) -> void:
	if not screen_flash_rect:
		return
	screen_flash_rect.color = Color(color.r, color.g, color.b, 1.0)
	screen_flash_rect.modulate.a = color.a
	var tween: Tween = create_tween()
	tween.tween_property(screen_flash_rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)

func _on_player_eaten(mass_gained: float) -> void:
	# Camera punch proportional to mass gained
	var punch_amount: float = clamp(mass_gained * 0.002, 0.01, 0.04)
	_camera_punch(punch_amount)

func _on_transition_started(new_scale: int) -> void:
	# Flash scale transition label — "SCALE UP!"
	if scale_label_flash:
		scale_label_flash.text = "SCALE UP!\n" + GameData.SCALE_DISPLAY[new_scale]
		scale_label_flash.modulate.a = 1.0
		var tween: Tween = create_tween()
		# Hold for a moment, then fade
		tween.tween_property(scale_label_flash, "scale", Vector2(1.2, 1.2), 0.15)
		tween.tween_property(scale_label_flash, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_interval(1.2)
		tween.tween_property(scale_label_flash, "modulate:a", 0.0, 0.5)

	# Screen shake
	shake_camera(15.0, 0.7)

func _on_transition_finished(new_scale: int) -> void:
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
	if not camera:
		return
	var tween: Tween = create_tween()
	var steps: int = int(duration / 0.05)
	for i in range(steps):
		var t: float = float(i) / float(steps)
		var s: float = strength * (1.0 - t)
		var offset: Vector2 = Vector2(
			randf_range(-s, s),
			randf_range(-s, s)
		)
		tween.tween_property(camera, "offset", offset, 0.05)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func _camera_punch(amount: float) -> void:
	if not camera:
		return
	var tween: Tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(1.0 + amount, 1.0 + amount), 0.06)
	tween.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.12)
