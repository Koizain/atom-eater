extends Area2D

# Entity — represents a spawned particle/object in the world

enum EntityType { WANDERER, ORBITER, CHASER }

var entity_radius: float = 10.0
var is_toxic: bool = false
var is_active: bool = true
var scale_index: int = 0
var entity_type: EntityType = EntityType.WANDERER

# Visual
var entity_color: Color = Color.WHITE
var drift_velocity: Vector2 = Vector2.ZERO
var drift_speed: float = 20.0

# Wanderer: changes direction every 2-3s
var wander_timer: float = 0.0
var wander_interval: float = 2.5

# Orbiter: orbits a fixed point
var orbit_center: Vector2 = Vector2.ZERO
var orbit_radius: float = 100.0
var orbit_angle: float = 0.0
var orbit_speed: float = 1.0

# Chaser: slowly moves toward player
var chase_speed: float = 30.0
var player_ref: Area2D = null

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

func _process_wanderer(delta: float) -> void:
	global_position += drift_velocity * delta
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 3.0)
		var angle: float = randf() * TAU
		drift_velocity = Vector2(cos(angle), sin(angle)) * drift_speed

func _process_orbiter(delta: float) -> void:
	orbit_angle += orbit_speed * delta
	if orbit_angle > TAU:
		orbit_angle -= TAU
	global_position = orbit_center + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius

func _process_chaser(delta: float) -> void:
	if player_ref and is_instance_valid(player_ref):
		var dir: Vector2 = (player_ref.global_position - global_position).normalized()
		drift_velocity = drift_velocity.lerp(dir * chase_speed, 1.5 * get_process_delta_time())
	global_position += drift_velocity * delta

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
	orbit_speed = randf_range(0.5, 1.5) * (1.0 if randf() > 0.5 else -1.0)

func setup_as_chaser(player: Area2D, speed: float) -> void:
	entity_type = EntityType.CHASER
	player_ref = player
	chase_speed = speed

func _update_collision() -> void:
	if collision_shape and collision_shape.shape:
		(collision_shape.shape as CircleShape2D).radius = entity_radius

func get_entity_data() -> Dictionary:
	return {
		"radius": entity_radius,
		"is_toxic": is_toxic,
		"color": entity_color,
	}

func reset_entity(radius: float, toxic: bool, color: Color, speed: float, pos: Vector2, scale_idx: int) -> void:
	global_position = pos
	monitoring = true
	monitorable = true
	setup(radius, toxic, color, speed, scale_idx)
	show()
	set_process(true)
