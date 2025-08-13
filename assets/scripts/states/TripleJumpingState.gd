extends State
class_name TripleJumpingState

func enter() -> void:
	if character.stamina_current < character.character_data.triple_jump_stamina_cost:
		state_machine.transition_to("JumpingState")
		return
	
	character.velocity.y = character.character_data.jump_velocity * character.character_data.triple_jump_multiplier
	character.stamina_current -= character.character_data.triple_jump_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	character.has_triple_jump = false
	character.jump_count = 3
	character.is_triple_jump_held = true
	character.play_animation("Triple_jump")
	character.reset_air_time()

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
	
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
	
	var input_direction = Input.get_axis("A_left", "D_right")
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
	if Input.is_action_just_pressed("J_dash") and character.character_data.can_dash:
		if character.can_dash:
			state_machine.transition_to("DashingState")
	
	if Input.is_action_just_pressed("L_attack"):
		if character.big_jump_charged and Input.is_action_pressed("J_dash"):
			state_machine.transition_to("DashAttackState")
		else:
			character.perform_air_attack()
	
	if Input.is_action_just_pressed("S_charge_jump"):
		if character.character_data.can_big_attack:
			state_machine.transition_to("BigAttackState")

func handle_animation() -> void:
	if character.animation_player.current_animation == "Triple_jump":
		pass
	else:
		character.play_animation("Jump")
