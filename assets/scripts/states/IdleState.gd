extends State
class_name IdleState

func enter() -> void:
	character.reset_jump_state()
	character.velocity.x = 0

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if not character.is_on_floor():
		state_machine.transition_to("JumpingState")
		return
	
	var input = character.get_controller_input()
	var input_direction = input.move_direction.x
	
	if abs(input_direction) > 0.1:
		state_machine.transition_to("WalkingState")
		return
	
	character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta)
	
	process_input()

func process_input() -> void:
	var input = character.get_controller_input()
	
	if input.jump_pressed:
		if character.handle_ground_jump():
			state_machine.transition_to("JumpingState")
			return
	
	if input.attack_pressed:
		if character.big_jump_charged and input.dash and character.timers_handler.dash_attack_cooldown_timer.is_stopped():
			state_machine.transition_to("DashAttackState")
		elif character.character_data.can_attack and character.timers_handler.before_attack_timer.is_stopped():
			state_machine.transition_to("AttackingState")
		return
	
	if input.dash and character.can_big_jump and character.timers_handler.big_jump_cooldown_timer.is_stopped():
		if not input.attack:
			character.start_big_jump_charge()
			if character.timers_handler.big_jump_timer.time_left > 0:
				state_machine.transition_to("ChargingBigJumpState")
				return
		elif character.big_jump_charged and character.timers_handler.dash_attack_cooldown_timer.is_stopped():
			state_machine.transition_to("DashAttackState")
			return
	
	character.process_big_jump_input()

func handle_animation() -> void:
	var input = character.get_controller_input()
	if character.big_jump_charged and input.dash:
		character.play_animation("Big_jump_charge")
	else:
		character.play_animation("Idle")
