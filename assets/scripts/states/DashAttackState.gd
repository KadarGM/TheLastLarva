extends State
class_name DashAttackState

var direction: float = 0.0

func enter() -> void:
	if not character.character_data.can_dash_attack or not character.character_data.can_attack:
		state_machine.transition_to("IdleState")
		return
	
	if character.stamina_current < character.character_data.dash_stamina_cost:
		state_machine.transition_to("IdleState")
		return
	
	character.stamina_current -= character.character_data.dash_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	direction = character.get_attack_direction()
	character.dash_attack_damaged_entities.clear()
	character.invulnerability_temp = true
	character.big_jump_charged = false

func exit() -> void:
	direction = 0.0
	character.dash_attack_damaged_entities.clear()
	character.invulnerability_temp = false
	character.timers_handler.hide_weapon_timer.start()

func physics_process(delta: float) -> void:
	character.velocity.x = direction * character.character_data.big_jump_horizontal_speed
	character.velocity.y = 0
	
	character.stamina_current -= character.character_data.dash_attack_stamina_drain_rate * delta
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	if character.stamina_current <= 0:
		character.stamina_current = 0
		state_machine.transition_to("JumpingState")
		return
	
	check_collision()
	
	if not Input.is_action_pressed("L_attack"):
		state_machine.transition_to("JumpingState")

func check_collision() -> void:
	if direction < 0 and character.is_on_wall_left():
		state_machine.transition_to("JumpingState")
	elif direction > 0 and character.is_on_wall_right():
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
