extends Area2D

# Entity — represents a spawned particle/object in the world

enum EntityType { WANDERER, ORBITER, CHASER, ABSORBER, SPLITTER }

var entity_radius: float = 10.0
var is_toxic: bool = false
var is_active: bool = true
var scale_index: int = 0
var entity_type: EntityType = EntityType.WANDERER

# Visual
var entity_color: Color = Color.WHITE
var drift_velocity: Vector2 = Vector2.ZERO
var drift_speed: float = 20.0

# Wanderer: flocking behavior
var wander_timer: float = 0.0
var wander_interval: float = 2.5
var flock_id: int = -1
var spawner_ref: Node = null  # Reference to entity_spawner for flock queries

# Orbiter: orbits a point with drift
var orbit_center: Vector2 = Vector2.ZERO
var orbit_radius: float = 100.0
var orbit_angle: float = 0.0
var orbit_speed: float = 1.0
var orbit_base_speed: float = 1.0
var orbit_drift_timer: float = 0.0
var orbit_drift_interval: float = 12.0

# Chaser: smart pursuit with patience
var chase_speed: float = 30.0
var player_ref: Area2D = null
var patience_timer: float = 8.0
var is_fleeing: bool = false

# Absorber: gravity well
var pull_radius: float = 180.0
var pull_strength: float = 60.0

# Splitter: chain-split
var generation: int = 0  # 0 = original, 1 = first split, 2 = second split
const MAX_GENERATION: int = 2

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var circle_draw: Node2D = $CircleDraw

func _ready() -> void:
	_update_collision()

func _process(delta: float) -> void:
	if not is_active:
		return

	match entity_type:
		EntityType.WANDERER:
			_process_wanderer(delta)
		EntityType.ORBITER:
			_process_orbiter(delta)
		EntityType.CHASER:
			_process_chaser(delta)
		EntityType.ABSORBER:
			_process_absorber(delta)
		EntityType.SPLITTER:
			_process_splitter(delta)

# ── Wanderer: Flocking with player reaction ──────────────────────

func _process_wanderer(delta: float) -> void:
	# Base wander direction change
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 3.0)
		var angle: float = randf() * TAU
		drift_velocity = Vector2(cos(angle), sin(angle)) * drift_speed

	# Flocking behavior if we have a spawner reference
	if spawner_ref and flock_id >= 0:
		var flock_force: Vector2 = _calculate_flock_force()
		drift_velocity += flock_force * delta * 3.0

	# Player reaction
	if player_ref and is_instance_valid(player_ref):
		var to_player: Vector2 = player_ref.global_position - global_position
		var dist: float = to_player.length()
		var player_radius: float = 16.0
		if player_ref.has_method("get_player_radius"):
			player_radius = player_ref.get_player_radius()

		if dist < 200.0 and dist > 0.0:
			if player_radius > entity_radius * 1.2:
				# Player is bigger — scatter away
				var flee_dir: Vector2 = -to_player.normalized()
				drift_velocity = drift_velocity.lerp(flee_dir * drift_speed * 1.8, 4.0 * delta)
			elif entity_radius > player_radius * 1.2:
				# We're bigger — swarm toward player
				var chase_dir: Vector2 = to_player.normalized()
				drift_velocity = drift_velocity.lerp(chase_dir * drift_speed * 1.3, 2.0 * delta)

	# Clamp speed
	if drift_velocity.length() > drift_speed * 2.0:
		drift_velocity = drift_velocity.normalized() * drift_speed * 2.0

	global_position += drift_velocity * delta

func _calculate_flock_force() -> Vector2:
	if not spawner_ref or not is_instance_valid(spawner_ref):
		return Vector2.ZERO

	var separation: Vector2 = Vector2.ZERO
	var alignment: Vector2 = Vector2.ZERO
	var cohesion: Vector2 = Vector2.ZERO
	var neighbor_count: int = 0
	var center_of_mass: Vector2 = Vector2.ZERO
	var flock_radius: float = 150.0

	var active: Array = spawner_ref.active_entities
	for other in active:
		if not is_instance_valid(other) or other == self:
			continue
		if not "flock_id" in other or other.flock_id != flock_id:
			continue
		if not "entity_type" in other or other.entity_type != EntityType.WANDERER:
			continue

		var offset: Vector2 = global_position - other.global_position
		var dist: float = offset.length()

		if dist < flock_radius and dist > 0.0:
			neighbor_count += 1
			center_of_mass += other.global_position

			# Separation: push away from too-close neighbors
			if dist < 50.0:
				separation += offset.normalized() * (50.0 / dist)

			# Alignment: match neighbor velocity
			if "drift_velocity" in other:
				alignment += other.drift_velocity

	if neighbor_count > 0:
		center_of_mass /= float(neighbor_count)
		# Cohesion: steer toward center of flock
		cohesion = (center_of_mass - global_position).normalized() * drift_speed * 0.3
		alignment = (alignment / float(neighbor_count)).normalized() * drift_speed * 0.2

	return separation * 1.5 + alignment + cohesion

# ── Orbiter: Drift to new centers, panic on player approach ──────

func _process_orbiter(delta: float) -> void:
	# Drift to new orbit center periodically
	orbit_drift_timer -= delta
	if orbit_drift_timer <= 0.0:
		orbit_drift_timer = randf_range(10.0, 15.0)
		var drift_offset: Vector2 = Vector2(randf_range(-120, 120), randf_range(-120, 120))
		orbit_center += drift_offset

	# Panic response when player approaches
	var target_speed: float = orbit_base_speed
	if player_ref and is_instance_valid(player_ref):
		var dist: float = global_position.distance_to(player_ref.global_position)
		if dist < 150.0:
			# Panic: orbit faster
			var panic_factor: float = 1.0 + (1.0 - dist / 150.0) * 2.5
			target_speed = orbit_base_speed * panic_factor

	orbit_speed = lerpf(orbit_speed, target_speed, 3.0 * delta)

	orbit_angle += orbit_speed * delta
	if orbit_angle > TAU:
		orbit_angle -= TAU
	global_position = orbit_center + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius

# ── Chaser: Smart pursuit with prediction, patience, and flee ────

func _process_chaser(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		global_position += drift_velocity * delta
		return

	var player_radius: float = 16.0
	if player_ref.has_method("get_player_radius"):
		player_radius = player_ref.get_player_radius()

	# If player got very big, flee instead
	if player_radius > entity_radius * 1.5:
		is_fleeing = true

	if is_fleeing:
		var flee_dir: Vector2 = (global_position - player_ref.global_position).normalized()
		drift_velocity = drift_velocity.lerp(flee_dir * chase_speed * 1.2, 2.0 * delta)
		global_position += drift_velocity * delta
		# Patience: if fleeing for too long, become wanderer
		patience_timer -= delta
		if patience_timer <= 0.0:
			_convert_to_wanderer()
		return

	# Predictive pursuit: aim where player is going
	var player_vel: Vector2 = Vector2.ZERO
	if "velocity" in player_ref:
		player_vel = player_ref.velocity

	var to_player: Vector2 = player_ref.global_position - global_position
	var dist: float = to_player.length()
	var time_to_reach: float = dist / max(chase_speed, 1.0)
	var predicted_pos: Vector2 = player_ref.global_position + player_vel * time_to_reach * 0.5

	var dir: Vector2 = (predicted_pos - global_position).normalized()
	drift_velocity = drift_velocity.lerp(dir * chase_speed, 2.5 * delta)
	global_position += drift_velocity * delta

	# Patience countdown
	patience_timer -= delta
	if patience_timer <= 0.0:
		_convert_to_wanderer()

func _convert_to_wanderer() -> void:
	entity_type = EntityType.WANDERER
	wander_timer = randf_range(1.5, 3.0)
	flock_id = -1  # Solo wanderer after conversion

# ── Absorber: Gravity well that pulls nearby entities ────────────

func _process_absorber(delta: float) -> void:
	# Slow drift
	global_position += drift_velocity * delta * 0.3

	# Pull nearby entities toward us
	if spawner_ref and is_instance_valid(spawner_ref):
		for other in spawner_ref.active_entities:
			if not is_instance_valid(other) or other == self:
				continue
			if not other.visible or not other.is_active:
				continue
			var other_radius: float = other.entity_radius if "entity_radius" in other else 10.0
			if other_radius >= entity_radius:
				continue  # Only pull smaller entities

			var offset: Vector2 = global_position - other.global_position
			var dist: float = offset.length()
			if dist < pull_radius and dist > entity_radius:
				var pull_force: float = pull_strength * (1.0 - dist / pull_radius) * delta
				other.global_position += offset.normalized() * pull_force

	# Slow player in pull zone
	if player_ref and is_instance_valid(player_ref):
		var to_player: Vector2 = global_position - player_ref.global_position
		var dist: float = to_player.length()
		if dist < pull_radius and dist > 0.0:
			var slow_factor: float = (1.0 - dist / pull_radius) * 0.4
			if "velocity" in player_ref:
				player_ref.velocity *= (1.0 - slow_factor * delta * 3.0)
			# Gentle pull
			player_ref.global_position += to_player.normalized() * pull_strength * 0.3 * (1.0 - dist / pull_radius) * delta

# ── Splitter: Standard movement, splits handled by player on eat ─

func _process_splitter(delta: float) -> void:
	# Moves like a wanderer but slightly faster
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 2.5)
		var angle: float = randf() * TAU
		drift_velocity = Vector2(cos(angle), sin(angle)) * drift_speed * 1.2
	global_position += drift_velocity * delta

# ── Setup functions ──────────────────────────────────────────────

func setup(radius: float, toxic: bool, color: Color, speed: float, scale_idx: int) -> void:
	entity_radius = radius
	is_toxic = toxic
	entity_color = color
	drift_speed = speed
	scale_index = scale_idx
	var angle: float = randf() * TAU
	drift_velocity = Vector2(cos(angle), sin(angle)) * drift_speed
	is_active = true
	wander_timer = randf_range(1.5, 3.0)
	patience_timer = 8.0
	is_fleeing = false
	generation = 0
	_update_collision()
	if circle_draw:
		circle_draw.queue_redraw()

func setup_as_wanderer() -> void:
	entity_type = EntityType.WANDERER
	wander_timer = randf_range(1.5, 3.0)

func setup_as_orbiter(center: Vector2, radius: float) -> void:
	entity_type = EntityType.ORBITER
	orbit_center = center
	orbit_radius = radius
	orbit_angle = randf() * TAU
	orbit_base_speed = randf_range(0.5, 1.5) * (1.0 if randf() > 0.5 else -1.0)
	orbit_speed = orbit_base_speed
	orbit_drift_timer = randf_range(10.0, 15.0)

func setup_as_chaser(player: Area2D, speed: float) -> void:
	entity_type = EntityType.CHASER
	player_ref = player
	chase_speed = speed
	patience_timer = 8.0
	is_fleeing = false

func setup_as_absorber(player: Area2D) -> void:
	entity_type = EntityType.ABSORBER
	player_ref = player
	pull_radius = entity_radius * 6.0
	pull_strength = 60.0

func setup_as_splitter(gen: int) -> void:
	entity_type = EntityType.SPLITTER
	generation = gen
	wander_timer = randf_range(1.0, 2.0)

func _update_collision() -> void:
	if collision_shape and collision_shape.shape:
		(collision_shape.shape as CircleShape2D).radius = entity_radius

func get_entity_data() -> Dictionary:
	return {
		"radius": entity_radius,
		"is_toxic": is_toxic,
		"color": entity_color,
		"entity_type": entity_type,
		"generation": generation,
	}

func reset_entity(radius: float, toxic: bool, color: Color, speed: float, pos: Vector2, scale_idx: int) -> void:
	global_position = pos
	monitoring = true
	monitorable = true
	setup(radius, toxic, color, speed, scale_idx)
	show()
	set_process(true)
