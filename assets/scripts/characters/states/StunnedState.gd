extends State
class_name StunnedState

func enter() -> void:
	character.velocity.x = 0
	character.timers_handler.stun_timer.wait_time = character.character_data.stun_time * 0.3
	character.timers_handler.stun_timer.start()
	character.cancel_big_jump_charge()

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if character.timers_handler.stun_timer.is_stopped():
		state_machine.transition_to("IdleState")
	
	character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta)

func handle_animation() -> void:
	character.play_animation("Idle")
