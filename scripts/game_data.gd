extends Node

# GameData autoload singleton — persistent game state

signal scale_changed(new_scale_index: int)
signal player_died(stats: Dictionary)
signal score_updated(mass: float)

# Current run state
var current_scale: int = 0  # 0=Subatomic, 1=Atomic, 2=Molecular
var player_mass: float = 10.0
var deaths_this_session: int = 0
var run_start_time: float = 0.0
var objects_eaten: int = 0
var max_combo: int = 0
var color_fragments_earned: int = 0

# Scale definitions
const SCALE_NAMES: Array[String] = ["Subatomic", "Atomic", "Molecular"]
const SCALE_THRESHOLDS: Array[float] = [350.0, 1225.0, 9999999.0]
const SCALE_COLORS: Array[Color] = [
	Color(0.3, 0.5, 1.0),    # Subatomic: blue-white
	Color(0.2, 1.0, 0.6),    # Atomic: cyan-green
	Color(1.0, 0.5, 0.1),    # Molecular: orange
]

# Player starting radius
const PLAYER_START_RADIUS: float = 16.0

func reset_run() -> void:
	current_scale = 0
	player_mass = 10.0
	run_start_time = Time.get_ticks_msec() / 1000.0
	objects_eaten = 0
	max_combo = 0
	color_fragments_earned = 0

func get_scale_name() -> String:
	if current_scale < SCALE_NAMES.size():
		return SCALE_NAMES[current_scale]
	return "Unknown"

func get_scale_progress() -> float:
	if current_scale >= SCALE_THRESHOLDS.size():
		return 1.0
	var threshold: float = SCALE_THRESHOLDS[current_scale]
	# Start mass for current scale
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

func calculate_fragments() -> int:
	var frags: int = current_scale + 1
	frags += int(objects_eaten * 0.05)
	var run_time: float = Time.get_ticks_msec() / 1000.0 - run_start_time
	frags = max(frags, 1)
	return frags

func _ready() -> void:
	reset_run()
