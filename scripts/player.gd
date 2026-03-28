extends Area2D

signal eaten_entity(mass_gained: float)
signal player_died_signal()
signal combo_changed(combo: int, multiplier: float)
signal player_hit()

# Visual node references
@onready var circle_draw: Node2D = $CircleDraw
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trail_line: Line2D = $TrailLine

# Movement settings
const BASE_SPEED: float = 280.0
const DRIFT_FORCE: float = 5.0
const DASH_SPEED: float = 850.0
const DASH_DURATION: float = 0.18
const DASH_COOLDOWN: float = 0.8
const MIN_SPEED_FACTOR: float = 0.35  # Minimum speed multiplier at max size

# State
var velocity: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var is_dead: bool = false

# Dash juice
var _dash_freeze: bool = false
var _afterimage_timer: float = 0.0
const AFTERIMAGE_INTERVAL: float = 0.045
var _trail_target_width: float = 4.0

# Size
var player_radius: float = GameData.PLAYER_START_RADIUS
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 1.8

# Eat pop effect
var eat_pop_timer: float = 0.0
var eat_pop_scale: float = 1.0

# Trail
const TRAIL_MAX_POINTS: int = 20
const TRAIL_POINT_INTERVAL: float = 0.03
var trail_timer: float = 0.0

# Upgrades
var absorption_radius_bonus: float = 0.0
var mass_efficiency_bonus: float = 0.0
var dash_cooldown_reduction: float = 0.0

# Scale manager reference
var scale_manager: Node = null

# Viewport size for screen wrapping
var viewport_size: Vector2 = Vector2(1920, 1080)

# Hit invincibility
var hit_invincible_timer: float = 0.0
const HIT_INVINCIBLE_DURATION: float = 1.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_update_radius()
	_update_visual()
	viewport_size = get_viewport_rect().size

	# Setup trail
	if trail_line:
		trail_line.width = 4.0
		trail_line.default_color = GameData.get_scale_color()
		trail_line.gradient = Gradient.new()
		trail_line.gradient.set_color(0, Color(1, 1, 1, 0.5))
		trail_line.gradient.set_color(1, Color(1, 1, 1, 0.0))

func _process(delta: float) -> void:
	if is_dead:
		return

	_handle_movement(delta)
	_handle_dash_cooldown(delta)
	_handle_combo_timer(delta)
	_handle_eat_pop(delta)
	_handle_trail(delta)
	_handle_hit_invincibility(delta)
	_handle_afterimages(delta)
	_check_scale_transition()

func _handle_movement(delta: float) -> void:
	if _dash_freeze:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var direction: Vector2 = (mouse_pos - global_position)
	var dist: float = direction.length()

	# Speed scales inversely with size
	var size_factor: float = GameData.PLAYER_START_RADIUS / max(player_radius, 1.0)
	var speed_mult: float = clamp(lerp(1.0, MIN_SPEED_FACTOR, 1.0 - size_factor), MIN_SPEED_FACTOR, 1.0)
	var current_speed: float = BASE_SPEED * speed_mult

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			_trail_target_width = 4.0
		else:
			velocity = dash_direction * DASH_SPEED * speed_mult
	else:
		if dist > 5.0:
			var target_vel: Vector2 = direction.normalized() * current_speed
			# Smooth drift with momentum/inertia
			velocity = velocity.lerp(target_vel, DRIFT_FORCE * delta)
		else:
			velocity = velocity.lerp(Vector2.ZERO, 4.0 * delta)

	global_position += velocity * delta

	# Screen wrap (toroidal space) — relative to camera
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam:
		var cam_pos: Vector2 = cam.global_position
		var half_w: float = viewport_size.x * 0.6
		var half_h: float = viewport_size.y * 0.6
		if global_position.x > cam_pos.x + half_w:
			global_position.x -= half_w * 2.0
		elif global_position.x < cam_pos.x - half_w:
			global_position.x += half_w * 2.0
		if global_position.y > cam_pos.y + half_h:
			global_position.y -= half_h * 2.0
		elif global_position.y < cam_pos.y - half_h:
			global_position.y += half_h * 2.0

func _handle_dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

func _handle_combo_timer(delta: float) -> void:
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			combo_changed.emit(0, 1.0)

func _handle_eat_pop(delta: float) -> void:
	if eat_pop_timer > 0.0:
		eat_pop_timer -= delta
		# Quick scale up then back down
		var t: float = eat_pop_timer / 0.15
		eat_pop_scale = 1.0 + 0.15 * sin(t * PI)
		if circle_draw:
			circle_draw.scale = Vector2(eat_pop_scale, eat_pop_scale)
	elif eat_pop_scale != 1.0:
		eat_pop_scale = 1.0
		if circle_draw:
			circle_draw.scale = Vector2.ONE

func _handle_trail(delta: float) -> void:
	if not trail_line:
		return

	# Smooth trail width transitions (wider during dash)
	trail_line.width = lerpf(trail_line.width, _trail_target_width, 10.0 * delta)

	trail_timer -= delta
	if trail_timer <= 0.0 and velocity.length() > 20.0:
		trail_timer = TRAIL_POINT_INTERVAL
		trail_line.add_point(Vector2.ZERO)
		if trail_line.get_point_count() > TRAIL_MAX_POINTS:
			trail_line.remove_point(0)

	# Move existing points away (they stay in world space effect)
	for i in range(trail_line.get_point_count()):
		var pt: Vector2 = trail_line.get_point_position(i)
		pt -= velocity * delta  # Counter-move to stay in world space
		trail_line.set_point_position(i, pt)

	# Trail color: brighter and more opaque during dash
	var base_color: Color = GameData.get_scale_color()
	if is_dashing:
		trail_line.default_color = Color(
			minf(base_color.r + 0.4, 1.0),
			minf(base_color.g + 0.4, 1.0),
			minf(base_color.b + 0.4, 1.0),
			0.8
		)
	else:
		trail_line.default_color = base_color

func _handle_hit_invincibility(delta: float) -> void:
	if hit_invincible_timer > 0.0:
		hit_invincible_timer -= delta
		# Flash effect
		if circle_draw:
			circle_draw.modulate.a = 0.4 + 0.6 * abs(sin(hit_invincible_timer * 12.0))
	elif circle_draw and circle_draw.modulate.a != 1.0:
		circle_draw.modulate.a = 1.0

func _handle_afterimages(delta: float) -> void:
	if is_dashing:
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = AFTERIMAGE_INTERVAL
			_spawn_afterimage()

func _spawn_afterimage() -> void:
	if get_parent() and get_parent().has_method("add_afterimage"):
		var color: Color = GameData.get_scale_color()
		get_parent().add_afterimage(global_position, player_radius, color)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_try_dash()

func _try_dash() -> void:
	if dash_cooldown_timer > 0.0 or is_dashing or _dash_freeze:
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	dash_direction = (mouse_pos - global_position).normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT

	# Freeze frame before dash — brief time-slow for punch
	_dash_freeze = true
	Engine.time_scale = 0.1
	get_tree().create_timer(0.05, true, false, true).timeout.connect(_launch_dash)

func _launch_dash() -> void:
	Engine.time_scale = 1.0
	_dash_freeze = false

	if is_dead:
		return

	is_dashing = true
	dash_timer = DASH_DURATION
	var effective_cooldown: float = DASH_COOLDOWN * (1.0 - dash_cooldown_reduction)
	dash_cooldown_timer = max(0.3, effective_cooldown)
	_afterimage_timer = 0.0

	# Widen trail during dash
	_trail_target_width = 12.0

	# Dash screen shake
	_shake(8.0, 0.15)

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
		_take_toxic_damage(entity_radius * 0.3)
		_return_entity_to_pool(area)
		return

	# Size comparison — eat if < 110% our size, danger if > 110%
	if entity_radius < player_radius * 1.1:
		_absorb_entity(area, entity_radius)
	elif entity_radius > player_radius * 1.1:
		_take_damage()

func _absorb_entity(entity: Area2D, entity_radius: float) -> void:
	var mass_gain: float = entity_radius * entity_radius * PI * 0.02
	mass_gain *= (1.0 + mass_efficiency_bonus)

	# Combo
	combo_count += 1
	combo_timer = COMBO_WINDOW
	if combo_count > GameData.max_combo:
		GameData.max_combo = combo_count

	# Combo multiplier
	var multiplier: float = GameData.get_combo_multiplier(combo_count)
	mass_gain *= multiplier
	combo_changed.emit(combo_count, multiplier)

	GameData.player_mass += mass_gain
	GameData.objects_eaten += 1

	# Eat pop effect
	eat_pop_timer = 0.15

	# Tiered eat impact based on size ratio
	var size_ratio: float = entity_radius / player_radius
	var entity_pos: Vector2 = entity.global_position

	if size_ratio > 0.7:
		# BOOM — large eat: freeze frame, heavy shake, zoom punch, shockwave
		_freeze_frame(0.06)
		_shake(16.0, 0.4)
		_screen_pulse()
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam and cam.has_method("zoom_punch"):
			cam.zoom_punch(0.05)
		if get_parent() and get_parent().has_method("spawn_shockwave"):
			get_parent().spawn_shockwave(entity_pos)
	elif size_ratio > 0.35:
		# Crunch — medium eat: moderate shake, small zoom punch
		_shake(6.0, 0.2)
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam and cam.has_method("zoom_punch"):
			cam.zoom_punch(0.02)
	else:
		# Pop — small eat: tiny zoom nudge (eat_pop handles the rest)
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam and cam.has_method("zoom_punch"):
			cam.zoom_punch(0.008)

	eaten_entity.emit(mass_gain)
	_update_radius()
	_update_visual()

	# Spawn floating text at entity position
	if get_parent() and get_parent().has_method("spawn_floating_text"):
		var text: String = "+%.0f" % mass_gain
		if multiplier > 1.0:
			text = "+%.0f x%.1f" % [mass_gain, multiplier]
		get_parent().spawn_floating_text(entity_pos, text, size_ratio > 0.7)

	_return_entity_to_pool(entity)

func _freeze_frame(real_duration: float) -> void:
	if Engine.time_scale < 0.5:
		return  # Already in a freeze — don't stack
	Engine.time_scale = 0.05
	get_tree().create_timer(real_duration, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0
	)

func _screen_pulse() -> void:
	if get_parent() and get_parent().has_method("screen_flash"):
		get_parent().screen_flash(Color(1, 1, 1, 0.3), 0.2)

func _take_damage() -> void:
	if hit_invincible_timer > 0.0:
		return

	var is_dead_now: bool = GameData.take_damage()
	hit_invincible_timer = HIT_INVINCIBLE_DURATION
	player_hit.emit()

	if is_dead_now:
		_die()
	else:
		# Shrink a bit
		GameData.player_mass *= 0.8
		_update_radius()
		_update_visual()
		_shake(10.0, 0.4)
		# Screen red flash
		if get_parent() and get_parent().has_method("screen_flash"):
			get_parent().screen_flash(Color(1, 0, 0, 0.4), 0.3)

func _take_toxic_damage(amount: float) -> void:
	if hit_invincible_timer > 0.0:
		return
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

	# Restore time scale in case we're mid-freeze
	Engine.time_scale = 1.0

	# Death implosion animation
	if circle_draw:
		var tween: Tween = create_tween()
		tween.tween_property(circle_draw, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(circle_draw, "scale", Vector2(0.01, 0.01), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_property(circle_draw, "modulate:a", 0.0, 0.15)

	# Screen red
	if get_parent() and get_parent().has_method("screen_flash"):
		get_parent().screen_flash(Color(1, 0, 0, 0.6), 0.5)

	player_died_signal.emit()

func _update_radius() -> void:
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
	entity.hide()
	entity.set_process(false)
	entity.monitoring = false
	entity.monitorable = false

func get_absorption_radius() -> float:
	return player_radius * (1.2 + absorption_radius_bonus)
