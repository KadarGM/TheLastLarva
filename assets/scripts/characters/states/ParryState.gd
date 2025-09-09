extends State
class_name ParryState

var parry_window_timer: float = 0.0
var successful_parry: bool = false
var parried_entity: Node2D = null

func enter() -> void:
	if not character.character_data.can_parry:
		state_machine.transition_to("BlockState")
		return
	
	if character.timers_handler.parry_cooldown_timer and character.timers_handler.parry_cooldown_timer.time_left > 0:
		state_machine.transition_to("BlockState")
		return
	
	if character.stamina_current < character.character_data.parry_stamina_cost:
		state_machine.transition_to("BlockState")
		return
	
	character.stamina_current -= character.character_data.parry_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	parry_window_timer = 0.0
	successful_parry = false
	parried_entity = null
	
	character.set_weapon_visibility("both")
	
	if character.is_on_floor():
		character.velocity.x = 0

func exit() -> void:
	character.timers_handler.hide_weapon_timer.wait_time = character.character_data.hide_weapon_time
	character.timers_handler.hide_weapon_timer.start()
	
	if not successful_parry and character.timers_handler.parry_cooldown_timer:
		character.timers_handler.parry_cooldown_timer.wait_time = character.character_data.parry_fail_cooldown
		character.timers_handler.parry_cooldown_timer.start()

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
	
	parry_window_timer += delta
	
	check_for_attacks_in_range()
	
	if parry_window_timer >= character.character_data.parry_window_duration:
		if successful_parry:
			execute_successful_parry()
		else:
			var input = character.get_controller_input()
			if input.parry and character.character_data.can_block:
				state_machine.transition_to("BlockState")
			else:
				transition_to_appropriate_state()

func check_for_attacks_in_range() -> void:
	if successful_parry or not character.areas_handler or not character.areas_handler.attack_area:
		return
	
	var overlapping_bodies = character.areas_handler.attack_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body == character:
			continue
		
		if body.is_in_group("dead"):
			continue
		
		var is_attacking = false
		
		if body.has_method("state_machine") and body.state_machine:
			var entity_state = body.state_machine.get_current_state_name()
			if entity_state == "AttackingState" or entity_state == "DashAttackState" or entity_state == "BigAttackState":
				is_attacking = true
		elif body.has_method("get") and body.has_method("character_data"):
			if body.get("current_state") == body.character_data.State.ATTACKING:
				is_attacking = true
		
		if is_attacking:
			successful_parry = true
			parried_entity = body
			break

func execute_successful_parry() -> void:
	if not parried_entity:
		transition_to_appropriate_state()
		return
	
	character.invulnerability_temp = true
	
	if character.timers_handler.parry_invulnerability_timer:
		character.timers_handler.parry_invulnerability_timer.wait_time = character.character_data.parry_invulnerability_duration
		character.timers_handler.parry_invulnerability_timer.start()
	
	if parried_entity.has_method("apply_stun"):
		parried_entity.apply_stun(character.character_data.parry_stun_duration)
	
	if parried_entity.has_method("state_machine") and parried_entity.state_machine:
		if parried_entity.state_machine.states.has("StunnedState"):
			parried_entity.state_machine.transition_to("StunnedState")
	
	if parried_entity.has_method("play_animation"):
		parried_entity.play_animation("Stun")
	
	if parried_entity.has_method("cancel_attack"):
		parried_entity.cancel_attack()
	
	var knockback_direction = (parried_entity.global_position - character.global_position).normalized()
	var knockback_force = Vector2(
		knockback_direction.x * character.character_data.parry_knockback_force,
		-abs(character.character_data.parry_knockback_force * 0.3)
	)
	
	if parried_entity.has_method("apply_knockback"):
		parried_entity.apply_knockback(knockback_force)
	
	if character.character_data.parry_restores_stamina:
		character.stamina_current += character.character_data.parry_stamina_restore
		character.stamina_current = min(character.stamina_current, character.character_data.stamina_max)
	
	if character.character_data.parry_heals:
		if character.stats_controller:
			character.stats_controller.restore_health(character.character_data.parry_heal_amount)
	
	transition_to_appropriate_state()

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
