extends State
class_name DoubleJumpingState

func enter() -> void:
	var input = character.get_controller_input()
	character.velocity.y = character.character_data.jump_velocity * character.character_data.double_jump_multiplier
	character.has_double_jump = false
	character.jump_count = 2
	character.has_triple_jump = true
	character.is_double_jump_held = input.jump
	character.play_animation("Double_jump")
	character.reset_air_time()

func physics_process(delta: float) -> void:
	var input = character.get_controller_input()
	
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
		
		if character.is_double_jump_held and character.velocity.y < 0:
			if input.jump_released or character._is_on_ceiling():
				character.velocity.y *= character.character_data.jump_release_multiplier
				character.is_double_jump_held = false
	
	if character.is_on_floor():
		if abs(character.velocity.x) > 10:
			state_machine.transition_to("WalkingState")
		else:
			state_machine.transition_to("IdleState")
		return
	
	var left = character.ray_casts_handler.left_wall_ray.is_colliding()
	var right = character.ray_casts_handler.right_wall_ray.is_colliding()
	
	if (left or right) and character.velocity.y > 0 and character.character_data.can_wall_slide:
		state_machine.transition_to("WallSlidingState")
		return
	
	var input_direction = input.move_direction.x
	process_air_movement(input_direction)
	process_input()

func process_air_movement(input_direction: float) -> void:
	if not character.character_data.can_walk:
		return
	
	if input_direction:
		character.velocity.x = move_toward(character.velocity.x, input_direction * character.character_data.speed, character.character_data.speed * character.character_data.air_movement_friction)
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * character.character_data.air_movement_friction)

func process_input() -> void:
	var input = character.get_controller_input()
	
	if input.jump_pressed:
		if character.jump_count == 2 and character.character_data.can_triple_jump:
			if character.stamina_current >= character.character_data.triple_jump_stamina_cost:
				state_machine.transition_to("TripleJumpingState")
	
	if input.dash_pressed and character.character_data.can_dash:
		if character.can_dash:
			state_machine.transition_to("DashingState")
	
	if input.attack_pressed:
		if character.big_jump_charged and input.dash:
			state_machine.transition_to("DashAttackState")
		else:
			character.perform_air_attack()
	
	if input.charge_jump_pressed:
		if character.character_data.can_big_attack:
			state_machine.transition_to("BigAttackState")

func handle_animation() -> void:
	if character.animation_player.current_animation == "Double_jump":
		pass
	else:
		character.play_animation("Jump")
