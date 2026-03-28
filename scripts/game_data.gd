extends Node

# GameData autoload singleton — persistent game state

signal scale_changed(new_scale_index: int)
signal player_died(stats: Dictionary)
signal score_updated(mass: float)
signal hp_changed(new_hp: int)
signal combo_updated(combo: int, multiplier: float)

# Current run state
var current_scale: int = 0  # 0=Subatomic, 1=Atomic, 2=Molecular, 3=Cellular, 4=Planetary
var player_mass: float = 10.0
var deaths_this_session: int = 0
var run_start_time: float = 0.0
var objects_eaten: int = 0
var max_combo: int = 0
var color_fragments_earned: int = 0

# HP system
var player_hp: int = 3
const MAX_HP: int = 3

# Scale definitions — 5 scales of reality
const SCALE_NAMES: Array[String] = ["Subatomic", "Atomic", "Molecular", "Cellular", "Planetary"]
const SCALE_DISPLAY: Array[String] = [
	"SCALE 1: SUBATOMIC",
	"SCALE 2: ATOMIC",
	"SCALE 3: MOLECULAR",
	"SCALE 4: CELLULAR",
	"SCALE 5: PLANETARY",
]
const SCALE_THRESHOLDS: Array[float] = [350.0, 1225.0, 4500.0, 15000.0, 9999999.0]
const SCALE_COLORS: Array[Color] = [
	Color(0.3, 0.5, 1.0),    # Subatomic: blue-white
	Color(0.2, 1.0, 0.6),    # Atomic: cyan-green
	Color(1.0, 0.5, 0.1),    # Molecular: orange
	Color(0.9, 0.2, 0.5),    # Cellular: pink-red
	Color(0.7, 0.4, 1.0),    # Planetary: purple
]

# Player starting radius
const PLAYER_START_RADIUS: float = 16.0

func reset_run() -> void:
	current_scale = 0
	player_mass = 10.0
	player_hp = MAX_HP
	run_start_time = Time.get_ticks_msec() / 1000.0
	objects_eaten = 0
	max_combo = 0
	color_fragments_earned = 0

func get_scale_name() -> String:
	if current_scale < SCALE_NAMES.size():
		return SCALE_NAMES[current_scale]
	return "Unknown"

func get_scale_display() -> String:
	if current_scale < SCALE_DISPLAY.size():
		return SCALE_DISPLAY[current_scale]
	return "UNKNOWN"

func get_scale_progress() -> float:
	if current_scale >= SCALE_THRESHOLDS.size():
		return 1.0
	var threshold: float = SCALE_THRESHOLDS[current_scale]
	var start_mass: float = 10.0
	if current_scale > 0:
		start_mass = SCALE_THRESHOLDS[current_scale - 1] * 0.3
	return clamp((player_mass - start_mass) / (threshold - start_mass), 0.0, 1.0)

func get_scale_threshold() -> float:
	if current_scale < SCALE_THRESHOLDS.size():
		return SCALE_THRESHOLDS[current_scale]
	return 9999999.0

func get_scale_color() -> Color:
	if current_scale < SCALE_COLORS.size():
		return SCALE_COLORS[current_scale]
	return Color.WHITE

func get_combo_multiplier(combo_count: int) -> float:
	if combo_count < 3:
		return 1.0
	elif combo_count < 6:
		return 1.5
	elif combo_count < 10:
		return 2.0
	elif combo_count < 15:
		return 3.0
	else:
		return 5.0

func take_damage() -> bool:
	player_hp -= 1
	hp_changed.emit(player_hp)
	return player_hp <= 0

func calculate_fragments() -> int:
	var frags: int = current_scale + 1
	frags += int(objects_eaten * 0.05)
	frags = max(frags, 1)
	return frags

func _ready() -> void:
	reset_run()
