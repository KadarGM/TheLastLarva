extends State
class_name BlockState

var blocked_this_frame: bool = false

func enter() -> void:
	if not character.character_data.can_block:
		transition_to_appropriate_state()
		return
	
	if character.stamina_current <= 0:
		transition_to_appropriate_state()
		return
	
	character.velocity.x = 0
	blocked_this_frame = false
	
	character.set_weapon_visibility("both")

func exit() -> void:
	character.timers_handler.hide_weapon_timer.wait_time = character.character_data.hide_weapon_time
	character.timers_handler.hide_weapon_timer.start()

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	var input = character.get_controller_input()
	
	if not input.parry:
		transition_to_appropriate_state()
		return
	
	character.stamina_current -= character.character_data.block_stamina_drain_rate * delta
	
	if blocked_this_frame:
		character.stamina_current -= character.character_data.block_hit_stamina_cost
		blocked_this_frame = false
	
	character.stamina_current = max(0, character.stamina_current)
	
	if character.stamina_current <= 0:
		state_machine.transition_to("StunnedState")
		return
	
	if character.is_on_floor():
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta * 2)
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta * 0.5)

func handle_incoming_damage(damage: int, attacker_position: Vector2) -> int:
	blocked_this_frame = true
	
	var blocked_damage = int(damage * character.character_data.block_damage_reduction)
	
	var knockback_direction: Vector2
	if attacker_position != Vector2.ZERO:
		knockback_direction = (character.global_position - attacker_position).normalized()
	else:
		knockback_direction = Vector2(randf_range(-1, 1), 0).normalized()
	
	if knockback_direction.x == 0:
		knockback_direction.x = randf_range(-0.5, 0.5)
	
	var blocked_knockback = Vector2(
		knockback_direction.x * character.character_data.block_knockback_force,
		0
	)
	
	character.velocity += blocked_knockback
	
	return blocked_damage

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
