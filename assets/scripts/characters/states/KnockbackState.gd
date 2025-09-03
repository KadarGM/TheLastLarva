extends State
class_name KnockbackState

func enter() -> void:
	pass

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
	
	if character.knockback_timer > 0:
		character.knockback_timer -= delta
		character.velocity = character.knockback_velocity
		character.knockback_velocity = character.knockback_velocity.move_toward(Vector2.ZERO, character.character_data.incoming_knockback_friction * delta)
		
		if character.knockback_timer <= 0 or character.knockback_velocity.length() < 10:
			character.knockback_velocity = Vector2.ZERO
			
			if character.pending_death:
				character.pending_death = false
				state_machine.transition_to("DeathState")
			elif character.was_hit_by_damage and character.is_on_floor() and character.character_data.can_be_stunned:
				character.was_hit_by_damage = false
				state_machine.transition_to("StunnedState")
			else:
				character.was_hit_by_damage = false
				state_machine.transition_to("IdleState")
	else:
		if character.pending_death:
			character.pending_death = false
			state_machine.transition_to("DeathState")
		elif character.was_hit_by_damage and character.is_on_floor() and character.character_data.can_be_stunned:
			character.was_hit_by_damage = false
			state_machine.transition_to("StunnedState")
		else:
			character.was_hit_by_damage = false
			state_machine.transition_to("IdleState")

func set_knockback(force: Vector2) -> void:
	character.knockback_velocity = force
	character.knockback_timer = character.character_data.incoming_knockback_duration

func handle_animation() -> void:
	character.play_animation("Jump")
