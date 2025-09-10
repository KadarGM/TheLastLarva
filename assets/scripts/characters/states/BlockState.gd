extends State
class_name BlockState

var block_timer: float = 0.0
var weapon_visibility_set: bool = false

func enter() -> void:
	if not character.character_data.can_block:
		transition_to_appropriate_state()
		return
	
	block_timer = 0.0
	weapon_visibility_set = false
	
	character.timers_handler.hide_weapon_timer.stop()
	character.set_weapon_visibility("both")
	weapon_visibility_set = true

func exit() -> void:
	if weapon_visibility_set:
		character.timers_handler.hide_weapon_timer.wait_time = character.character_data.hide_weapon_time
		character.timers_handler.hide_weapon_timer.start()

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	var input = character.get_controller_input()
	
	if not input.parry:
		transition_to_appropriate_state()
		return
	
	block_timer += delta
	
	if character.is_on_floor():
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta * 2)
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta * 0.5)

func handle_incoming_damage(damage: int, attacker_position: Vector2) -> int:
	if character.stamina_current < character.character_data.block_hit_stamina_cost:
		return damage
	
	character.stamina_current -= character.character_data.block_hit_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	if character.stamina_current <= 0:
		character.stamina_current = 0
		if character.timers_handler.stun_timer:
			character.timers_handler.stun_timer.wait_time = character.character_data.stun_time
			character.timers_handler.stun_timer.start()
		state_machine.transition_to("StunnedState")
		return damage
	
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
