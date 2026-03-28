extends Area2D

# Entity — represents a spawned particle/object in the world

var entity_radius: float = 10.0
var is_toxic: bool = false
var is_active: bool = true
var scale_index: int = 0

# Visual
var entity_color: Color = Color.WHITE
var drift_velocity: Vector2 = Vector2.ZERO
var drift_speed: float = 20.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var circle_draw: Node2D = $CircleDraw

func _ready() -> void:
	_update_collision()

func _process(delta: float) -> void:
	if not is_active:
		return
	global_position += drift_velocity * delta

func setup(radius: float, toxic: bool, color: Color, speed: float, scale_idx: int) -> void:
	entity_radius = radius
	is_toxic = toxic
	entity_color = color
	drift_speed = speed
	scale_index = scale_idx
	# Random drift direction
	var angle: float = randf() * TAU
	drift_velocity = Vector2(cos(angle), sin(angle)) * drift_speed
	is_active = true
	_update_collision()
	if circle_draw:
		circle_draw.queue_redraw()

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
