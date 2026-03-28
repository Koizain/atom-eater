extends CanvasLayer

@onready var scale_label: Label = $VBoxContainer/ScaleLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var deaths_label: Label = $VBoxContainer/DeathsLabel
@onready var fps_label: Label = $VBoxContainer/FPSLabel
@onready var combo_label: Label = $VBoxContainer/ComboLabel
@onready var scale_flash: ColorRect = $ScaleFlash

var flash_timer: float = 0.0
var player_ref: Area2D = null

func _ready() -> void:
	GameData.scale_changed.connect(_on_scale_changed)
	if scale_flash:
		scale_flash.modulate.a = 0.0

func set_player(player: Area2D) -> void:
	player_ref = player

func _process(delta: float) -> void:
	_update_hud()

	if flash_timer > 0.0:
		flash_timer -= delta
		if scale_flash:
			scale_flash.modulate.a = clamp(flash_timer / 0.5, 0.0, 0.7)

func _update_hud() -> void:
	if scale_label:
		scale_label.text = "⚛ " + GameData.get_scale_name()
		scale_label.add_theme_color_override("font_color", GameData.get_scale_color())

	if progress_bar:
		progress_bar.value = GameData.get_scale_progress() * 100.0
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = GameData.get_scale_color()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		progress_bar.add_theme_stylebox_override("fill", style)

	if deaths_label:
		deaths_label.text = "☠ Deaths: " + str(GameData.deaths_this_session)

	if fps_label:
		fps_label.text = "FPS: " + str(Engine.get_frames_per_second())

	if combo_label and player_ref and player_ref.has_method("get_player_radius"):
		var combo: int = 0
		if "combo_count" in player_ref:
			combo = player_ref.combo_count
		if combo > 1:
			combo_label.text = "COMBO x" + str(combo) + "!"
			combo_label.modulate.a = 1.0
		else:
			combo_label.modulate.a = max(0.0, combo_label.modulate.a - 0.016 * 2.0)

func _on_scale_changed(new_scale: int) -> void:
	flash_timer = 0.5
	if scale_flash:
		scale_flash.modulate.a = 0.7
