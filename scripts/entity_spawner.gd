extends Node2D

@export var entity_scene: PackedScene = preload("res://scenes/entity.tscn")
@export var player: Area2D

# Pool settings
const POOL_SIZE: int = 80
const SPAWN_RADIUS_MIN: float = 350.0
const SPAWN_RADIUS_MAX: float = 700.0
const DESPAWN_RADIUS: float = 900.0
const MAX_ACTIVE: int = 60
const SPAWN_INTERVAL_BASE: float = 0.4

# Entity size relative to player radius
const SIZE_RATIO_MIN: float = 0.15
const SIZE_RATIO_MAX: float = 3.2

var entity_pool: Array[Area2D] = []
var active_entities: Array[Area2D] = []
var spawn_timer: float = 0.0
var difficulty_time: float = 0.0

# Scale-specific settings
var current_scale_index: int = 0
var toxic_chance: float = 0.0  # Scale 3 introduces toxics

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
		spawn_timer = max(0.15, interval)

	_check_despawn()

func _spawn_batch() -> void:
	if active_entities.size() >= MAX_ACTIVE:
		return
	if not player:
		return

	var batch_count: int = randi_range(1, 3)
	for i in range(batch_count):
		if active_entities.size() >= MAX_ACTIVE:
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

	# Size: weighted toward edible (smaller than player)
	var size_roll: float = randf()
	var size_ratio: float
	if size_roll < 0.55:
		# Smaller — edible
		size_ratio = randf_range(SIZE_RATIO_MIN, 0.85)
	elif size_roll < 0.80:
		# Similar — neutral/slight danger
		size_ratio = randf_range(0.85, 1.15)
	else:
		# Larger — dangerous
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
	active_entities.append(entity)

func _get_entity_color(size_ratio: float, toxic: bool) -> Color:
	if toxic:
		return Color(0.5, 0.0, 0.8)  # Purple for toxic

	# Color by size: green (small/edible) → yellow (neutral) → red (dangerous)
	if size_ratio < 0.7:
		# Edible: green
		return Color(0.1, 0.9, 0.3)
	elif size_ratio < 1.0:
		# Slightly smaller: cyan
		return Color(0.1, 0.8, 0.8)
	elif size_ratio < 1.15:
		# Neutral: yellow
		return Color(0.9, 0.85, 0.1)
	elif size_ratio < 1.8:
		# Dangerous: orange-red
		return Color(1.0, 0.4, 0.1)
	else:
		# Very dangerous: deep red
		return Color(0.9, 0.05, 0.05)

func _check_despawn() -> void:
	if not player:
		return
	var to_remove: Array[Area2D] = []
	for entity in active_entities:
		if not is_instance_valid(entity):
			to_remove.append(entity)
			continue
		# Already returned to pool (eaten by player)
		if not entity.visible:
			to_remove.append(entity)
			continue
		var dist: float = entity.global_position.distance_to(player.global_position)
		if dist > DESPAWN_RADIUS:
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
		1:  # Atomic
			toxic_chance = 0.0
			difficulty_time = 20.0
		2:  # Molecular
			toxic_chance = 0.20

	# Clear active entities on scale change
	for entity in active_entities:
		if is_instance_valid(entity):
			_return_to_pool(entity)
	active_entities.clear()
	spawn_timer = 0.5
