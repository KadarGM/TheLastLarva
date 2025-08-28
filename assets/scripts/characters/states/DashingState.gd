extends State
class_name DashingState

var dash_direction: float = 0.0

func enter() -> void:
	if not character.character_data.can_dash:
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
		return
	
	if not character.can_dash:
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
	
	var input = character.get_controller_input()
	
	if not character.is_on_floor() and input.move_direction.x == 0:
		state_machine.transition_to("JumpingState")
		return
	
	if input.move_direction.x != 0:
		dash_direction = input.move_direction.x
	else:
		dash_direction = character.get_facing_direction()
	
	character.stamina_current -= character.character_data.dash_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	character.can_dash = false
	character.dash_count += 1
	
	character.timers_handler.dash_timer.wait_time = character.character_data.dash_duration
	character.timers_handler.dash_timer.start()
	
	character.timers_handler.dash_cooldown_timer.wait_time = character.character_data.dash_cooldown_time
	character.timers_handler.dash_cooldown_timer.start()
	
	character.play_animation("Dash")

func physics_process(_delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y = 0
	
	character.velocity.x = dash_direction * character.character_data.dash_speed
	
	if character.timers_handler.dash_timer.is_stopped():
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
		return
	
	process_input()

func process_input() -> void:
	var input = character.get_controller_input()
	
	if input.jump_pressed and character.character_data.can_jump:
		character.velocity.y = character.character_data.jump_velocity
		state_machine.transition_to("JumpingState")
	
	if input.attack_pressed and character.character_data.can_attack:
		if character.is_on_floor():
			state_machine.transition_to("AttackingState")
		elif character.character_data.can_air_attack:
			state_machine.transition_to("AttackingState")

func handle_animation() -> void:
	character.play_animation("Dash")
