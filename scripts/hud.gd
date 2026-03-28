extends CanvasLayer

@onready var scale_label: Label = $VBoxContainer/ScaleLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
var mass_label: Label = null
@onready var hp_container: HBoxContainer = $VBoxContainer/HPContainer
@onready var fps_label: Label = $VBoxContainer/FPSLabel
@onready var combo_label: Label = $ComboDisplay/ComboLabel
@onready var combo_mult_label: Label = $ComboDisplay/MultiplierLabel
@onready var scale_flash: ColorRect = $ScaleFlash

var flash_timer: float = 0.0
var player_ref: Area2D = null
var hp_circles: Array[ColorRect] = []
var progress_glow_time: float = 0.0

# Smooth progress bar
var display_progress: float = 0.0

# Cached progress bar style — reuse instead of creating new one every frame
var _progress_style: StyleBoxFlat = null

func _ready() -> void:
	mass_label = get_node_or_null("VBoxContainer/MassLabel")
	GameData.scale_changed.connect(_on_scale_changed)
	GameData.hp_changed.connect(_on_hp_changed)
	if scale_flash:
		scale_flash.modulate.a = 0.0
	_create_hp_circles()

func set_player(player: Area2D) -> void:
	player_ref = player
	if player_ref.has_signal("combo_changed"):
		player_ref.combo_changed.connect(_on_combo_changed)
	if player_ref.has_signal("player_hit"):
		player_ref.player_hit.connect(_on_player_hit)

func _process(delta: float) -> void:
	progress_glow_time += delta
	_update_hud(delta)

	if flash_timer > 0.0:
		flash_timer -= delta
		if scale_flash:
			scale_flash.modulate.a = clamp(flash_timer / 0.5, 0.0, 0.7)

func _update_hud(delta: float) -> void:
	# Scale label with number
	if scale_label:
		scale_label.text = GameData.get_scale_display()
		scale_label.add_theme_color_override("font_color", GameData.get_scale_color())

	# Smooth animated progress bar
	if progress_bar:
		var target: float = GameData.get_scale_progress() * 100.0
		display_progress = lerp(display_progress, target, 5.0 * delta)
		progress_bar.value = display_progress

		# Animated glow on progress bar fill — reuse cached style
		var glow_alpha: float = 0.6 + 0.4 * sin(progress_glow_time * 3.0)
		var sc: Color = GameData.get_scale_color()
		if not _progress_style:
			_progress_style = StyleBoxFlat.new()
			_progress_style.corner_radius_top_left = 4
			_progress_style.corner_radius_top_right = 4
			_progress_style.corner_radius_bottom_left = 4
			_progress_style.corner_radius_bottom_right = 4
			progress_bar.add_theme_stylebox_override("fill", _progress_style)
		_progress_style.bg_color = Color(sc.r, sc.g, sc.b, glow_alpha)

	# Mass counter
	if mass_label:
		var threshold: float = GameData.get_scale_threshold()
		var display_threshold: String = str(int(threshold)) if threshold < 9999999.0 else "MAX"
		mass_label.text = "Mass: %.0f / %s" % [GameData.player_mass, display_threshold]

	if fps_label:
		fps_label.text = "FPS: " + str(Engine.get_frames_per_second())

	# Combo fade out
	if combo_label and combo_label.modulate.a > 0.0:
		if player_ref and "combo_count" in player_ref and player_ref.combo_count <= 1:
			combo_label.modulate.a = max(0.0, combo_label.modulate.a - 2.0 * delta)
			if combo_mult_label:
				combo_mult_label.modulate.a = combo_label.modulate.a

func _on_combo_changed(combo: int, multiplier: float) -> void:
	if not combo_label:
		return
	if combo >= 3:
		combo_label.text = "COMBO x%d!" % combo
		combo_label.modulate.a = 1.0
		# Pop animation
		var tween: Tween = create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.08)
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.12)

		if combo_mult_label and multiplier > 1.0:
			combo_mult_label.text = "%.1fx BONUS" % multiplier
			combo_mult_label.modulate.a = 1.0
	elif combo == 0:
		combo_label.modulate.a = 0.0
		if combo_mult_label:
			combo_mult_label.modulate.a = 0.0

func _on_player_hit() -> void:
	# Flash screen red briefly
	_update_hp_display()

func _create_hp_circles() -> void:
	if not hp_container:
		return
	for i in range(GameData.MAX_HP_CAP):
		var circle: ColorRect = ColorRect.new()
		circle.custom_minimum_size = Vector2(18, 18)
		if i < GameData.max_hp:
			circle.color = Color(1.0, 0.2, 0.2, 0.9) if i < GameData.player_hp else Color(0.3, 0.1, 0.1, 0.4)
		else:
			circle.color = Color(0.0, 0.0, 0.0, 0.0)  # Hidden slot
		hp_container.add_child(circle)
		hp_circles.append(circle)

func _update_hp_display() -> void:
	for i in range(hp_circles.size()):
		if i >= GameData.max_hp:
			hp_circles[i].color = Color(0.0, 0.0, 0.0, 0.0)  # Hidden
		elif i < GameData.player_hp:
			hp_circles[i].color = Color(1.0, 0.2, 0.2, 0.9)
		else:
			hp_circles[i].color = Color(0.3, 0.1, 0.1, 0.4)
	# Pulse remaining HP circles
	if GameData.player_hp > 0 and GameData.player_hp < GameData.max_hp:
		for i in range(GameData.player_hp):
			var tween: Tween = create_tween()
			tween.tween_property(hp_circles[i], "scale", Vector2(1.4, 1.4), 0.1)
			tween.tween_property(hp_circles[i], "scale", Vector2(1.0, 1.0), 0.2)

func _on_hp_changed(_new_hp: int) -> void:
	_update_hp_display()

func _on_scale_changed(_new_scale: int) -> void:
	flash_timer = 0.5
	if scale_flash:
		scale_flash.modulate.a = 0.7
