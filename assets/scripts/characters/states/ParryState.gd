extends State
class_name ParryState

var parry_window_timer: float = 0.0
var parry_window_active: bool = true

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
	
	parry_window_timer = 0.0
	parry_window_active = true
	
	character.set_weapon_visibility("both")
	
	if character.is_on_floor():
		character.velocity.x = 0

func exit() -> void:
	character.timers_handler.hide_weapon_timer.wait_time = character.character_data.hide_weapon_time
	character.timers_handler.hide_weapon_timer.start()
	
	if parry_window_active and character.timers_handler.parry_cooldown_timer:
		character.timers_handler.parry_cooldown_timer.wait_time = character.character_data.parry_fail_cooldown
		character.timers_handler.parry_cooldown_timer.start()

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
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

func handle_incoming_damage(damage: int, attacker_position: Vector2) -> int:
	if not parry_window_active or parry_window_timer >= character.character_data.parry_window_duration:
		return damage
	
	parry_window_active = false
	
	var attacker_found: Node2D = null
	
	if attacker_position != Vector2.ZERO:
		var min_distance = 100.0
		for body in get_tree().get_nodes_in_group("Enemy"):
			var distance = body.global_position.distance_to(attacker_position)
			if distance < min_distance:
				min_distance = distance
				attacker_found = body
	
	if not attacker_found:
		for body in character.areas_handler.attack_area.get_overlapping_bodies():
			if body == character:
				continue
			if body.is_in_group("Enemy"):
				attacker_found = body
				break
	
	if attacker_found:
		if attacker_found.has_method("get_stunned_by_parry"):
			attacker_found.get_stunned_by_parry(character.character_data.parry_stun_duration)
		elif attacker_found.has_method("apply_stun"):
			attacker_found.apply_stun(character.character_data.parry_stun_duration)
		
		var knockback = (attacker_found.global_position - character.global_position).normalized()
		knockback *= character.character_data.parry_knockback_force
		knockback.y = -abs(character.character_data.parry_knockback_force * 0.3)
		
		if attacker_found.has_method("apply_knockback"):
			attacker_found.apply_knockback(knockback)
	
	if character.character_data.parry_restores_stamina:
		character.stamina_current += character.character_data.parry_stamina_restore
		character.stamina_current = min(character.stamina_current, character.character_data.stamina_max)
	
	if character.character_data.parry_heals and character.stats_controller:
		character.stats_controller.restore_health(character.character_data.parry_heal_amount)
	
	if character.timers_handler.parry_invulnerability_timer:
		character.timers_handler.parry_invulnerability_timer.wait_time = character.character_data.parry_invulnerability_duration
		character.timers_handler.parry_invulnerability_timer.start()
		character.invulnerability_temp = true
	
	transition_to_appropriate_state()
	return 0

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
