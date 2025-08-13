extends State
class_name ChargingBigJumpState

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if not character.is_on_floor():
		state_machine.transition_to("JumpingState")
		return
	
	if not Input.is_action_pressed("J_dash"):
		character.cancel_big_jump_charge()
		state_machine.transition_to("IdleState")
		return
	
	if character.big_jump_charged:
		if Input.is_action_just_pressed("L_attack"):
			state_machine.transition_to("DashAttackState")
			return
		elif Input.is_action_just_pressed("W_jump"):
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
	
	var input_direction = Input.get_axis("A_left", "D_right")
	if input_direction != 0 and not character.big_jump_charged:
		character.velocity.x = input_direction * character.character_data.speed
		character.cancel_big_jump_charge()
		state_machine.transition_to("WalkingState")
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta)

func handle_animation() -> void:
	character.play_animation("Big_jump_charge")
