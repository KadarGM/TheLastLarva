extends State
class_name DashAttackState

var direction: float = 0.0

func enter() -> void:
	character.stamina_current -= character.character_data.dash_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	direction = character.get_attack_direction()
	character.dash_attack_damaged_entities.clear()
	character.invulnerability_temp = true
	character.big_jump_charged = false
	character.can_big_jump = false
	
	if character.timers_handler.hide_weapon_timer:
		character.timers_handler.hide_weapon_timer.stop()
	
	character.timers_handler.big_jump_timer.stop()
	character.timers_handler.big_jump_cooldown_timer.wait_time = character.character_data.dash_attack_cooldown
	character.timers_handler.big_jump_cooldown_timer.start()

func exit() -> void:
	direction = 0.0
	character.dash_attack_damaged_entities.clear()
	character.invulnerability_temp = false
	
	if character.timers_handler.hide_weapon_timer:
		character.timers_handler.hide_weapon_timer.wait_time = character.character_data.hide_weapon_time
		character.timers_handler.hide_weapon_timer.start()

func physics_process(delta: float) -> void:
	character.velocity.x = direction * character.character_data.big_jump_horizontal_speed
	character.velocity.y = 0
	
	character.stamina_current -= character.character_data.dash_attack_stamina_drain_rate * delta
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	if character.stamina_current <= 0:
		character.stamina_current = 0
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
		return
	
	check_collision()
	
	if not Input.is_action_pressed("L_attack") or not Input.is_action_pressed("J_dash"):
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")

func check_collision() -> void:
	if direction < 0 and character.is_on_wall_left():
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
	elif direction > 0 and character.is_on_wall_right():
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")

func apply_damage_to_entity(body: Node2D) -> void:
	if body in character.dash_attack_damaged_entities or body == character:
		return
	
	character.dash_attack_damaged_entities.append(body)
	
	var damage = character.character_data.dash_attack_dmg
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	if character.character_data.can_take_knockback:
		var knockback_force = Vector2(
			direction * character.character_data.knockback_force * 1.5,
			character.character_data.jump_velocity * character.character_data.knockback_vertical_multiplier
		)
		if body.has_method("apply_knockback"):
			body.apply_knockback(knockback_force)

func handle_animation() -> void:
	character.play_animation("Dash_attack")
	character.set_weapon_visibility("both")
