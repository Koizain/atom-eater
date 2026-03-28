extends Node2D

@export var entity_scene: PackedScene = preload("res://scenes/entity.tscn")
@export var player: Area2D

# Pool settings
const POOL_SIZE: int = 120
const SPAWN_RADIUS_MIN: float = 350.0
const SPAWN_RADIUS_MAX: float = 700.0
const DESPAWN_RADIUS: float = 900.0
const SPAWN_INTERVAL_BASE: float = 0.35

# Entity size relative to player radius
const SIZE_RATIO_MIN: float = 0.15
const SIZE_RATIO_MAX: float = 3.2

var entity_pool: Array[Area2D] = []
var active_entities: Array[Area2D] = []
var spawn_timer: float = 0.0
var difficulty_time: float = 0.0

# Scale-specific settings
var current_scale_index: int = 0
var toxic_chance: float = 0.0
var max_active: int = 60

var _pool_built: bool = false

func _ready() -> void:
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	if not _pool_built:
		_build_pool()
		_pool_built = true
	refresh_for_scale(0)

func _build_pool() -> void:
	for i in range(POOL_SIZE):
		var entity: Area2D = entity_scene.instantiate()
		entity.hide()
		entity.set_process(false)
		add_child(entity)
		entity_pool.append(entity)

func _process(delta: float) -> void:
	spawn_timer -= delta
	difficulty_time += delta

	if spawn_timer <= 0.0:
		_spawn_batch()
		var interval: float = SPAWN_INTERVAL_BASE * (1.0 - clamp(difficulty_time / 120.0, 0.0, 0.6))
		spawn_timer = max(0.12, interval)

	_check_despawn()

func _spawn_batch() -> void:
	if active_entities.size() >= max_active:
		return
	if not player:
		return

	var batch_count: int = randi_range(1, 4)
	for i in range(batch_count):
		if active_entities.size() >= max_active:
			break
		_spawn_one()

func _spawn_one() -> void:
	var entity: Area2D = _get_pooled_entity()
	if entity == null:
		return

	var player_radius: float = 16.0
	if player.has_method("get_player_radius"):
		player_radius = player.get_player_radius()

	var angle: float = randf() * TAU
	var dist: float = randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	var spawn_pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * dist

	# Size distribution: 60% smaller, 30% similar, 10% larger
	var size_roll: float = randf()
	var size_ratio: float
	if size_roll < 0.60:
		size_ratio = randf_range(SIZE_RATIO_MIN, 0.7)
	elif size_roll < 0.90:
		size_ratio = randf_range(0.7, 1.15)
	else:
		size_ratio = randf_range(1.15, SIZE_RATIO_MAX)

	var radius: float = clamp(player_radius * size_ratio, 4.0, 150.0)

	# Toxic only in scale 2+
	var toxic: bool = false
	if current_scale_index >= 2 and randf() < toxic_chance:
		toxic = true

	var color: Color = _get_entity_color(size_ratio, toxic)
	var speed: float = randf_range(15.0, 60.0) * (1.0 + difficulty_time / 180.0)

	if entity.has_method("reset_entity"):
		entity.reset_entity(radius, toxic, color, speed, spawn_pos, current_scale_index)
	entity.show()
	entity.set_process(true)

	# Entity type: 60% wanderer, 25% orbiter, 15% chaser (chasers only when player is large)
	var type_roll: float = randf()
	if type_roll < 0.60:
		entity.setup_as_wanderer()
	elif type_roll < 0.85:
		# Orbiter: orbit a nearby point
		var orbit_center: Vector2 = spawn_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var orbit_r: float = randf_range(40.0, 120.0)
		entity.setup_as_orbiter(orbit_center, orbit_r)
	else:
		# Chasers only if player is somewhat large and entity is bigger
		if player_radius > 24.0 and size_ratio > 1.0:
			entity.setup_as_chaser(player, randf_range(20.0, 45.0))
		else:
			entity.setup_as_wanderer()

	active_entities.append(entity)

func _get_entity_color(size_ratio: float, toxic: bool) -> Color:
	if toxic:
		return Color(0.5, 0.0, 0.8)  # Purple for toxic

	# Color gradient: smaller = cyan/green, similar = yellow, larger = red/orange
	if size_ratio < 0.5:
		return Color(0.0, 0.95, 0.7)  # Bright cyan
	elif size_ratio < 0.7:
		return Color(0.1, 0.9, 0.3)  # Green
	elif size_ratio < 1.0:
		return Color(0.1, 0.8, 0.8)  # Cyan
	elif size_ratio < 1.15:
		return Color(0.95, 0.9, 0.1)  # Yellow
	elif size_ratio < 1.8:
		return Color(1.0, 0.4, 0.1)  # Orange-red
	else:
		return Color(0.9, 0.05, 0.05)  # Deep red

func _check_despawn() -> void:
	if not player:
		return
	var to_remove: Array[Area2D] = []
	for entity in active_entities:
		if not is_instance_valid(entity):
			to_remove.append(entity)
			continue
		if not entity.visible:
			to_remove.append(entity)
			continue
		var d: float = entity.global_position.distance_to(player.global_position)
		if d > DESPAWN_RADIUS:
			to_remove.append(entity)
			_return_to_pool(entity)

	for e in to_remove:
		active_entities.erase(e)

func _get_pooled_entity() -> Area2D:
	for entity in entity_pool:
		if not is_instance_valid(entity):
			continue
		if not entity.visible:
			return entity
	return null

func _return_to_pool(entity: Area2D) -> void:
	if not is_instance_valid(entity):
		return
	entity.hide()
	entity.set_process(false)
	entity.monitoring = false
	entity.monitorable = false

func refresh_for_scale(scale_idx: int) -> void:
	current_scale_index = scale_idx
	match scale_idx:
		0:  # Subatomic
			toxic_chance = 0.0
			difficulty_time = 0.0
			max_active = 60
		1:  # Atomic
			toxic_chance = 0.0
			difficulty_time = 20.0
			max_active = 70
		2:  # Molecular
			toxic_chance = 0.20
			max_active = 80
		3:  # Cellular
			toxic_chance = 0.25
			max_active = 90
		4:  # Planetary
			toxic_chance = 0.30
			max_active = 100

	# Clear active entities on scale change
	for entity in active_entities:
		if is_instance_valid(entity):
			_return_to_pool(entity)
	active_entities.clear()
	spawn_timer = 0.5
