extends State
class_name ParryState

var parry_window_timer: float = 0.0
var parry_successful: bool = false
var transition_timer: float = 0.0

func enter() -> void:
	if not character.character_data.can_parry:
		if character.character_data.can_block:
			state_machine.transition_to("BlockState")
		else:
			transition_to_appropriate_state()
		return
	
	if character.timers_handler.parry_cooldown_timer and character.timers_handler.parry_cooldown_timer.time_left > 0:
		if character.character_data.can_block:
			state_machine.transition_to("BlockState")
		else:
			transition_to_appropriate_state()
		return
	
	if character.stamina_current < character.character_data.parry_stamina_cost:
		if character.character_data.can_block:
			state_machine.transition_to("BlockState")
		else:
			transition_to_appropriate_state()
		return
	
	parry_window_timer = 0.0
	parry_successful = false
	transition_timer = 0.0
	
	character.stamina_current -= character.character_data.parry_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	character.set_weapon_visibility("both")
	
	if character.is_on_floor():
		character.velocity.x = 0

func exit() -> void:
	character.timers_handler.hide_weapon_timer.wait_time = character.character_data.hide_weapon_time
	character.timers_handler.hide_weapon_timer.start()
	
	if not parry_successful and character.timers_handler.parry_cooldown_timer:
		character.timers_handler.parry_cooldown_timer.wait_time = character.character_data.parry_fail_cooldown
		character.timers_handler.parry_cooldown_timer.start()

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if parry_successful:
		transition_timer += delta
		if transition_timer >= 0.1:
			transition_to_appropriate_state()
		return
	
	parry_window_timer += delta
	
	if parry_window_timer >= character.character_data.parry_window_duration:
		var input = character.get_controller_input()
		if input.parry and character.character_data.can_block:
			state_machine.transition_to("BlockState")
		else:
			transition_to_appropriate_state()
		return
	
	if character.is_on_floor():
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta * 2)
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta * 0.5)

func handle_incoming_attack(attacker: Node2D) -> bool:
	if parry_successful:
		return true
	
	if parry_window_timer < character.character_data.parry_window_duration:
		execute_parry(attacker)
		return true
	
	return false

func execute_parry(attacker: Node2D) -> void:
	parry_successful = true
	
	print("[PARRY] Successful parry by ", character.name, " against ", attacker.name)
	
	if attacker.has_method("cancel_attack"):
		attacker.cancel_attack()
	
	if attacker.has_method("get_stunned_by_parry"):
		attacker.get_stunned_by_parry(character.character_data.parry_stun_duration)
	elif attacker.has_method("apply_stun"):
		attacker.apply_stun(character.character_data.parry_stun_duration)
	
	var knockback = (attacker.global_position - character.global_position).normalized()
	knockback *= character.character_data.parry_knockback_force
	knockback.y = -abs(character.character_data.parry_knockback_force * 0.3)
	
	if attacker.has_method("apply_knockback"):
		attacker.apply_knockback(knockback)
	
	if character.character_data.parry_restores_stamina:
		character.stamina_current += character.character_data.parry_stamina_restore
		character.stamina_current = min(character.stamina_current, character.character_data.stamina_max)
	
	if character.character_data.parry_heals and character.stats_controller:
		character.stats_controller.restore_health(character.character_data.parry_heal_amount)
	
	if character.timers_handler.parry_invulnerability_timer:
		character.timers_handler.parry_invulnerability_timer.wait_time = character.character_data.parry_invulnerability_duration
		character.timers_handler.parry_invulnerability_timer.start()
		character.invulnerability_temp = true

func transition_to_appropriate_state() -> void:
	if character.is_on_floor():
		var input = character.get_controller_input()
		if abs(input.move_direction.x) > 0.1:
			state_machine.transition_to("WalkingState")
		else:
			state_machine.transition_to("IdleState")
	else:
		state_machine.transition_to("JumpingState")

func handle_animation() -> void:
	if character.is_on_floor():
		character.play_animation("Block_ground")
	else:
		character.play_animation("Block_air")
