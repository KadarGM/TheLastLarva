extends State
class_name DashAttackState

var direction: float = 0.0

func enter() -> void:
	if not character.character_data.can_dash_attack:
		state_machine.transition_to("IdleState")
		return
	
	if not character.big_jump_charged:
		state_machine.transition_to("IdleState")
		return
	
	if character.timers_handler.dash_attack_cooldown_timer.time_left > 0:
		state_machine.transition_to("IdleState")
		return
	
	character.cancel_big_jump_charge()
	character.dash_attack_damaged_entities.clear()
	character.invulnerability_temp = true
	
	var input = character.get_controller_input()
	direction = input.move_direction.x
	if direction == 0:
		direction = character.get_facing_direction()
	
	character.velocity.x = direction * character.character_data.dash_speed * 1.5
	character.velocity.y = 0
	
	character.set_weapon_visibility("both")
	
	character.timers_handler.dash_attack_cooldown_timer.wait_time = character.character_data.dash_attack_cooldown
	character.timers_handler.dash_attack_cooldown_timer.start()

func exit() -> void:
	character.invulnerability_temp = false
	character.dash_attack_damaged_entities.clear()
	character.set_weapon_visibility("hide")
	character.can_big_jump = false
	character.timers_handler.big_jump_cooldown_timer.wait_time = character.character_data.big_jump_cooldown
	character.timers_handler.big_jump_cooldown_timer.start()

func physics_process(delta: float) -> void:
	character.stamina_current -= character.character_data.dash_attack_stamina_drain_rate * delta
	
	if character.stamina_current <= 0:
		character.stamina_current = 0
		end_dash_attack()
		return
	
	var input = character.get_controller_input()
	if not input.attack:
		end_dash_attack()
		return
	
	if character.is_on_wall_left() or character.is_on_wall_right():
		end_dash_attack()
		return
	
	character.velocity.x = direction * character.character_data.dash_speed * 1.5
	
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta * 0.5

func end_dash_attack() -> void:
	if character.is_on_floor():
		state_machine.transition_to("IdleState")
	else:
		state_machine.transition_to("JumpingState")

func apply_damage_to_entity(body: Node2D) -> void:
	if body == character:
		return
	
	if body.is_in_group("dead"):
		return
	
	if body.has_method("state_machine") and body.state_machine:
		if body.state_machine.current_state and body.state_machine.current_state.name == "DeathState":
			return
	
	if body in character.dash_attack_damaged_entities:
		return
	
	character.dash_attack_damaged_entities.append(body)
	
	if body.has_method("take_damage"):
		body.take_damage(character.character_data.dash_attack_dmg)
	
	if body.has_method("apply_knockback"):
		var knockback_dir = direction
		var knockback = Vector2(
			knockback_dir * character.character_data.knockback_force * 1.5,
			-abs(character.character_data.jump_velocity) * 0.3
		)
		body.apply_knockback(knockback)

func handle_animation() -> void:
	character.play_animation("Dash_attack")
