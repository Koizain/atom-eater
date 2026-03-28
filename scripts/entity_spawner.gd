extends Node2D

@export var entity_scene: PackedScene = preload("res://scenes/entity.tscn")
var player = null

# Pool settings
const POOL_SIZE: int = 150
const DESPAWN_RADIUS: float = 800.0
const SPAWN_INTERVAL_BASE: float = 0.35
const RECYCLE_DISTANCE: float = 800.0

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

# Wave system
var wave_timer: float = 15.0
const WAVE_INTERVAL: float = 15.0
const WAVE_MIN_COUNT: int = 8
const WAVE_MAX_COUNT: int = 12

# Flock system
var next_flock_id: int = 0
var flock_spawn_counter: Dictionary = {}  # flock_id -> count spawned so far
const FLOCK_SIZE_MIN: int = 5
const FLOCK_SIZE_MAX: int = 7

# Migration herd system
var migration_timer: float = 20.0
const MIGRATION_INTERVAL: float = 20.0

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

	# Wave spawns
	wave_timer -= delta
	if wave_timer <= 0.0:
		wave_timer = WAVE_INTERVAL
		_spawn_wave()

	# Migration herds
	migration_timer -= delta
	if migration_timer <= 0.0:
		migration_timer = MIGRATION_INTERVAL
		_spawn_migration_herd()

	_check_despawn_and_recycle()

# ── Off-screen spawn position (viewport edge) ────────────────────

func _get_offscreen_spawn_pos() -> Vector2:
	if not player:
		return Vector2.ZERO
	var vp: Vector2 = get_viewport_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = cam.global_position if cam else player.global_position
	var half_w: float = vp.x * 0.55
	var half_h: float = vp.y * 0.55

	# Pick a random edge: 0=top, 1=bottom, 2=left, 3=right
	var edge: int = randi() % 4
	var pos: Vector2
	match edge:
		0:  # Top
			pos = Vector2(cam_pos.x + randf_range(-half_w, half_w), cam_pos.y - half_h - randf_range(20, 80))
		1:  # Bottom
			pos = Vector2(cam_pos.x + randf_range(-half_w, half_w), cam_pos.y + half_h + randf_range(20, 80))
		2:  # Left
			pos = Vector2(cam_pos.x - half_w - randf_range(20, 80), cam_pos.y + randf_range(-half_h, half_h))
		_:  # Right
			pos = Vector2(cam_pos.x + half_w + randf_range(20, 80), cam_pos.y + randf_range(-half_h, half_h))
	return pos

# ── Batch spawning ───────────────────────────────────────────────

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

	var spawn_pos: Vector2 = _get_offscreen_spawn_pos()

	# Size distribution with danger escalation
	var size_roll: float = randf()
	var size_ratio: float
	var danger_bias: float = _get_danger_bias()

	# Shift distribution toward larger entities as danger increases
	var small_threshold: float = 0.60 - danger_bias * 0.2
	var medium_threshold: float = 0.90 - danger_bias * 0.1

	if size_roll < small_threshold:
		size_ratio = randf_range(SIZE_RATIO_MIN, 0.7)
	elif size_roll < medium_threshold:
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

	# Give entity references
	entity.player_ref = player
	entity.spawner_ref = self

	# Determine entity type based on scale and conditions
	_assign_entity_type(entity, size_ratio, player_radius, spawn_pos)

	active_entities.append(entity)

func _assign_entity_type(entity: Area2D, size_ratio: float, player_radius: float, spawn_pos: Vector2) -> void:
	# Absorbers: scale 2+, low chance, always large
	if current_scale_index >= 2 and size_ratio > 1.5 and randf() < 0.08:
		entity.entity_radius = clamp(player_radius * randf_range(1.8, 2.8), 20.0, 150.0)
		entity.entity_color = Color(0.8, 0.2, 0.9)  # Deep purple
		entity.is_toxic = false
		entity._update_collision()
		entity.setup_as_absorber(player)
		return

	# Splitters: scale 3+, medium chance, medium size
	if current_scale_index >= 3 and size_ratio > 0.5 and size_ratio < 1.2 and randf() < 0.12:
		entity.entity_color = Color(0.2, 0.9, 0.9)  # Bright cyan
		entity.is_toxic = false
		entity.setup_as_splitter(0)
		return

	# Chasers: only when player mass > 40% of threshold, entity must be bigger
	var threshold: float = GameData.get_scale_threshold()
	var mass_progress: float = GameData.player_mass / threshold if threshold > 0 else 0.0

	var type_roll: float = randf()
	if type_roll < 0.55:
		# Wanderer with flock assignment
		entity.setup_as_wanderer()
		_assign_flock(entity)
	elif type_roll < 0.80:
		# Orbiter
		var orbit_center: Vector2 = spawn_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var orbit_r: float = randf_range(40.0, 120.0)
		entity.setup_as_orbiter(orbit_center, orbit_r)
	else:
		# Chaser: only if conditions met
		if mass_progress > 0.4 and size_ratio > 1.0 and player_radius > 20.0:
			entity.setup_as_chaser(player, randf_range(25.0, 55.0))
		else:
			entity.setup_as_wanderer()
			_assign_flock(entity)

func _assign_flock(entity: Area2D) -> void:
	# Find an existing flock that needs more members
	for fid in flock_spawn_counter.keys():
		if flock_spawn_counter[fid] < FLOCK_SIZE_MAX:
			entity.flock_id = fid
			flock_spawn_counter[fid] += 1
			return

	# Create new flock
	entity.flock_id = next_flock_id
	flock_spawn_counter[next_flock_id] = 1
	next_flock_id += 1

# ── Wave spawning: burst of one type ─────────────────────────────

func _spawn_wave() -> void:
	if not player:
		return
	var count: int = randi_range(WAVE_MIN_COUNT, WAVE_MAX_COUNT)
	var player_radius: float = 16.0
	if player.has_method("get_player_radius"):
		player_radius = player.get_player_radius()

	# Pick a wave type biased by scale
	var wave_types: Array[int] = [0]  # Wanderer always available
	if current_scale_index >= 1:
		wave_types.append(1)  # Orbiter
	if current_scale_index >= 2:
		wave_types.append(4)  # Splitter
	var wave_type: int = wave_types[randi() % wave_types.size()]

	# Spawn from one side of the screen
	var edge: int = randi() % 4
	var vp: Vector2 = get_viewport_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = cam.global_position if cam else player.global_position

	var wave_flock_id: int = next_flock_id
	next_flock_id += 1
	flock_spawn_counter[wave_flock_id] = 0

	for i in range(count):
		if active_entities.size() >= max_active:
			break
		var entity: Area2D = _get_pooled_entity()
		if entity == null:
			break

		# Wave entities are smaller (food wave) — 60% of time
		var size_ratio: float
		if randf() < 0.6:
			size_ratio = randf_range(0.2, 0.6)
		else:
			size_ratio = randf_range(0.6, 1.0)
		var radius: float = clamp(player_radius * size_ratio, 4.0, 100.0)

		# All spawn from same edge with spread
		var pos: Vector2 = _get_wave_spawn_pos(edge, cam_pos, vp, i, count)

		var color: Color = _get_entity_color(size_ratio, false)
		var speed: float = randf_range(20.0, 50.0)

		if entity.has_method("reset_entity"):
			entity.reset_entity(radius, false, color, speed, pos, current_scale_index)
		entity.show()
		entity.set_process(true)
		entity.player_ref = player
		entity.spawner_ref = self

		match wave_type:
			0:  # Wanderer wave
				entity.setup_as_wanderer()
				entity.flock_id = wave_flock_id
				flock_spawn_counter[wave_flock_id] += 1
				# Give them a drift toward center
				var to_center: Vector2 = (cam_pos - pos).normalized()
				entity.drift_velocity = to_center * speed
			1:  # Orbiter wave
				var orbit_center: Vector2 = cam_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200))
				entity.setup_as_orbiter(orbit_center, randf_range(60.0, 140.0))
			4:  # Splitter wave
				entity.entity_color = Color(0.2, 0.9, 0.9)
				entity.setup_as_splitter(0)

		active_entities.append(entity)

func _get_wave_spawn_pos(edge: int, cam_pos: Vector2, vp: Vector2, idx: int, total: int) -> Vector2:
	var half_w: float = vp.x * 0.55
	var half_h: float = vp.y * 0.55
	var spread: float = float(idx) / max(float(total - 1), 1.0) - 0.5  # -0.5 to 0.5

	match edge:
		0:  # Top
			return Vector2(cam_pos.x + spread * vp.x * 0.8, cam_pos.y - half_h - randf_range(20, 60))
		1:  # Bottom
			return Vector2(cam_pos.x + spread * vp.x * 0.8, cam_pos.y + half_h + randf_range(20, 60))
		2:  # Left
			return Vector2(cam_pos.x - half_w - randf_range(20, 60), cam_pos.y + spread * vp.y * 0.8)
		_:  # Right
			return Vector2(cam_pos.x + half_w + randf_range(20, 60), cam_pos.y + spread * vp.y * 0.8)

# ── Migration herd ───────────────────────────────────────────────

func _spawn_migration_herd() -> void:
	if not player:
		return
	var count: int = randi_range(6, 10)
	var player_radius: float = 16.0
	if player.has_method("get_player_radius"):
		player_radius = player.get_player_radius()

	var vp: Vector2 = get_viewport_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = cam.global_position if cam else player.global_position

	# Pick entry and exit edges (opposite sides)
	var entry_edge: int = randi() % 4
	var migration_dir: Vector2
	match entry_edge:
		0: migration_dir = Vector2(0, 1)   # Top → Bottom
		1: migration_dir = Vector2(0, -1)  # Bottom → Top
		2: migration_dir = Vector2(1, 0)   # Left → Right
		_: migration_dir = Vector2(-1, 0)  # Right → Left

	var herd_flock_id: int = next_flock_id
	next_flock_id += 1
	flock_spawn_counter[herd_flock_id] = 0

	for i in range(count):
		if active_entities.size() >= max_active:
			break
		var entity: Area2D = _get_pooled_entity()
		if entity == null:
			break

		var size_ratio: float = randf_range(0.3, 0.8)
		var radius: float = clamp(player_radius * size_ratio, 4.0, 80.0)
		var pos: Vector2 = _get_wave_spawn_pos(entry_edge, cam_pos, vp, i, count)
		var color: Color = _get_entity_color(size_ratio, false)
		var speed: float = randf_range(30.0, 50.0)

		if entity.has_method("reset_entity"):
			entity.reset_entity(radius, false, color, speed, pos, current_scale_index)
		entity.show()
		entity.set_process(true)
		entity.player_ref = player
		entity.spawner_ref = self

		entity.setup_as_wanderer()
		entity.flock_id = herd_flock_id
		flock_spawn_counter[herd_flock_id] += 1
		# Give strong drift in migration direction
		entity.drift_velocity = migration_dir * speed * 1.5

		active_entities.append(entity)

# ── Danger escalation ────────────────────────────────────────────

func _get_danger_bias() -> float:
	# Returns 0.0 to 1.0: how much to shift spawn toward larger/dangerous entities
	var scale_bias: float = current_scale_index * 0.1
	var progress: float = GameData.get_scale_progress()
	return clamp(scale_bias + progress * 0.3, 0.0, 0.6)

# ── Splitter spawn helper (called by player on eating a splitter) ─

func spawn_split_children(pos: Vector2, parent_radius: float, parent_generation: int, parent_color: Color) -> void:
	if parent_generation >= 2:
		return  # Max 3 generations (0, 1, 2)

	for i in range(2):
		var entity: Area2D = _get_pooled_entity()
		if entity == null:
			break

		var child_radius: float = parent_radius * 0.65
		var offset: Vector2 = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var child_pos: Vector2 = pos + offset
		var speed: float = randf_range(25.0, 45.0)

		# Slightly different color per generation
		var gen_color: Color = parent_color.lightened(0.15)

		if entity.has_method("reset_entity"):
			entity.reset_entity(child_radius, false, gen_color, speed, child_pos, current_scale_index)
		entity.show()
		entity.set_process(true)
		entity.player_ref = player
		entity.spawner_ref = self
		entity.setup_as_splitter(parent_generation + 1)

		active_entities.append(entity)

# ── Color assignment ─────────────────────────────────────────────

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

# ── Despawn and recycle ──────────────────────────────────────────

func _check_despawn_and_recycle() -> void:
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
		if d > RECYCLE_DISTANCE:
			# Recycle: teleport to new off-screen position instead of despawning
			entity.global_position = _get_offscreen_spawn_pos()
			# Reset wander timer for fresh behavior
			if "wander_timer" in entity:
				entity.wander_timer = randf_range(1.0, 2.0)

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
	# Clean up flock tracking
	if "flock_id" in entity and entity.flock_id >= 0:
		if flock_spawn_counter.has(entity.flock_id):
			flock_spawn_counter[entity.flock_id] -= 1
			if flock_spawn_counter[entity.flock_id] <= 0:
				flock_spawn_counter.erase(entity.flock_id)

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
			toxic_chance = 0.15
			max_active = 80
		3:  # Cellular
			toxic_chance = 0.20
			max_active = 90
		4:  # Planetary
			toxic_chance = 0.25
			max_active = 100

	# Clear active entities on scale change
	for entity in active_entities:
		if is_instance_valid(entity):
			_return_to_pool(entity)
	active_entities.clear()
	flock_spawn_counter.clear()
	spawn_timer = 0.3
	wave_timer = 8.0  # First wave comes sooner on new scale
