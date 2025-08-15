extends State
class_name WaitState

var wait_timer: float = 0.0

func enter() -> void:
	character.velocity.x = 0
	wait_timer = 2.0

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	wait_timer -= delta
	
	character.velocity.x = 0
	
	var ai_controller = character.controller as AIController
	if not ai_controller:
		state_machine.transition_to("PatrolState")
		return
	
	if ai_controller.can_see_player:
		if ai_controller.player_in_attack_range:
			state_machine.transition_to("AIAttackState")
		else:
			state_machine.transition_to("ChaseState")
		return
	
	if wait_timer <= 0:
		if ai_controller.player_in_detection_zone:
			state_machine.transition_to("SearchState")
		else:
			state_machine.transition_to("PatrolState")

func handle_animation() -> void:
	character.play_animation("Idle")
