extends CanvasLayer

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var scale_label: Label = $CenterContainer/VBoxContainer/ScaleReachedLabel
@onready var eaten_label: Label = $CenterContainer/VBoxContainer/EatenLabel
@onready var combo_label: Label = $CenterContainer/VBoxContainer/ComboLabel
@onready var fragments_label: Label = $CenterContainer/VBoxContainer/FragmentsLabel
@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton

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
		scale_label.text = "Scale reached: " + GameData.get_scale_name()
	if eaten_label:
		eaten_label.text = "Particles eaten: " + str(GameData.objects_eaten)
	if combo_label:
		combo_label.text = "Max combo: x" + str(GameData.max_combo)
	if fragments_label:
		fragments_label.text = "⬡ Color Fragments earned: " + str(fragments)

	show()
	# Animate in
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

func _on_restart_pressed() -> void:
	GameData.reset_run()
	get_tree().reload_current_scene()
