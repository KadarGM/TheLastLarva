extends State
class_name WallSlidingState

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func enter() -> void:
	character.can_wall_jump = true
	character.jump_count = 0
	character.has_double_jump = true
	character.has_triple_jump = false

func physics_process(delta: float) -> void:
	if character.is_on_floor():
		state_machine.transition_to("IdleState")
		return
	
	var left = character.ray_casts_handler.left_wall_ray.is_colliding()
	var right = character.ray_casts_handler.right_wall_ray.is_colliding()
	
	if not left and not right:
		state_machine.transition_to("JumpingState")
		return
	
	apply_wall_slide_gravity(delta)
	process_input()

func apply_wall_slide_gravity(delta: float) -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	var wall_direction = get_wall_direction()
	
	if wall_direction != 0 and input_direction != 0:
		if sign(input_direction) == -sign(wall_direction):
			character.velocity.y = 0
			return
	
	if Input.is_action_pressed("S_charge_jump"):
		character.velocity.y += gravity * delta * character.character_data.wall_slide_gravity_multiplier
		character.velocity.y = min(character.velocity.y, 300)
	else:
		character.velocity.y = 0

func process_input() -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if character.big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("W_jump"):
			character.execute_big_jump(Vector2(0, -1))
			var big_jump_state = state_machine.states.get("BigJumpingState")
			if big_jump_state:
				big_jump_state.set_direction(Vector2(0, -1))
			state_machine.transition_to("BigJumpingState")
			return
		elif Input.is_action_just_pressed("A_left"):
			character.execute_big_jump(Vector2(-1, 0))
			var big_jump_state = state_machine.states.get("BigJumpingState")
			if big_jump_state:
				big_jump_state.set_direction(Vector2(-1, 0))
			state_machine.transition_to("BigJumpingState")
			return
		elif Input.is_action_just_pressed("D_right"):
			character.execute_big_jump(Vector2(1, 0))
			var big_jump_state = state_machine.states.get("BigJumpingState")
			if big_jump_state:
				big_jump_state.set_direction(Vector2(1, 0))
			state_machine.transition_to("BigJumpingState")
			return
	
	if Input.is_action_just_pressed("W_jump") and character.can_wall_jump:
		execute_wall_jump()
		return
	
	if input_direction != 0 and character.can_wall_jump:
		var wall_direction = get_wall_direction()
		if sign(input_direction) == sign(wall_direction):
			execute_wall_jump_away()
			return
	
	if Input.is_action_pressed("J_dash") and character.can_big_jump:
		character.start_big_jump_charge()
	elif Input.is_action_just_released("J_dash"):
		character.cancel_big_jump_charge()
	
	if Input.is_action_just_pressed("L_attack"):
		if character.character_data.can_air_attack:
			character.perform_air_attack()

func execute_wall_jump() -> void:
	var wall_direction = get_wall_direction()
	character.velocity.y = character.character_data.jump_velocity * 0.7
	character.velocity.x = wall_direction * character.character_data.wall_jump_force
	
	character.reset_air_time()
	character.jump_count = 1
	character.has_double_jump = true
	character.has_triple_jump = false
	character.can_wall_jump = false
	
	state_machine.transition_to("WallJumpingState")

func execute_wall_jump_away() -> void:
	var wall_direction = get_wall_direction()
	character.velocity.y = character.character_data.jump_velocity * 0.2
	character.velocity.x = wall_direction * character.character_data.wall_jump_force * (1.0 + character.character_data.wall_jump_away_multiplier) * 0.8
	
	character.reset_air_time()
	character.jump_count = 1
	character.has_double_jump = true
	character.has_triple_jump = false
	character.can_wall_jump = false
	
	state_machine.transition_to("WallJumpingState")

func get_wall_direction() -> float:
	if character.ray_casts_handler.left_wall_ray.is_colliding():
		return 1.0
	elif character.ray_casts_handler.right_wall_ray.is_colliding():
		return -1.0
	return 0.0

func handle_animation() -> void:
	if Input.is_action_pressed("J_dash") and character.timers_handler.big_jump_timer.time_left > 0:
		character.play_animation("Big_jump_wall_charge")
	elif character.big_jump_charged and Input.is_action_pressed("J_dash"):
		character.play_animation("Big_jump_wall_charge")
	else:
		character.play_animation("Sliding_wall")
