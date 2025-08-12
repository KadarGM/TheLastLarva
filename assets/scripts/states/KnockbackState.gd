extends State
class_name KnockbackState

func enter() -> void:
	pass

func physics_process(delta: float) -> void:
	if character.knockback_timer > 0:
		character.knockback_timer -= delta
		character.velocity = character.knockback_velocity
		character.knockback_velocity = character.knockback_velocity.move_toward(Vector2.ZERO, character.character_data.knockback_friction * delta)
		
		if character.knockback_timer <= 0 or character.knockback_velocity.length() < 10:
			character.knockback_velocity = Vector2.ZERO
			state_machine.transition_to("IdleState")
	else:
		state_machine.transition_to("IdleState")

func handle_animation() -> void:
	character.play_animation("Jump")
