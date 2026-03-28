extends Node2D

@onready var player: Area2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var entity_spawner: Node2D = $EntitySpawner
@onready var scale_manager: Node = $ScaleManager
@onready var hud: CanvasLayer = $HUD
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var background: ColorRect = $BackgroundLayer/Background
@onready var scale_label_flash: Label = $UIOverlay/ScaleTransitionLabel

var is_game_over: bool = false

# Background colors per scale
const BG_COLORS: Array[Color] = [
	Color(0.039, 0.039, 0.059),   # Subatomic: dark blue-black
	Color(0.02, 0.05, 0.04),       # Atomic: dark teal-black
	Color(0.05, 0.02, 0.06),       # Molecular: dark purple-black
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

	# Wire spawner to follow player
	set_process(true)

	game_over_screen.hide()

	if scale_label_flash:
		scale_label_flash.modulate.a = 0.0

	_update_background()

func _process(delta: float) -> void:
	if is_game_over:
		return

	# Keep camera following player
	camera.global_position = player.global_position

	# Keep entity spawner centered on player (for despawn calcs)
	# (entity spawner uses player.global_position directly)

	# Update background color
	_update_background()

func _update_background() -> void:
	if background and GameData.current_scale < BG_COLORS.size():
		var target_color: Color = BG_COLORS[GameData.current_scale]
		background.color = background.color.lerp(target_color, 0.02)

func _on_player_eaten(mass_gained: float) -> void:
	# Small camera punch
	_camera_punch(0.015)

func _on_transition_started(new_scale: int) -> void:
	# Flash scale transition label
	if scale_label_flash:
		scale_label_flash.text = "→ " + GameData.SCALE_NAMES[new_scale] + " ←"
		scale_label_flash.modulate.a = 1.0
		var tween: Tween = create_tween()
		tween.tween_interval(1.0)
		tween.tween_property(scale_label_flash, "modulate:a", 0.0, 0.5)

	# Screen shake
	shake_camera(12.0, 0.6)

func _on_transition_finished(new_scale: int) -> void:
	_update_background()

func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true

	# Death effect
	shake_camera(20.0, 0.8)
	player.hide()

	await get_tree().create_timer(0.9).timeout
	game_over_screen.show_game_over()
	game_over_screen.show()

func shake_camera(strength: float, duration: float) -> void:
	if not camera:
		return
	var tween: Tween = create_tween()
	var start_pos: Vector2 = camera.offset
	var elapsed: float = 0.0
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
