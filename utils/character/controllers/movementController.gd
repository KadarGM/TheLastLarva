extends Control
class_name MovementController

@export var owner_body: CharacterManager
@export var state_machine: CallableStateMachine
@export var character_data: CharacterData
@export var body_node: BodyNode
@export var animation_player: AnimationPlayer
@export var ray_casts_handler: RayCastsHandler
@export var timers_handler: TimersHandler
@export var jump_controller: JumpController
@export var combat_controller: CombatController
@export var stats_controller: StatsController
@export var big_jump_controller: BigJumpController

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var dash_attack_direction: Vector2 = Vector2.ZERO
var can_dash: bool = true

var can_wall_jump: bool = true
var has_wall_jumped: bool = false
var was_on_wall: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

var air_time: float = 0.0
var effective_air_time: float = 0.0
var big_attack_pending: bool = false
var is_high_big_attack: bool = false

func setup(body: CharacterManager, sm: CallableStateMachine, data: CharacterData, bn: BodyNode, anim: AnimationPlayer, rch: RayCastsHandler, th: TimersHandler, jc: JumpController, cc: CombatController):
	owner_body = body
	state_machine = sm
	character_data = data
	body_node = bn
	animation_player = anim
	ray_casts_handler = rch
	timers_handler = th
	jump_controller = jc
	combat_controller = cc
	
	if owner_body.stats_controller:
		stats_controller = owner_body.stats_controller
	if owner_body.big_jump_controller:
		big_jump_controller = owner_body.big_jump_controller

func process_physics(delta: float) -> void:
	if owner_body.current_state == state_machine.State.KNOCKBACK:
		process_knockback(delta)
		return
	
	if owner_body.current_state == state_machine.State.DEATH:
		apply_gravity(delta)
		return
	
	apply_gravity(delta)
	process_jump_release()
	check_big_attack_landing()
	update_air_time(delta)

func process_state_movement(delta: float, input_direction: float) -> void:
	match owner_body.current_state:
		state_machine.State.IDLE, state_machine.State.WALKING:
			process_ground_movement(input_direction)
		state_machine.State.JUMPING, state_machine.State.DOUBLE_JUMPING, state_machine.State.TRIPLE_JUMPING:
			process_air_movement(input_direction)
		state_machine.State.WALL_SLIDING:
			process_wall_slide(delta)
		state_machine.State.WALL_JUMPING:
			if timers_handler.wall_jump_control_timer.is_stopped():
				process_air_movement(input_direction)
		state_machine.State.DASH_ATTACK:
			process_dash_attack_movement()
		state_machine.State.CHARGING_JUMP:
			process_charge_jump()
		state_machine.State.BIG_JUMPING:
			if big_jump_controller:
				big_jump_controller.process_big_jump_movement()
		state_machine.State.BIG_ATTACK:
			process_air_movement(input_direction)
		state_machine.State.BIG_ATTACK_LANDING:
			owner_body.velocity.x = 0
		state_machine.State.ATTACKING:
			combat_controller.process_attack_movement()

func process_ground_movement(input_direction: float) -> void:
	if not character_data.can_walk:
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_ability_blocked("Walk", "Disabled in character data")
		return
	if input_direction:
		owner_body.velocity.x = input_direction * character_data.speed
		if owner_body.current_state == state_machine.State.CHARGING_JUMP:
			if big_jump_controller:
				big_jump_controller.cancel_charge()
	else:
		owner_body.velocity.x = move_toward(owner_body.velocity.x, 0, character_data.speed)

func process_air_movement(input_direction: float) -> void:
	if not character_data.can_walk:
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_ability_blocked("Air Walk", "Disabled in character data")
		return
	if owner_body.current_state == state_machine.State.BIG_ATTACK or owner_body.current_state == state_machine.State.BIG_ATTACK_LANDING:
		owner_body.velocity.x = move_toward(owner_body.velocity.x, 0, character_data.speed * character_data.big_attack_air_friction)
		return
		
	if input_direction:
		owner_body.velocity.x = input_direction * character_data.speed
	else:
		owner_body.velocity.x = move_toward(owner_body.velocity.x, 0, character_data.speed * character_data.air_movement_friction)

func process_wall_slide(_delta) -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	var big_jump_executed = false
	if big_jump_controller:
		big_jump_executed = big_jump_controller.process_big_jump_input()

	if Input.is_action_just_pressed("W_jump") and can_wall_jump and not big_jump_executed:
		if character_data.can_wall_jump:
			execute_wall_jump()
			return
	elif input_direction != 0 and can_wall_jump and not big_jump_executed:
		var wall_direction = get_wall_jump_direction()
		if (input_direction > 0 and wall_direction > 0) or (input_direction < 0 and wall_direction < 0):
			execute_wall_jump_away()
			return
	
	if big_jump_controller:
		big_jump_controller.perform_wall_charge_attempt()
	
	if Input.is_action_just_pressed("J_dash"):
		if character_data.can_dash:
			perform_dash()

func process_charge_jump() -> void:
	if not Input.is_action_pressed("J_dash"):
		if big_jump_controller:
			big_jump_controller.cancel_charge()
	
	if big_jump_controller:
		big_jump_controller.process_big_jump_input()
	
	if owner_body.velocity.x != 0 and big_jump_controller and not big_jump_controller.is_charged():
		big_jump_controller.cancel_charge()

func process_dash_attack_movement() -> void:
	if dash_attack_direction.x != 0:
		owner_body.velocity.x = dash_attack_direction.x * character_data.big_jump_horizontal_speed
		owner_body.velocity.y = 0

func process_knockback(delta: float) -> void:
	if owner_body.current_state == state_machine.State.KNOCKBACK:
		if knockback_timer > 0:
			knockback_timer -= delta
			owner_body.velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, character_data.knockback_friction * delta)
			
			if knockback_timer <= 0 or knockback_velocity.length() < 10:
				knockback_velocity = Vector2.ZERO
				state_machine.transition_to(state_machine.State.IDLE)
		else:
			state_machine.transition_to(state_machine.State.IDLE)

func apply_gravity(delta: float) -> void:
	if owner_body.current_state == state_machine.State.BIG_JUMPING or owner_body.current_state == state_machine.State.KNOCKBACK or owner_body.current_state == state_machine.State.DASH_ATTACK:
		return
		
	if not owner_body.is_on_floor():
		if owner_body.current_state == state_machine.State.WALL_SLIDING and (is_wall_hanging_left() or is_wall_hanging_right()):
			return
		elif owner_body.current_state == state_machine.State.WALL_SLIDING:
			if Input.is_action_pressed("S_charge_jump"):
				if character_data.can_wall_slide:
					owner_body.velocity.y += gravity * delta * character_data.wall_slide_gravity_multiplier
			elif Input.is_action_just_released("S_charge_jump"):
				owner_body.velocity.y = gravity * delta / character_data.wall_slide_initial_velocity_divisor
			else:
				owner_body.velocity.y = gravity * delta / character_data.wall_slide_initial_velocity_divisor
		elif big_attack_pending and owner_body.velocity.y > 0:
			owner_body.velocity.y += gravity * delta * character_data.landing_multiplier
		else:
			owner_body.velocity.y += gravity * delta

func process_jump_release() -> void:
	if state_machine.current_state == state_machine.State.KNOCKBACK or state_machine.current_state == state_machine.State.DEATH:
		return
	
	if Input.is_action_just_released("W_jump") or owner_body.is_on_ceiling():
		jump_controller.handle_jump_release()

func execute_jump() -> void:
	if jump_controller.handle_ground_jump():
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_jump("Jump")
		state_machine.transition_to(state_machine.State.JUMPING)

func execute_double_jump() -> void:
	if not stats_controller:
		return
	var result = jump_controller.handle_air_jump(stats_controller.get_stamina())
	if result.success and result.type == "double":
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_jump("Double Jump")
		reset_air_time()
		state_machine.transition_to(state_machine.State.DOUBLE_JUMPING)

func execute_triple_jump() -> void:
	if not stats_controller:
		return
	var result = jump_controller.handle_air_jump(stats_controller.get_stamina())
	if result.success and result.type == "triple":
		stats_controller.consume_stamina(result.stamina_cost)
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_jump("Triple Jump")
		reset_air_time()
		state_machine.transition_to(state_machine.State.TRIPLE_JUMPING)

func execute_wall_jump() -> void:
	var wall_direction = get_wall_jump_direction()
	owner_body.velocity.y = character_data.jump_velocity * 1.5
	owner_body.velocity.x = wall_direction * character_data.wall_jump_force * 2
	reset_air_time()
	jump_controller.jump_count = 1
	jump_controller.has_double_jump = true
	jump_controller.has_triple_jump = false
	if owner_body.debug_helper.console_debug:
		owner_body.debug_helper.log_wall_interaction("Wall Jump")
	state_machine.transition_to(state_machine.State.WALL_JUMPING)
	can_wall_jump = false

func execute_wall_jump_away() -> void:
	var wall_direction = get_wall_jump_direction()
	owner_body.velocity.y = character_data.jump_velocity * 0.2
	owner_body.velocity.x = wall_direction * character_data.wall_jump_force * (1.0 + character_data.wall_jump_away_multiplier)
	reset_air_time()
	jump_controller.jump_count = 1
	jump_controller.has_double_jump = true
	jump_controller.has_triple_jump = false
	if owner_body.debug_helper.console_debug:
		owner_body.debug_helper.log_wall_interaction("Wall Jump Away")
	state_machine.transition_to(state_machine.State.WALL_JUMPING)
	can_wall_jump = false

func execute_dash_attack() -> void:
	if not character_data.can_dash_attack or not character_data.can_attack:
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_ability_blocked("Dash Attack", "Not available")
		return
	var attack_dir = combat_controller.get_attack_direction()
	dash_attack_direction = Vector2(attack_dir, 0)
	
	if owner_body.debug_helper.console_debug:
		owner_body.debug_helper.log_attack("Dash Attack")
	
	state_machine.transition_to(state_machine.State.DASH_ATTACK)

func perform_dash() -> void:
	if not character_data.can_dash or not can_dash:
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_ability_blocked("Dash", "On cooldown or disabled")
		return
	
	if not stats_controller or not stats_controller.is_stamina_available(character_data.dash_stamina_cost):
		return
	
	var dash_direction = Input.get_axis("A_left", "D_right")
	if dash_direction == 0:
		return
	
	owner_body.velocity.x = dash_direction * character_data.dash_speed
	owner_body.velocity.y = 0
	can_dash = false
	stats_controller.consume_stamina(character_data.dash_stamina_cost)
	
	if big_jump_controller and big_jump_controller.is_charged():
		timers_handler.dash_timer.wait_time = character_data.dash_duration * character_data.big_jump_dash_multiplier
		big_jump_controller.cancel_charge()
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_dash("charged")
	else:
		timers_handler.dash_timer.wait_time = character_data.dash_duration
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_dash("normal")
	
	timers_handler.dash_timer.start()
	timers_handler.dash_cooldown_timer.start()
	state_machine.transition_to(state_machine.State.DASHING)

func perform_air_jump() -> void:
	if state_machine.current_state != state_machine.State.ATTACKING:
		if jump_controller.has_double_jump and jump_controller.jump_count == 1:
			execute_double_jump()
		elif jump_controller.has_triple_jump and jump_controller.jump_count == 2:
			execute_triple_jump()

func perform_big_attack() -> void:
	if not character_data.can_big_attack:
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_ability_blocked("Big Attack", "Not available")
		return
	var ground = ray_casts_handler.ground_check_ray.is_colliding() or ray_casts_handler.ground_check_ray_2.is_colliding() or ray_casts_handler.ground_check_ray_3.is_colliding()
	if stats_controller and stats_controller.is_stamina_available(character_data.big_attack_stamina_cost):
		stats_controller.consume_stamina(character_data.big_attack_stamina_cost)
		is_high_big_attack = not ground
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_attack("Big Attack")
		state_machine.transition_to(state_machine.State.BIG_ATTACK)

func check_dash_attack_collision() -> void:
	var left = ray_casts_handler.left_wall_ray.is_colliding()
	var right = ray_casts_handler.right_wall_ray.is_colliding()
	if dash_attack_direction.x < 0 and left:
		end_dash_attack()
	elif dash_attack_direction.x > 0 and right:
		end_dash_attack()

func check_dash_attack_input_release() -> void:
	if not Input.is_action_pressed("L_attack"):
		end_dash_attack()

func end_dash_attack() -> void:
	dash_attack_direction = Vector2.ZERO
	combat_controller.dash_attack_damaged_entities.clear()
	if stats_controller:
		stats_controller.stamina_regen_timer = character_data.stamina_regen_delay
	state_machine.transition_to(state_machine.State.JUMPING)
	timers_handler.hide_weapon_timer.stop()
	timers_handler.hide_weapon_timer.start()

func check_big_attack_landing() -> void:
	var near = ray_casts_handler.near_ground_ray.is_colliding() or ray_casts_handler.near_ground_ray_2.is_colliding() or ray_casts_handler.near_ground_ray_3.is_colliding()
	if owner_body.current_state == state_machine.State.BIG_ATTACK and big_attack_pending and near:
		state_machine.transition_to(state_machine.State.BIG_ATTACK_LANDING)

func check_stun_on_landing() -> void:
	timers_handler.hide_weapon_timer.stop()
	timers_handler.hide_weapon_timer.start()
	big_attack_pending = false

func update_air_time(delta: float) -> void:
	if not owner_body.is_on_floor() and owner_body.current_state != state_machine.State.WALL_SLIDING:
		air_time += delta
		if owner_body.current_state == state_machine.State.BIG_ATTACK or big_attack_pending:
			effective_air_time += delta * character_data.landing_multiplier
		else:
			effective_air_time += delta
	elif owner_body.is_on_floor():
		if owner_body.current_state == state_machine.State.BIG_ATTACK_LANDING or big_attack_pending:
			check_stun_on_landing()
		reset_air_time()
	elif owner_body.current_state == state_machine.State.WALL_SLIDING:
		pass

func update_dash_attack_stamina(delta: float) -> void:
	if owner_body.current_state == state_machine.State.DASH_ATTACK:
		if stats_controller:
			stats_controller.drain_stamina(character_data.dash_attack_stamina_drain_rate, delta)
			if stats_controller.get_stamina() <= 0:
				end_dash_attack()

func reset_air_time() -> void:
	air_time = 0
	effective_air_time = 0

func get_wall_jump_direction() -> float:
	if ray_casts_handler.left_wall_ray.is_colliding():
		return 1.0
	elif ray_casts_handler.right_wall_ray.is_colliding():
		return -1.0
	return 0.0

func is_wall_hanging_left() -> bool:
	var colliding = ray_casts_handler.left_wall_ray.is_colliding()
	var input_direction = Input.get_axis("A_left", "D_right")
	return colliding and input_direction < 0

func is_wall_hanging_right() -> bool:
	var colliding = ray_casts_handler.right_wall_ray.is_colliding()
	var input_direction = Input.get_axis("A_left", "D_right")
	return colliding and input_direction > 0

func apply_knockback(force: Vector2) -> void:
	if not character_data.can_get_knockback:
		if owner_body.debug_helper.console_debug:
			owner_body.debug_helper.log_ability_blocked("Knockback", "Immune to knockback")
		return
		
	if owner_body.current_state == state_machine.State.BIG_ATTACK or owner_body.current_state == state_machine.State.BIG_ATTACK_LANDING or owner_body.current_state == state_machine.State.BIG_JUMPING or owner_body.current_state == state_machine.State.KNOCKBACK or owner_body.current_state == state_machine.State.DEATH or owner_body.current_state == state_machine.State.DASH_ATTACK:
		return
	
	knockback_velocity = Vector2(force.x * character_data.knockback_force_horizontal_multiplier, force.y)
	knockback_timer = character_data.knockback_duration
	
	if owner_body.debug_helper.console_debug:
		owner_body.debug_helper.log_knockback(force)
	
	state_machine.transition_to(state_machine.State.KNOCKBACK)

func on_state_enter(new_state) -> void:
	match new_state:
		state_machine.State.WALL_JUMPING:
			timers_handler.wall_jump_control_timer.start()
			has_wall_jumped = true
		state_machine.State.WALL_SLIDING:
			jump_controller.on_wall_jump()
			can_wall_jump = true
		state_machine.State.DASH_ATTACK:
			combat_controller.dash_attack_damaged_entities.clear()
		state_machine.State.BIG_ATTACK:
			if not character_data.can_big_attack:
				return
			big_attack_pending = true
			timers_handler.hide_weapon_timer.stop()
			if air_time == 0:
				air_time = character_data.air_time_initial
				effective_air_time = character_data.air_time_initial
		state_machine.State.BIG_ATTACK_LANDING:
			combat_controller.execute_damage_to_entities()
	
	if big_jump_controller:
		big_jump_controller.on_state_enter(new_state)

func on_state_exit(old_state) -> void:
	if big_jump_controller:
		big_jump_controller.on_state_exit(old_state)

func update_state_transitions() -> void:
	if owner_body.current_state == state_machine.State.STUNNED or owner_body.current_state == state_machine.State.ATTACKING or owner_body.current_state == state_machine.State.KNOCKBACK or owner_body.current_state == state_machine.State.DEATH:
		return
	
	if owner_body.current_state == state_machine.State.BIG_JUMPING:
		if big_jump_controller:
			big_jump_controller.check_big_jump_collision()
			big_jump_controller.check_big_jump_input_release()
		return
	
	if owner_body.current_state == state_machine.State.DASH_ATTACK:
		check_dash_attack_collision()
		check_dash_attack_input_release()
		return
	
	if owner_body.current_state == state_machine.State.DASHING:
		if timers_handler.dash_timer.is_stopped():
			state_machine.transition_to(state_machine.State.IDLE)
		return
	
	if owner_body.is_on_floor():
		process_ground_state_transition()
	else:
		process_air_state_transition()

func process_ground_state_transition() -> void:
	has_wall_jumped = false
	can_wall_jump = true
	was_on_wall = false
	
	if owner_body.current_state == state_machine.State.BIG_ATTACK_LANDING:
		return
	
	if abs(owner_body.velocity.x) > 10:
		state_machine.transition_to(state_machine.State.WALKING)
	elif timers_handler.big_jump_timer.time_left > 0:
		state_machine.transition_to(state_machine.State.CHARGING_JUMP)
	else:
		state_machine.transition_to(state_machine.State.IDLE)

func process_air_state_transition() -> void:
	var left = ray_casts_handler.left_wall_ray.is_colliding()
	var right = ray_casts_handler.right_wall_ray.is_colliding()
	var can_wall_slide = false
	var is_touching_wall = left or right
	
	if is_touching_wall:
		if not was_on_wall:
			can_wall_jump = true
			was_on_wall = true
	else:
		was_on_wall = false

	if is_touching_wall and owner_body.velocity.y > 0:
		if owner_body.current_state == state_machine.State.BIG_ATTACK or owner_body.current_state == state_machine.State.BIG_ATTACK_LANDING:
			can_wall_slide = false
		else:
			can_wall_slide = true
	
	if can_wall_slide:
		state_machine.transition_to(state_machine.State.WALL_SLIDING)
		
	elif owner_body.current_state != state_machine.State.WALL_JUMPING and owner_body.current_state != state_machine.State.BIG_ATTACK and owner_body.current_state != state_machine.State.BIG_ATTACK_LANDING:
		if owner_body.current_state != state_machine.State.DOUBLE_JUMPING and owner_body.current_state != state_machine.State.JUMPING and owner_body.current_state != state_machine.State.TRIPLE_JUMPING:
			state_machine.transition_to(state_machine.State.JUMPING)

func on_dash_cooldown_timer_timeout() -> void:
	can_dash = true
