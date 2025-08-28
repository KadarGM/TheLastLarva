extends State
class_name DashAttackState

var dash_direction: float = 0.0
var damage_applied: bool = false

func enter() -> void:
	if not character.character_data.can_dash_attack:
		state_machine.transition_to("IdleState")
		return
	
	if character.timers_handler.dash_attack_cooldown_timer.time_left > 0:
		state_machine.transition_to("IdleState")
		return
	
	character.timers_handler.hide_weapon_timer.stop()
	
	damage_applied = false
	character.dash_attack_damaged_entities.clear()
	dash_direction = character.get_facing_direction()
	
	character.big_jump_charged = false
	character.timers_handler.big_jump_timer.stop()
	
	character.timers_handler.dash_attack_cooldown_timer.wait_time = character.character_data.dash_attack_cooldown
	character.timers_handler.dash_attack_cooldown_timer.start()
	
	character.set_weapon_visibility("both")
	character.play_animation("Dash_attack")

func exit() -> void:
	character.timers_handler.hide_weapon_timer.wait_time = character.character_data.hide_weapon_time
	character.timers_handler.hide_weapon_timer.start()

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
	
	character.stamina_current -= character.character_data.dash_attack_stamina_drain_rate * delta
	character.stamina_current = max(0, character.stamina_current)
	
	if character.stamina_current <= 0:
		state_machine.transition_to("IdleState")
		return
	
	character.velocity.x = dash_direction * character.character_data.dash_speed * 1.5
	
	if character._is_on_wall():
		state_machine.transition_to("IdleState")
		return
	
	process_input()

func process_input() -> void:
	var input = character.get_controller_input()
	
	if not input.dash:
		state_machine.transition_to("IdleState")

func apply_damage_to_entity(entity: Node2D) -> void:
	if damage_applied:
		return
	
	if entity == character:
		return
	
	if entity in character.dash_attack_damaged_entities:
		return
	
	if entity.is_in_group("dead"):
		return
	
	if entity.has_method("state_machine") and entity.state_machine:
		if entity.state_machine.current_state and entity.state_machine.current_state.name == "DeathState":
			return
	
	character.dash_attack_damaged_entities.append(entity)
	
	if entity.has_method("take_damage"):
		entity.take_damage(character.character_data.dash_attack_dmg, character.global_position)
	
	if entity.has_method("apply_knockback") and character.character_data.can_apply_knockback:
		var target_weight_multiplier = 1.0
		if entity.has_method("character_data") and entity.character_data:
			if entity.character_data.has("weight"):
				target_weight_multiplier = 100.0 / entity.character_data.weight
		
		var knockback = Vector2(
			dash_direction * character.character_data.outgoing_knockback_force * 2.0 * target_weight_multiplier,
			-abs(character.character_data.jump_velocity * 0.3 * target_weight_multiplier)
		)
		entity.apply_knockback(knockback)

func handle_animation() -> void:
	pass
