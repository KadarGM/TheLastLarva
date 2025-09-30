extends State
class_name BigAttackState

var animation_started: bool = false

func enter() -> void:
	if not character.character_data.can_big_attack:
		state_machine.transition_to("JumpingState")
		return
	
	if character.stamina_current < character.character_data.big_attack_stamina_cost:
		state_machine.transition_to("JumpingState")
		return
	
	character.stamina_current -= character.character_data.big_attack_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	var ground = character.is_on_floor()
	character.is_high_big_attack = not ground
	character.big_attack_pending = true
	animation_started = false
	
	if character.air_time == 0:
		character.air_time = character.character_data.air_time_initial
		character.effective_air_time = character.character_data.air_time_initial
	
	character.timers_handler.hide_weapon_timer.stop()
	character.invulnerability_temp = true

func exit() -> void:
	character.invulnerability_temp = false

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta * character.character_data.landing_multiplier
	
	character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * character.character_data.big_attack_air_friction)
	
	check_big_attack_landing()

func check_big_attack_landing() -> void:
	if character.is_on_floor() and character.big_attack_pending:
		state_machine.transition_to("BigAttackLandingState")

func handle_animation() -> void:
	if not character.character_data.can_big_attack:
		return
	
	if not animation_started:
		if character.is_high_big_attack:
			character.play_animation("Big_attack_prepare")
		else:
			character.play_animation("Big_attack")
		character.set_weapon_visibility("both")
		animation_started = true
