extends State
class_name DashingState

func enter() -> void:
	if not character.character_data.can_dash or not character.can_dash:
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
		return
	
	if character.stamina_current < character.character_data.dash_stamina_cost:
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
		return
	
	if character.jump_count >= 4:
		state_machine.transition_to("JumpingState")
		return
	
	var input = character.get_controller_input()
	var dash_direction = input.move_direction.x
	if dash_direction == 0:
		dash_direction = character.get_facing_direction()
	
	character.velocity.x = dash_direction * character.character_data.dash_speed
	character.velocity.y = 0
	character.can_dash = false
	character.stamina_current -= character.character_data.dash_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	if character.big_jump_charged:
		character.timers_handler.dash_timer.wait_time = character.character_data.dash_duration * character.character_data.big_jump_dash_multiplier
		character.cancel_big_jump_charge()
	else:
		character.timers_handler.dash_timer.wait_time = character.character_data.dash_duration
	
	character.timers_handler.dash_timer.start()
	character.timers_handler.dash_cooldown_timer.start()
	
	character.invulnerability_temp = true

func exit() -> void:
	character.invulnerability_temp = false

func physics_process(_delta: float) -> void:
	var input = character.get_controller_input()
	
	if input.jump_pressed and not character.is_on_floor():
		if character.jump_count == 1 and character.has_double_jump and character.character_data.can_double_jump:
			state_machine.transition_to("DoubleJumpingState")
		elif character.jump_count == 2 and character.has_triple_jump and character.character_data.can_triple_jump:
			if character.stamina_current >= character.character_data.triple_jump_stamina_cost:
				state_machine.transition_to("TripleJumpingState")
	
	if character.timers_handler.dash_timer.is_stopped():
		if character.is_on_floor():
			state_machine.transition_to("WalkingState")
		else:
			state_machine.transition_to("JumpingState")

func handle_animation() -> void:
	character.play_animation("Dash")
