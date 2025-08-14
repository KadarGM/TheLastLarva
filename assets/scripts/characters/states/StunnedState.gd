extends State
class_name StunnedState

func enter() -> void:
	character.velocity.x = 0
	character.timers_handler.stun_timer.start()
	character.cancel_big_jump_charge()

func physics_process(_delta: float) -> void:
	if character.timers_handler.stun_timer.is_stopped():
		state_machine.transition_to("IdleState")
	
	character.velocity.x = 0

func handle_animation() -> void:
	pass
