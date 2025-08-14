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
	
	var left = false
	var right = false
	
	if character.ray_casts_handler:
		left = character.ray_casts_handler.left_wall_ray.is_colliding()
		right = character.ray_casts_handler.right_wall_ray.is_colliding()
	
	if not left and not right:
		state_machine.transition_to("JumpingState")
		return
	
	apply_wall_slide_gravity(delta)
	process_input()

func apply_wall_slide_gravity(delta: float) -> void:
	var input = character.get_controller_input()
	var input_direction = input.move_direction.x
	var wall_direction = get_wall_direction()
	
	if wall_direction != 0 and input_direction != 0:
		if sign(input_direction) == -sign(wall_direction):
			character.velocity.y = 0
			return
	
	if input.charge_jump:
		character.velocity.y += gravity * delta * character.character_data.wall_slide_gravity_multiplier
		character.velocity.y = min(character.velocity.y, 300)
	else:
		character.velocity.y = 0

func process_input() -> void:
	var input = character.get_controller_input()
	var input_direction = input.move_direction.x
	
	if character.big_jump_charged and input.dash:
		if input.jump_pressed:
			character.execute_big_jump(Vector2(0, -1))
			var big_jump_state = state_machine.states.get("BigJumpingState")
			if big_jump_state:
				big_jump_state.set_direction(Vector2(0, -1))
			state_machine.transition_to("BigJumpingState")
			return
		elif input_direction < 0 and input.move_direction.x < -0.5:
			character.execute_big_jump(Vector2(-1, 0))
			var big_jump_state = state_machine.states.get("BigJumpingState")
			if big_jump_state:
				big_jump_state.set_direction(Vector2(-1, 0))
			state_machine.transition_to("BigJumpingState")
			return
		elif input_direction > 0 and input.move_direction.x > 0.5:
			character.execute_big_jump(Vector2(1, 0))
			var big_jump_state = state_machine.states.get("BigJumpingState")
			if big_jump_state:
				big_jump_state.set_direction(Vector2(1, 0))
			state_machine.transition_to("BigJumpingState")
			return
	
	if input.jump_pressed and character.can_wall_jump:
		execute_wall_jump()
		return
	
	if input_direction != 0 and character.can_wall_jump:
		var wall_direction = get_wall_direction()
		if sign(input_direction) == sign(wall_direction):
			execute_wall_jump_away()
			return
	
	if input.dash and character.can_big_jump and character.timers_handler.big_jump_cooldown_timer.is_stopped():
		character.start_big_jump_charge()
	elif not input.dash:
		character.cancel_big_jump_charge()

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
	if character.ray_casts_handler:
		if character.ray_casts_handler.left_wall_ray.is_colliding():
			return 1.0
		elif character.ray_casts_handler.right_wall_ray.is_colliding():
			return -1.0
	return 0.0

func handle_animation() -> void:
	var input = character.get_controller_input()
	if input.dash and character.timers_handler.big_jump_timer.time_left > 0:
		character.play_animation("Big_jump_wall_charge")
	elif character.big_jump_charged and input.dash:
		character.play_animation("Big_jump_wall_charge")
	else:
		character.play_animation("Sliding_wall")
