extends State
class_name WalkingState

func enter() -> void:
	pass

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if not character.is_on_floor():
		state_machine.transition_to("JumpingState")
		return
	
	var input = character.get_controller_input()
	var input_direction = input.move_direction.x
	
	if abs(input_direction) < 0.1:
		state_machine.transition_to("IdleState")
		return
	
	character.velocity.x = input_direction * character.character_data.speed
	
	process_input()

func process_input() -> void:
	var input = character.get_controller_input()
	
	if input.parry_pressed:
		if character.character_data.can_parry:
			if not character.timers_handler.parry_cooldown_timer or character.timers_handler.parry_cooldown_timer.is_stopped():
				state_machine.transition_to("ParryState")
				return
	elif input.parry:
		if character.character_data.can_block:
			state_machine.transition_to("BlockState")
			return
	
	if input.jump_pressed:
		if character.handle_ground_jump():
			state_machine.transition_to("JumpingState")
			return
	
	if input.charge_jump_pressed and character.character_data.can_big_attack:
		state_machine.transition_to("BigAttackState")
		return
	
	if input.dash_pressed:
		if character.big_jump_charged and input.attack and character.timers_handler.dash_attack_cooldown_timer.is_stopped():
			state_machine.transition_to("DashAttackState")
			return
		elif character.can_dash:
			state_machine.transition_to("DashingState")
			return
	
	if input.attack_pressed:
		if character.character_data.can_attack and character.timers_handler.before_attack_timer.is_stopped():
			state_machine.transition_to("AttackingState")
		return
	
	character.process_big_jump_input()

func handle_animation() -> void:
	var input = character.get_controller_input()
	if character.big_jump_charged and input.dash:
		character.play_animation("Big_jump_charge")
	else:
		character.play_animation("Walk")
