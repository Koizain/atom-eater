extends CanvasLayer

@onready var center_container: CenterContainer = $CenterContainer
@onready var color_rect: ColorRect = $ColorRect
@onready var title_label: Label = $CenterContainer/VBoxContainer/Panel/InnerBox/TitleLabel
@onready var scale_label: Label = $CenterContainer/VBoxContainer/Panel/InnerBox/ScaleReachedLabel
@onready var eaten_label: Label = $CenterContainer/VBoxContainer/Panel/InnerBox/EatenLabel
@onready var combo_label: Label = $CenterContainer/VBoxContainer/Panel/InnerBox/ComboLabel
@onready var fragments_label: Label = $CenterContainer/VBoxContainer/Panel/InnerBox/FragmentsLabel
@onready var restart_button: Button = $CenterContainer/VBoxContainer/Panel/InnerBox/RestartButton

func _ready() -> void:
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	hide()

func show_game_over() -> void:
	var fragments: int = GameData.calculate_fragments()
	GameData.color_fragments_earned = fragments

	if title_label:
		title_label.text = "YOU WERE EATEN"
	if scale_label:
		scale_label.text = "Scale reached: " + GameData.get_scale_name() + " (Scale %d)" % (GameData.current_scale + 1)
	if eaten_label:
		eaten_label.text = "Particles eaten: " + str(GameData.objects_eaten)
	if combo_label:
		combo_label.text = "Max combo: x" + str(GameData.max_combo)
	if fragments_label:
		fragments_label.text = "Color Fragments earned: " + str(fragments)

	show()
	# Animate in
	if center_container:
		center_container.modulate.a = 0.0
		center_container.scale = Vector2(0.8, 0.8)
	if color_rect:
		color_rect.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if center_container:
		tween.tween_property(center_container, "modulate:a", 1.0, 0.5)
		tween.tween_property(center_container, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if color_rect:
		tween.tween_property(color_rect, "modulate:a", 1.0, 0.5)

func _on_restart_pressed() -> void:
	GameData.reset_run()
	get_tree().reload_current_scene()
