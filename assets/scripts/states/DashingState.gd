extends State
class_name DashingState

func enter() -> void:
	if not character.character_data.can_dash or not character.can_dash:
		state_machine.transition_to("IdleState")
		return
	
	if character.stamina_current < character.character_data.dash_stamina_cost:
		state_machine.transition_to("IdleState")
		return
	
	var dash_direction = Input.get_axis("A_left", "D_right")
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
	if character.timers_handler.dash_timer.is_stopped():
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")

func handle_animation() -> void:
	character.play_animation("Dash")
