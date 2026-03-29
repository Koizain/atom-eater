extends Node

# GameData autoload singleton — persistent game state

signal scale_changed(new_scale_index: int)
signal hp_changed(new_hp: int)

# Current run state
var current_scale: int = 0  # 0=Quantum Foam .. 17=Universal
var player_mass: float = 10.0
var deaths_this_session: int = 0
var run_start_time: float = 0.0
var objects_eaten: int = 0
var max_combo: int = 0
var color_fragments_earned: int = 0

# HP system
var player_hp: int = 3
var max_hp: int = 3
const MAX_HP_CAP: int = 5
const START_HP: int = 3

# Scale definitions — 18 scales of reality
const SCALE_NAMES: Array[String] = [
	"Quantum Foam", "Subatomic", "Atomic", "Molecular",
	"Viral", "Bacterial", "Microorganism", "Insect",
	"Small Animal", "Human", "Vehicle", "City",
	"Geographic", "Planetary", "Stellar", "Galactic",
	"Cosmic", "Universal",
]
const SCALE_DISPLAY: Array[String] = [
	"SCALE 1: QUANTUM FOAM",
	"SCALE 2: SUBATOMIC",
	"SCALE 3: ATOMIC",
	"SCALE 4: MOLECULAR",
	"SCALE 5: VIRAL",
	"SCALE 6: BACTERIAL",
	"SCALE 7: MICROORGANISM",
	"SCALE 8: INSECT",
	"SCALE 9: SMALL ANIMAL",
	"SCALE 10: HUMAN",
	"SCALE 11: VEHICLE",
	"SCALE 12: CITY",
	"SCALE 13: GEOGRAPHIC",
	"SCALE 14: PLANETARY",
	"SCALE 15: STELLAR",
	"SCALE 16: GALACTIC",
	"SCALE 17: COSMIC",
	"SCALE 18: UNIVERSAL",
]
const SCALE_THRESHOLDS: Array[float] = [
	200.0,        # 0  Quantum Foam -> Subatomic
	500.0,        # 1  Subatomic -> Atomic
	1200.0,       # 2  Atomic -> Molecular
	3000.0,       # 3  Molecular -> Viral
	7000.0,       # 4  Viral -> Bacterial
	15000.0,      # 5  Bacterial -> Microorganism
	35000.0,      # 6  Microorganism -> Insect
	80000.0,      # 7  Insect -> Small Animal
	180000.0,     # 8  Small Animal -> Human
	400000.0,     # 9  Human -> Vehicle
	900000.0,     # 10 Vehicle -> City
	2000000.0,    # 11 City -> Geographic
	5000000.0,    # 12 Geographic -> Planetary
	12000000.0,   # 13 Planetary -> Stellar
	30000000.0,   # 14 Stellar -> Galactic
	80000000.0,   # 15 Galactic -> Cosmic
	200000000.0,  # 16 Cosmic -> Universal
	9999999999.0, # 17 Universal (max)
]
const SCALE_COLORS: Array[Color] = [
	Color(0.27, 0.27, 0.53),  # Quantum Foam: deep indigo
	Color(0.3, 0.5, 1.0),     # Subatomic: blue-white
	Color(0.0, 0.8, 1.0),     # Atomic: cyan
	Color(0.27, 1.0, 0.67),   # Molecular: green-cyan
	Color(1.0, 0.0, 0.4),     # Viral: hot pink
	Color(0.27, 1.0, 0.27),   # Bacterial: bright green
	Color(0.0, 1.0, 0.53),    # Microorganism: sea green
	Color(0.67, 0.53, 0.2),   # Insect: amber
	Color(0.27, 0.53, 0.8),   # Small Animal: blue
	Color(1.0, 0.8, 0.53),    # Human: warm skin
	Color(0.67, 0.67, 0.67),  # Vehicle: silver
	Color(1.0, 1.0, 0.27),    # City: yellow
	Color(0.1, 0.4, 0.27),    # Geographic: forest green
	Color(0.27, 0.4, 0.67),   # Planetary: slate blue
	Color(1.0, 0.67, 0.13),   # Stellar: golden
	Color(0.53, 0.27, 0.8),   # Galactic: violet
	Color(0.4, 0.8, 1.0),     # Cosmic: light blue
	Color(1.0, 1.0, 1.0),     # Universal: white
]

# Player starting radius
const PLAYER_START_RADIUS: float = 16.0

# Upgrade definitions
const UPGRADES: Array[Dictionary] = [
	{"id": "density", "name": "Density", "desc": "Absorption radius +30%", "max_stacks": 3},
	{"id": "efficiency", "name": "Efficiency", "desc": "Mass per eat +20%", "max_stacks": 3},
	{"id": "agility", "name": "Agility", "desc": "Movement speed +25%", "max_stacks": 3},
	{"id": "magnetism", "name": "Magnetism", "desc": "Small entities drawn toward you", "max_stacks": 1},
	{"id": "ghosting", "name": "Ghosting", "desc": "Phase through threats after dash", "max_stacks": 1},
	{"id": "hunger", "name": "Hunger", "desc": "Eating gives brief speed burst", "max_stacks": 1},
	{"id": "gravity", "name": "Gravity", "desc": "Right-click: shockwave pushes entities", "max_stacks": 1},
	{"id": "chain", "name": "Chain", "desc": "Eating chains to nearest smaller entity", "max_stacks": 1},
	{"id": "resilience", "name": "Resilience", "desc": "+1 HP (max 5)", "max_stacks": 2},
]

# Upgrade state for current run
var upgrade_counts: Dictionary = {}

func reset_run() -> void:
	current_scale = 0
	player_mass = 10.0
	max_hp = START_HP
	player_hp = max_hp
	run_start_time = Time.get_ticks_msec() / 1000.0
	objects_eaten = 0
	max_combo = 0
	color_fragments_earned = 0
	upgrade_counts = {}

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

func get_upgrade_count(upgrade_id: String) -> int:
	return upgrade_counts.get(upgrade_id, 0)

func apply_upgrade(upgrade_id: String) -> void:
	if not upgrade_counts.has(upgrade_id):
		upgrade_counts[upgrade_id] = 0
	upgrade_counts[upgrade_id] += 1
	if upgrade_id == "resilience":
		max_hp = mini(max_hp + 1, MAX_HP_CAP)
		player_hp = mini(player_hp + 1, max_hp)
		hp_changed.emit(player_hp)

func get_random_upgrades(count: int) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for upg in UPGRADES:
		var current: int = get_upgrade_count(upg.id)
		if current < upg.max_stacks:
			available.append(upg)
	available.shuffle()
	var result: Array[Dictionary] = []
	for i in range(mini(count, available.size())):
		result.append(available[i])
	return result

func _ready() -> void:
	reset_run()
