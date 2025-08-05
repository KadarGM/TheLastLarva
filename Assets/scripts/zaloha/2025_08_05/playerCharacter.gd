extends BaseCharacter
class_name PlayerCharacter

@onready var big_attack_area: Area2D = $Areas/BigAttackArea
@onready var big_attack_area_2: Area2D = $Areas/BigAttackArea2

@onready var big_jump_timer: Timer = $Timers/BigJumpTimer
@onready var big_jump_cooldown_timer: Timer = $Timers/BigJumpCooldownTimer

@onready var near_ground_ray: RayCast2D = $RayCasts/NearGroundRay
@onready var near_ground_ray_2: RayCast2D = $RayCasts/NearGroundRay2
@onready var near_ground_ray_3: RayCast2D = $RayCasts/NearGroundRay3
@onready var ceiling_ray: RayCast2D = $RayCasts/CeilingRay
@onready var ceiling_ray_2: RayCast2D = $RayCasts/CeilingRay2
@onready var ceiling_ray_3: RayCast2D = $RayCasts/CeilingRay3

@onready var stamina_bar: ProgressBar = $GameUI/MarginContainer/HBoxContainer/VBoxContainer/StaminaBar
@onready var health_bar: ProgressBar = $GameUI/MarginContainer/HBoxContainer/VBoxContainer/HealthBar
@onready var camera_2d: Camera2D = $Camera2D

var air_time: float = 0.0
var effective_air_time: float = 0.0
var is_double_jump_held: bool = false
var is_triple_jump_held: bool = false

var big_jump_charged: bool = false
var big_jump_direction: Vector2 = Vector2.ZERO
var can_big_jump: bool = true

var dash_attack_direction: Vector2 = Vector2.ZERO
var dash_attack_damaged_entities: Array = []

var velocity_before_attack: float = 0.0
var pending_knockback_force: Vector2 = Vector2.ZERO

var big_attack_pending: bool = false
var is_high_big_attack: bool = false

func initialize_character() -> void:
	setup_additional_raycasts()
	init_additional_timers()

func setup_additional_raycasts() -> void:
	if near_ground_ray:
		near_ground_ray.target_position = Vector2(0, character_data.near_ground_ray_length)
		near_ground_ray.enabled = true
	if near_ground_ray_2:
		near_ground_ray_2.target_position = Vector2(0, character_data.near_ground_ray_length)
		near_ground_ray_2.enabled = true
	if near_ground_ray_3:
		near_ground_ray_3.target_position = Vector2(0, character_data.near_ground_ray_length)
		near_ground_ray_3.enabled = true
	
	if ceiling_ray:
		ceiling_ray.target_position = Vector2(0, -character_data.ceiling_ray_length)
		ceiling_ray.enabled = true
	if ceiling_ray_2:
		ceiling_ray_2.target_position = Vector2(0, -character_data.ceiling_ray_length)
		ceiling_ray_2.enabled = true
	if ceiling_ray_3:
		ceiling_ray_3.target_position = Vector2(0, -character_data.ceiling_ray_length)
		ceiling_ray_3.enabled = true

func init_additional_timers() -> void:
	if capabilities.can_big_jump:
		big_jump_timer.wait_time = character_data.big_jump_charge_time
		big_jump_timer.one_shot = true
		big_jump_timer.timeout.connect(_on_big_jump_timer_timeout)
		
		big_jump_cooldown_timer.wait_time = character_data.big_jump_cooldown
		big_jump_cooldown_timer.one_shot = true
		big_jump_cooldown_timer.timeout.connect(_on_big_jump_cooldown_timer_timeout)

func process_character(delta: float) -> void:
	handle_big_jump_stamina(delta)
	handle_dash_attack_stamina(delta)
	update_ui()

func physics_process_character(delta: float) -> void:
	handle_jump_release()
	check_big_attack_landing()
	handle_air_time(delta)
	handle_flipping()

func handle_movement(_delta: float) -> void:
	if current_state == State.STUNNED or current_state == State.ATTACKING or current_state == State.KNOCKBACK or current_state == State.DEATH:
		return
	
	if current_state == State.BIG_JUMPING:
		check_big_jump_collision()
		check_big_jump_input_release()
		return
	
	if current_state == State.DASH_ATTACK:
		check_dash_attack_collision()
		check_dash_attack_input_release()
		return
	
	if dash_timer and not dash_timer.is_stopped():
		change_state(State.DASHING)
		return
	
	check_floor_state()

func handle_actions() -> void:
	if current_state == State.KNOCKBACK or current_state == State.DEATH:
		return
	
	var input_direction = Input.get_axis("A_left", "D_right")
	
	match current_state:
		State.IDLE, State.WALKING:
			handle_ground_movement(input_direction)
			handle_ground_actions()
		State.JUMPING, State.DOUBLE_JUMPING, State.TRIPLE_JUMPING:
			handle_air_movement(input_direction)
			handle_air_actions()
		State.WALL_SLIDING:
			handle_wall_actions()
		State.WALL_JUMPING:
			if wall_jump_control_timer and wall_jump_control_timer.is_stopped():
				can_double_jump = true
				can_triple_jump = true
				handle_air_movement(input_direction)
			handle_air_actions()
		State.DASHING:
			pass
		State.DASH_ATTACK:
			handle_dash_attack_movement()
		State.CHARGING_JUMP:
			handle_charge_jump()
		State.BIG_JUMPING:
			handle_big_jump_movement()
		State.STUNNED:
			pass
		State.BIG_ATTACK:
			handle_air_movement(input_direction)
		State.BIG_ATTACK_LANDING:
			velocity.x = 0
		State.ATTACKING:
			handle_attack_movement()
			if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
				if Input.is_action_just_pressed("L_attack"):
					perform_attack()

func handle_ground_movement(input_direction: float) -> void:
	if input_direction:
		velocity.x = input_direction * character_data.speed
		if current_state == State.CHARGING_JUMP:
			cancel_big_jump_charge()
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed)

func handle_air_movement(input_direction: float) -> void:
	if current_state == State.BIG_ATTACK or current_state == State.BIG_ATTACK_LANDING:
		velocity.x = move_toward(velocity.x, 0, character_data.speed * character_data.big_attack_air_friction)
		return
		
	if input_direction:
		velocity.x = input_direction * character_data.speed
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed * character_data.air_movement_friction)

func handle_ground_actions() -> void:
	if current_state == State.STUNNED:
		return
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			perform_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			perform_directional_big_jump(Vector2(1, 0))
			return
		elif Input.is_action_just_pressed("W_jump"):
			perform_directional_big_jump(Vector2(0, -1))
			return
		elif Input.is_action_just_pressed("L_attack"):
			perform_dash_attack()
			return
	
	if big_jump_charged and Input.is_action_just_released("J_dash"):
		cancel_big_jump_charge()
		big_jump_charged = false
	
	if Input.is_action_just_pressed("W_jump"):
		perform_jump()
	
	if Input.is_action_just_pressed("J_dash") and velocity.x != 0:
		attempt_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		perform_attack()
	
	if Input.is_action_pressed("J_dash") and velocity.x == 0 and can_big_jump and capabilities.can_big_jump:
		start_big_jump_charge()

func handle_air_actions() -> void:
	if Input.is_action_just_pressed("W_jump"):
		if current_state != State.WALL_JUMPING and current_state != State.ATTACKING:
			if can_double_jump and jump_count == 1 and capabilities.can_double_jump:
				perform_double_jump()
			elif can_triple_jump and jump_count == 2 and capabilities.can_triple_jump:
				perform_triple_jump()
		elif current_state == State.WALL_JUMPING:
			if can_double_jump and capabilities.can_double_jump:
				perform_double_jump()
			elif can_triple_jump and capabilities.can_triple_jump:
				perform_triple_jump()
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			perform_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			perform_directional_big_jump(Vector2(1, 0))
			return
		elif Input.is_action_just_pressed("L_attack"):
			perform_dash_attack()
			return
	
	if big_jump_charged and Input.is_action_just_released("J_dash"):
		cancel_big_jump_charge()
		big_jump_charged = false
	
	if Input.is_action_just_pressed("J_dash") and current_state != State.ATTACKING:
		attempt_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		perform_attack()
	
	if Input.is_action_just_pressed("S_charge_jump") and capabilities.can_big_attack:
		if stamina_current >= character_data.big_attack_stamina_cost:
			stamina_current -= character_data.big_attack_stamina_cost
			stamina_regen_timer = character_data.stamina_regen_delay
			var ground = is_on_floor()
			is_high_big_attack = not ground
			change_state(State.BIG_ATTACK)

func handle_wall_actions() -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if Input.is_action_just_pressed("W_jump") and can_wall_jump and capabilities.can_wall_jump:
		perform_wall_jump()
		return
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			perform_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			perform_directional_big_jump(Vector2(1, 0))
			return
		elif Input.is_action_just_pressed("L_attack"):
			perform_dash_attack()
			return
	
	if input_direction != 0 and can_wall_jump and capabilities.can_wall_jump:
		var wall_direction = get_wall_jump_direction()
		if (input_direction > 0 and wall_direction > 0) or (input_direction < 0 and wall_direction < 0):
			perform_wall_jump_away()
	
	if big_jump_charged and Input.is_action_just_released("J_dash"):
		cancel_big_jump_charge()
		big_jump_charged = false
	
	if Input.is_action_pressed("J_dash") and velocity.y < 0 and can_big_jump and capabilities.can_big_jump:
		if Input.is_action_just_pressed("S_charge_jump"):
			cancel_big_jump_charge()
		else:
			start_big_jump_charge()
	else:
		cancel_big_jump_charge()
	
	if Input.is_action_just_pressed("J_dash"):
		attempt_dash()

func handle_attack_movement() -> void:
	if has_nearby_enemy():
		velocity.x = move_toward(velocity.x, 0, character_data.attack_movement_friction * character_data.enemy_nearby_friction_multiplier)
		return
		
	if is_on_floor():
		var attack_force = character_data.attack_movement_force * character_data.ground_attack_force_multiplier
		if count_of_attack == 3:
			attack_force *= character_data.attack_movement_multiplier
		velocity.x = get_attack_direction() * attack_force
	else:
		var air_attack_force = character_data.attack_movement_force * character_data.air_attack_force_multiplier
		velocity.x = get_attack_direction() * air_attack_force
	
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, character_data.attack_movement_friction * character_data.ground_friction_multiplier)
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.attack_movement_friction * character_data.air_friction_multiplier)

func handle_charge_jump() -> void:
	if not Input.is_action_pressed("J_dash"):
		cancel_big_jump_charge()
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			perform_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			perform_directional_big_jump(Vector2(1, 0))
			return
		elif Input.is_action_just_pressed("W_jump"):
			perform_directional_big_jump(Vector2(0, -1))
			return
		elif Input.is_action_just_pressed("L_attack"):
			perform_dash_attack()
			return
	
	if velocity.x != 0 and not big_jump_charged:
		cancel_big_jump_charge()

func handle_big_jump_movement() -> void:
	if big_jump_direction.y < 0:
		velocity.x = 0
		velocity.y = -character_data.big_jump_vertical_speed
	elif big_jump_direction.x != 0:
		velocity.x = big_jump_direction.x * character_data.big_jump_horizontal_speed
		velocity.y = 0

func handle_dash_attack_movement() -> void:
	if dash_attack_direction.x != 0:
		velocity.x = dash_attack_direction.x * character_data.big_jump_horizontal_speed
		velocity.y = 0

func handle_gravity(delta: float) -> void:
	if current_state == State.BIG_JUMPING or current_state == State.KNOCKBACK or current_state == State.DASH_ATTACK:
		return
		
	if not is_on_floor():
		if current_state == State.WALL_SLIDING and (is_wall_hanging_left() or is_wall_hanging_right()):
			return
		elif current_state == State.WALL_SLIDING:
			if Input.is_action_pressed("S_charge_jump"):
				velocity.y += gravity * delta * character_data.wall_slide_gravity_multiplier
			elif Input.is_action_just_released("S_charge_jump"):
				velocity.y = gravity * delta / character_data.wall_slide_initial_velocity_divisor
			else:
				velocity.y = gravity * delta / character_data.wall_slide_initial_velocity_divisor
		elif big_attack_pending and velocity.y > 0:
			velocity.y += gravity * delta * character_data.landing_multiplier
		else:
			velocity.y += gravity * delta

func handle_jump_release() -> void:
	if current_state == State.KNOCKBACK or current_state == State.DEATH:
		return
		
	if Input.is_action_just_released("W_jump") or _is_on_ceiling():
		if is_jump_held and velocity.y < 0:
			velocity.y *= character_data.jump_release_multiplier
			is_jump_held = false
		elif is_double_jump_held and velocity.y < 0:
			velocity.y *= character_data.jump_release_multiplier
			is_double_jump_held = false
		elif is_triple_jump_held and velocity.y < 0:
			velocity.y *= character_data.jump_release_multiplier
			is_triple_jump_held = false

func handle_air_time(delta: float) -> void:
	if not is_on_floor():
		air_time += delta
		if current_state == State.BIG_ATTACK or big_attack_pending:
			effective_air_time += delta * character_data.landing_multiplier
		else:
			effective_air_time += delta
	elif is_on_floor():
		if current_state == State.BIG_ATTACK_LANDING or big_attack_pending:
			check_stun_on_landing()
		reset_air_time()

func handle_big_jump_stamina(delta: float) -> void:
	if current_state == State.BIG_JUMPING:
		stamina_current -= character_data.big_jump_stamina_drain_rate * delta
		if stamina_current <= 0:
			stamina_current = 0
			end_big_jump()

func handle_dash_attack_stamina(delta: float) -> void:
	if current_state == State.DASH_ATTACK:
		stamina_current -= character_data.dash_attack_stamina_drain_rate * delta
		if stamina_current <= 0:
			stamina_current = 0
			end_dash_attack()

func handle_flipping() -> void:
	if current_state == State.DEATH:
		return
		
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if current_state == State.WALL_SLIDING:
		if left_wall_ray.is_colliding():
			body.scale.x = 1
		elif right_wall_ray.is_colliding():
			body.scale.x = -1
	elif input_direction != 0 and current_state != State.DASH_ATTACK:
		body.scale.x = -sign(input_direction)

func perform_wall_jump_away() -> void:
	var wall_direction = get_wall_jump_direction()
	velocity.y = 0
	velocity.x = wall_direction * character_data.wall_jump_force * character_data.wall_jump_away_multiplier
	reset_air_time()
	change_state(State.WALL_JUMPING)
	can_wall_jump = false

func attempt_dash() -> void:
	if not can_dash or not capabilities.can_dash:
		return
	
	if stamina_current < character_data.dash_stamina_cost:
		return
	
	var dash_direction = Input.get_axis("A_left", "D_right")
	if dash_direction == 0:
		return
	
	perform_dash(dash_direction)
	
	if big_jump_charged:
		dash_timer.wait_time = character_data.dash_duration * character_data.big_jump_dash_multiplier
		big_jump_charged = false

func perform_dash_attack() -> void:
	if not capabilities.can_dash_attack:
		return
		
	var attack_dir = get_attack_direction()
	dash_attack_direction = Vector2(attack_dir, 0)
	change_state(State.DASH_ATTACK)

func start_big_jump_charge() -> void:
	if big_jump_charged or big_jump_timer.time_left > 0 or not can_big_jump:
		return
	can_big_jump = false
	big_jump_cooldown_timer.start()
	big_jump_timer.start()

func cancel_big_jump_charge() -> void:
	if big_jump_timer.time_left > 0:
		big_jump_timer.stop()
		big_jump_charged = false

func perform_directional_big_jump(direction: Vector2) -> void:
	big_jump_charged = false
	big_jump_direction = direction
	change_state(State.BIG_JUMPING)

func check_big_jump_collision() -> void:
	var _ceil = ceiling_ray and (ceiling_ray.is_colliding() or ceiling_ray_2.is_colliding() or ceiling_ray_3.is_colliding())
	var left = left_wall_ray.is_colliding()
	var right = right_wall_ray.is_colliding()
	if big_jump_direction.y < 0 and _ceil:
		end_big_jump()
	elif big_jump_direction.x < 0 and left:
		end_big_jump()
	elif big_jump_direction.x > 0 and right:
		end_big_jump()

func check_big_jump_input_release() -> void:
	if big_jump_direction.x < 0 and not Input.is_action_pressed("A_left"):
		end_big_jump()
	elif big_jump_direction.x > 0 and not Input.is_action_pressed("D_right"):
		end_big_jump()
	elif big_jump_direction.y < 0 and not Input.is_action_pressed("W_jump"):
		end_big_jump()

func end_big_jump() -> void:
	big_jump_direction = Vector2.ZERO
	change_state(State.JUMPING)

func check_dash_attack_collision() -> void:
	var left = left_wall_ray.is_colliding()
	var right = right_wall_ray.is_colliding()
	if dash_attack_direction.x < 0 and left:
		end_dash_attack()
	elif dash_attack_direction.x > 0 and right:
		end_dash_attack()

func check_dash_attack_input_release() -> void:
	if not Input.is_action_pressed("L_attack"):
		end_dash_attack()

func end_dash_attack() -> void:
	dash_attack_direction = Vector2.ZERO
	dash_attack_damaged_entities.clear()
	stamina_regen_timer = character_data.stamina_regen_delay
	change_state(State.JUMPING)

func check_big_attack_landing() -> void:
	var near = near_ground_ray and (near_ground_ray.is_colliding() or near_ground_ray_2.is_colliding() or near_ground_ray_3.is_colliding())
	if current_state == State.BIG_ATTACK and big_attack_pending and near:
		change_state(State.BIG_ATTACK_LANDING)

func reset_air_time() -> void:
	air_time = 0
	effective_air_time = 0

func check_stun_on_landing() -> void:
	hide_weapon_timer.stop()
	hide_weapon_timer.start()
	big_attack_pending = false

func get_attack_direction() -> float:
	return -body.scale.x

func is_wall_hanging_left() -> bool:
	var colliding = left_wall_ray.is_colliding()
	var input_direction = Input.get_axis("A_left", "D_right")
	return colliding and input_direction < 0

func is_wall_hanging_right() -> bool:
	var colliding = right_wall_ray.is_colliding()
	var input_direction = Input.get_axis("A_left", "D_right")
	return colliding and input_direction > 0

func has_nearby_enemy() -> bool:
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	
	for entity in overlapping_bodies:
		if entity == self:
			continue
		return true
	return false

func _is_on_ceiling() -> bool:
	if not ceiling_ray:
		return false
	return ceiling_ray.is_colliding() or ceiling_ray_2.is_colliding() or ceiling_ray_3.is_colliding()

func update_ui() -> void:
	if stamina_bar:
		stamina_bar.value = stamina_current
		stamina_bar.max_value = character_data.stamina_max
	if health_bar:
		health_bar.value = health_current
		health_bar.max_value = character_data.health_max

func enter_state(state: State) -> void:
	super.enter_state(state)
	
	match state:
		State.DOUBLE_JUMPING:
			is_double_jump_held = true
		State.TRIPLE_JUMPING:
			is_triple_jump_held = true
		State.DASH_ATTACK:
			invulnerability = true
			dash_attack_damaged_entities.clear()
			big_jump_charged = false
		State.BIG_ATTACK:
			invulnerability = true
			big_attack_pending = true
			hide_weapon_timer.stop()
			if air_time == 0:
				air_time = character_data.air_time_initial
				effective_air_time = character_data.air_time_initial
		State.BIG_ATTACK_LANDING:
			apply_damage_to_entities_big_attack()
		State.BIG_JUMPING:
			big_jump_charged = false
		State.ATTACKING:
			velocity_before_attack = velocity.x

func exit_state(state: State) -> void:
	super.exit_state(state)
	
	if state == State.ATTACKING and current_state != State.KNOCKBACK and current_state != State.DASH_ATTACK:
		pending_knockback_force = Vector2.ZERO

func handle_animations() -> void:
	if not animation_player:
		return
		
	match current_state:
		State.IDLE:
			if big_jump_charged and Input.is_action_pressed("J_dash"):
				animation_player.play("Big_jump_charge")
			else:
				animation_player.play("Idle")
		State.BIG_JUMPING:
			animation_player.play("Dash")
		State.BIG_ATTACK:
			if is_high_big_attack and animation_player.current_animation != "Big_attack":
				animation_player.play("Big_attack_prepare")
				update_weapon_visibility("both")
		State.BIG_ATTACK_LANDING:
			if animation_player.current_animation != "Big_attack_landing":
				animation_player.play("Big_attack_landing")
		State.WALL_SLIDING:
			if (big_jump_timer.time_left > 0) or (big_jump_charged and Input.is_action_pressed("J_dash")):
				animation_player.play("Big_jump_wall_charge")
			else:
				animation_player.play("Sliding_wall")
		State.DASH_ATTACK:
			animation_player.play("Dash_attack")
			update_weapon_visibility("both")
		State.CHARGING_JUMP:
			animation_player.play("Big_jump_charge")
		_:
			super.handle_animations()

func apply_damage_to_entities_big_attack() -> void:
	var front_bodies = big_attack_area.get_overlapping_bodies()
	var back_bodies = big_attack_area_2.get_overlapping_bodies()
	
	var damage = character_data.big_attack_dmg
	var base_knockback_force = character_data.knockback_force * character_data.knockback_force_multiplier
	var attack_dir = get_attack_direction()
	var hit_count = 0

	for entity in front_bodies:
		if entity == self:
			continue
		hit_count += 1
		
		var knockback_force = Vector2(
			1 * base_knockback_force * 2.0,
			character_data.jump_velocity * character_data.knockback_vertical_multiplier
		)
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		if entity.has_method("apply_knockback"):
			entity.apply_knockback(knockback_force)
	
	for entity in back_bodies:
		if entity == self or entity in front_bodies:
			continue
		hit_count += 1
		
		var knockback_force = Vector2(
			-1 * base_knockback_force * 2.0,
			character_data.jump_velocity * character_data.knockback_vertical_multiplier
		)
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		if entity.has_method("apply_knockback"):
			entity.apply_knockback(knockback_force)
	
	if hit_count > 0:
		var reaction_force = Vector2(
			-attack_dir * base_knockback_force * character_data.knockback_reaction_multiplier * character_data.knockback_reaction_force_multiplier,
			character_data.jump_velocity * character_data.knockback_reaction_jump_multiplier
		)
		apply_knockback(reaction_force)

func apply_damage_to_entities() -> void:
	if current_state == State.BIG_ATTACK_LANDING:
		apply_damage_to_entities_big_attack()
		return
		
	super.apply_damage_to_entities()
	
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	if not overlapping_bodies.is_empty():
		var hit_count = 0
		for entity in overlapping_bodies:
			if entity != self:
				hit_count += 1
		
		if hit_count > 0:
			var base_knockback_force = character_data.knockback_force
			if count_of_attack == 3:
				base_knockback_force *= character_data.knockback_force_multiplier
			var attack_dir = get_attack_direction()
			var reaction_force = Vector2(
				-attack_dir * base_knockback_force * character_data.knockback_reaction_multiplier * character_data.knockback_reaction_force_multiplier,
				character_data.jump_velocity * character_data.knockback_reaction_jump_multiplier
			)
			
			if current_state == State.ATTACKING:
				pending_knockback_force = reaction_force
			else:
				apply_knockback(reaction_force)

func _on_attack_area_body_entered(_body: Node2D) -> void:
	if current_state != State.DASH_ATTACK or _body == self:
		return
		
	if _body in dash_attack_damaged_entities:
		return
	
	dash_attack_damaged_entities.append(_body)
	
	var damage = character_data.dash_attack_dmg
	var base_knockback_force = character_data.knockback_force * character_data.knockback_force_multiplier
	var attack_dir = get_attack_direction()
	
	var knockback_force = Vector2(
		attack_dir * base_knockback_force * 1.5,
		character_data.jump_velocity * character_data.knockback_vertical_multiplier
	)
	
	if _body.has_method("take_damage"):
		_body.take_damage(damage)
	if _body.has_method("apply_knockback"):
		_body.apply_knockback(knockback_force)
	
	var reaction_force = Vector2(
		-attack_dir * base_knockback_force * character_data.knockback_reaction_multiplier,
		0
	)
	pending_knockback_force = reaction_force

func _on_animation_finished(anim_name: String) -> void:
	if current_state == State.ATTACKING:
		if anim_name.begins_with("Attack_ground"):
			if pending_knockback_force.length() > 0:
				apply_knockback(pending_knockback_force)
				pending_knockback_force = Vector2.ZERO
			else:
				velocity.x = velocity_before_attack
				change_state(State.IDLE)
		elif anim_name.begins_with("Attack_air"):
			if pending_knockback_force.length() > 0:
				apply_knockback(pending_knockback_force)
				pending_knockback_force = Vector2.ZERO
			else:
				change_state(State.JUMPING)
	elif current_state == State.DASH_ATTACK and anim_name == "Dash_attack":
		end_dash_attack()
	elif current_state == State.BIG_ATTACK and anim_name == "Big_attack_prepare":
		animation_player.play("Big_attack")
	elif anim_name == "Big_attack" and (current_state == State.BIG_ATTACK_LANDING or is_on_floor()):
		if not animation_player.is_playing() or animation_player.current_animation != "Big_attack_landing":
			animation_player.play("Big_attack_landing")
	elif anim_name == "Big_attack_landing":
		if effective_air_time > character_data.stun_after_land_treshold:
			change_state(State.STUNNED)
			stun_timer.start()
		else:
			change_state(State.IDLE)
	elif anim_name == "Death":
		death_animation_played = true

func _on_big_jump_timer_timeout() -> void:
	big_jump_charged = true

func _on_big_jump_cooldown_timer_timeout() -> void:
	can_big_jump = true
