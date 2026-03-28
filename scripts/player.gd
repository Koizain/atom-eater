extends Area2D

signal eaten_entity(mass_gained: float)
signal player_died_signal()

# Visual node references
@onready var circle_draw: Node2D = $CircleDraw
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Movement settings
const BASE_SPEED: float = 220.0
const DRIFT_FORCE: float = 6.5
const DASH_SPEED: float = 850.0
const DASH_DURATION: float = 0.18
const DASH_COOLDOWN: float = 0.8

# State
var velocity: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var is_dead: bool = false

# Size
var player_radius: float = GameData.PLAYER_START_RADIUS
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 1.5

# Upgrades
var absorption_radius_bonus: float = 0.0
var mass_efficiency_bonus: float = 0.0
var dash_cooldown_reduction: float = 0.0

# Scale manager reference
var scale_manager: Node = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_update_radius()
	_update_visual()

func _process(delta: float) -> void:
	if is_dead:
		return

	_handle_movement(delta)
	_handle_dash_cooldown(delta)
	_handle_combo_timer(delta)
	_check_scale_transition()

func _handle_movement(delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var direction: Vector2 = (mouse_pos - global_position)
	var dist: float = direction.length()

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		else:
			velocity = dash_direction * DASH_SPEED
	else:
		if dist > 5.0:
			var target_vel: Vector2 = direction.normalized() * BASE_SPEED
			# Drift: smoothly interpolate toward target velocity
			velocity = velocity.lerp(target_vel, DRIFT_FORCE * delta)
		else:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)

	global_position += velocity * delta

func _handle_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

func _handle_combo_timer(delta: float) -> void:
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_try_dash()

func _try_dash() -> void:
	if dash_cooldown_timer > 0.0 or is_dashing:
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	dash_direction = (mouse_pos - global_position).normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT
	is_dashing = true
	dash_timer = DASH_DURATION
	var effective_cooldown: float = DASH_COOLDOWN * (1.0 - dash_cooldown_reduction)
	dash_cooldown_timer = max(0.3, effective_cooldown)

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if not area.has_method("get_entity_data"):
		return

	var entity_data: Dictionary = area.get_entity_data()
	var entity_radius: float = entity_data.get("radius", 10.0)
	var is_toxic: bool = entity_data.get("is_toxic", false)

	# Check if scale manager says we're invincible
	if scale_manager and scale_manager.is_player_invincible():
		return

	if is_toxic:
		# Toxic: lose mass on contact
		_take_toxic_damage(entity_radius * 0.3)
		_return_entity_to_pool(area)
		return

	# Size comparison — GDD: eat if < 110% our size, danger if > 110% our size
	# Neutral zone: exactly 1.1x (bounce off — handled by physics naturally)
	if entity_radius < player_radius * 1.1:
		# We can eat it
		_absorb_entity(area, entity_radius)
	elif entity_radius > player_radius * 1.1:
		# It can eat us — danger!
		_take_damage()

func _absorb_entity(entity: Area2D, entity_radius: float) -> void:
	var mass_gain: float = entity_radius * entity_radius * PI * 0.02
	mass_gain *= (1.0 + mass_efficiency_bonus)
	GameData.player_mass += mass_gain
	GameData.objects_eaten += 1

	# Combo
	combo_count += 1
	combo_timer = COMBO_WINDOW
	if combo_count > GameData.max_combo:
		GameData.max_combo = combo_count

	eaten_entity.emit(mass_gain)
	_update_radius()
	_update_visual()

	# Return entity to pool (don't free it!)
	_return_entity_to_pool(entity)

func _take_damage() -> void:
	# Shrink player significantly (eaten partially)
	GameData.player_mass *= 0.6
	if GameData.player_mass < 1.0:
		_die()
	else:
		_update_radius()
		_update_visual()
		_shake(8.0, 0.3)

func _take_toxic_damage(amount: float) -> void:
	GameData.player_mass -= amount
	if GameData.player_mass < 1.0:
		_die()
	else:
		_update_radius()
		_update_visual()
		_shake(4.0, 0.2)

func _shake(strength: float, duration: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(strength, duration)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	GameData.deaths_this_session += 1
	player_died_signal.emit()

func _update_radius() -> void:
	# Radius grows with mass (square root relationship for area)
	var base_r: float = GameData.PLAYER_START_RADIUS
	player_radius = base_r * sqrt(GameData.player_mass / 10.0)
	player_radius = clamp(player_radius, 8.0, 120.0)

	if collision_shape and collision_shape.shape:
		(collision_shape.shape as CircleShape2D).radius = player_radius

func _check_scale_transition() -> void:
	if scale_manager:
		scale_manager.check_scale_transition(GameData.player_mass)

func _update_visual() -> void:
	if circle_draw:
		circle_draw.queue_redraw()

func get_player_radius() -> float:
	return player_radius

func apply_upgrade(upgrade_type: String) -> void:
	match upgrade_type:
		"absorption_radius":
			absorption_radius_bonus += 0.3
		"mass_efficiency":
			mass_efficiency_bonus += 0.2
		"dash_cooldown":
			dash_cooldown_reduction += 0.35

func _return_entity_to_pool(entity: Area2D) -> void:
	# Signal the spawner to reclaim it
	entity.hide()
	entity.set_process(false)
	entity.monitoring = false
	entity.monitorable = false

func get_absorption_radius() -> float:
	return player_radius * (1.2 + absorption_radius_bonus)
